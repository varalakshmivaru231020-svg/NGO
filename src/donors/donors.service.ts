import { Injectable, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateDonorDto } from './dto/create-donor.dto';
import { UpdateDonorDto } from './dto/update-donor.dto';
import { DonorQueryDto } from './dto/donor-query.dto';
import { CreateDonorActivityVideoDto } from './dto/create-donor-activity-video.dto';
import { CreateDonorActivityImageDto } from './dto/create-donor-activity-image.dto';
import { paginate, paginatedResponse } from '../common/dto/pagination.dto';

// ~20MB original video / ~27MB once base64-encoded — keeps well under the
// 30mb JSON body-parser limit configured in main.ts.
const MAX_VIDEO_BASE64_CHARS = 27 * 1024 * 1024;
// ~5MB original image / ~7MB once base64-encoded.
const MAX_IMAGE_BASE64_CHARS = 7 * 1024 * 1024;

@Injectable()
export class DonorsService {
  constructor(private prisma: PrismaService) {}

  private include = {
    categories: { include: { category: true } },
    _count: { select: { donations: true, sponsorships: true } },
  };

  // List rows omit the base64 avatar — see StudentsService.listSelect. Cards
  // lazy-load it from GET /donors/:id/avatar when `hasAvatar` is true.
  private listSelect = {
    ...Object.fromEntries(
      Object.keys(Prisma.DonorScalarFieldEnum).filter((k) => k !== 'avatar').map((k) => [k, true]),
    ),
    ...this.include,
  } as Prisma.DonorSelect;

  // Atomic — see DonationsService.nextReceiptNo() for why SELECT ... FOR
  // UPDATE inside a transaction is race-free under concurrent requests
  // (relevant now that public/anonymous donor creation exists).
  private async nextCode(): Promise<string> {
    const key = 'donor-code';
    const seq = await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`INSERT IGNORE INTO sequence_counters (\`key\`, seq) VALUES (${key}, 0)`;
      const rows = await tx.$queryRaw<{ seq: number }[]>`SELECT seq FROM sequence_counters WHERE \`key\` = ${key} FOR UPDATE`;
      const next = rows[0].seq + 1;
      await tx.$executeRaw`UPDATE sequence_counters SET seq = ${next} WHERE \`key\` = ${key}`;
      return next;
    });
    return `DID${String(seq).padStart(5, '0')}`;
  }

  // name + mobile together identify a donor. Two people may share a name, and
  // a family may share one phone, but the pair repeating means the same donor
  // is being entered twice.
  private static normName(s: string) {
    return (s ?? '').trim().toLowerCase().replace(/\s+/g, ' ');
  }

  private static normMobile(s: string) {
    return (s ?? '').replace(/\D/g, '');
  }

  /**
   * Rejects a second donor with the same name + mobile. Candidates are pulled
   * on an exact match of EITHER field (both are indexed) and then compared on
   * their normalised forms, so a difference in spacing/case/punctuation in one
   * field is still caught via the other. Soft-deleted donors don't reserve the
   * pair — a deleted donor can be re-added.
   */
  private async assertNotDuplicate(name: string, mobile: string, excludeId?: string) {
    const wantName = DonorsService.normName(name);
    const wantMobile = DonorsService.normMobile(mobile);
    if (!wantName || !wantMobile) return;

    const candidates = await this.prisma.donor.findMany({
      where: {
        isActive: true,
        OR: [{ name: (name ?? '').trim() }, { mobile: (mobile ?? '').trim() }],
      },
      select: { id: true, name: true, mobile: true, donorCode: true },
    });

    const clash = candidates.find(
      (d) =>
        d.id !== excludeId &&
        DonorsService.normName(d.name) === wantName &&
        DonorsService.normMobile(d.mobile) === wantMobile,
    );
    if (clash) {
      throw new ConflictException(
        `${clash.name} with mobile ${clash.mobile} is already added (${clash.donorCode}).`,
      );
    }
  }

  async create(dto: CreateDonorDto) {
    await this.assertNotDuplicate(dto.name, dto.mobile);
    const { categoryIds, ...data } = dto;
    const donorCode = await this.nextCode();
    return this.prisma.donor.create({
      data: {
        ...data,
        donorCode,
        dob: data.dob ? new Date(data.dob) : undefined,
        anniversary: data.anniversary ? new Date(data.anniversary) : undefined,
        categories: categoryIds?.length
          ? { create: categoryIds.map((id) => ({ categoryId: id })) }
          : undefined,
      },
      include: this.include,
    });
  }

  async findAll(query: DonorQueryDto) {
    const { page = 1, limit = 20, search, tier, city, categoryId } = query;
    const where: any = { isActive: true };
    if (search) {
      where.OR = [
        { name: { contains: search } },
        { mobile: { contains: search } },
        { email: { contains: search } },
        { donorCode: { contains: search } },
      ];
    }
    if (tier) where.tier = tier;
    if (city) where.city = { contains: city };
    if (categoryId) where.categories = { some: { categoryId } };

    const [rows, total] = await Promise.all([
      this.prisma.donor.findMany({ where, select: this.listSelect, ...paginate(page, limit), orderBy: { createdAt: 'desc' } }),
      this.prisma.donor.count({ where }),
    ]);
    const withAvatar = new Set(
      (await this.prisma.donor.findMany({
        where: { id: { in: rows.map((r: any) => r.id) }, avatar: { not: null } },
        select: { id: true },
      })).map((r) => r.id),
    );
    const data = rows.map((r: any) => ({ ...r, hasAvatar: withAvatar.has(r.id) }));
    return paginatedResponse(data, total, page, limit);
  }

  async getAvatar(id: string) {
    const row = await this.prisma.donor.findUnique({ where: { id }, select: { id: true, avatar: true } });
    if (!row) throw new NotFoundException('Donor not found');
    return row;
  }

  async findOne(id: string) {
    const donor = await this.prisma.donor.findUnique({
      where: { id },
      include: {
        ...this.include,
        donations: { orderBy: { date: 'desc' }, take: 10, include: { type: true } },
        sponsorships: { include: { student: { select: { id: true, name: true, childId: true, center: true } } } },
      },
    });
    if (!donor) throw new NotFoundException('Donor not found');

    // Lifetime total — the included `donations` list above is capped at 10,
    // so it isn't enough on its own for a true all-time figure.
    const totalDonated = await this.prisma.donation.aggregate({
      where: { donorId: id },
      _sum: { amount: true },
    });

    return { ...donor, totalDonated: totalDonated._sum.amount ?? 0 };
  }

  async update(id: string, dto: UpdateDonorDto) {
    const current = await this.findOne(id);
    // Editing must not merge this donor onto an existing name + mobile either.
    if (dto.name !== undefined || dto.mobile !== undefined) {
      await this.assertNotDuplicate(dto.name ?? current.name, dto.mobile ?? current.mobile, id);
    }
    const { categoryIds, ...raw } = dto;
    // The edit form sends '' (or null) for a field the user cleared — store
    // that as NULL so it actually clears. Non-nullable columns are never
    // blanked (''/null there is ignored); undefined means "leave as is".
    const required = new Set(['name', 'mobile', 'gender', 'tier']);
    const data: Record<string, any> = {};
    for (const [k, v] of Object.entries(raw)) {
      if (v === undefined) continue;
      if (required.has(k)) {
        if (v !== '' && v !== null) data[k] = v;
        continue;
      }
      data[k] = v === '' ? null : v;
    }
    const toDate = (v: unknown) => (v === undefined ? undefined : v === null ? null : new Date(v as string));

    // Category replace is delete + recreate — one transaction so a failure
    // can't leave the donor stripped of its categories.
    return this.prisma.$transaction(async (tx) => {
      if (categoryIds !== undefined) {
        await tx.donorCategoryMap.deleteMany({ where: { donorId: id } });
      }
      return tx.donor.update({
        where: { id },
        data: {
          ...data,
          dob: toDate(data.dob),
          anniversary: toDate(data.anniversary),
          categories: categoryIds?.length
            ? { create: categoryIds.map((cid) => ({ categoryId: cid })) }
            : undefined,
        },
        include: this.include,
      });
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    return this.prisma.donor.update({ where: { id }, data: { isActive: false }, include: this.include });
  }

  async addActivityVideo(donorId: string, dto: CreateDonorActivityVideoDto) {
    await this.findOne(donorId);
    if (dto.data.length > MAX_VIDEO_BASE64_CHARS) {
      throw new BadRequestException('Video is too large — please upload a shorter clip (max ~20MB).');
    }
    return this.prisma.donorActivityVideo.create({
      data: {
        donorId,
        title: dto.title,
        activityDate: dto.activityDate ? new Date(dto.activityDate) : new Date(),
        fileName: dto.fileName,
        mimeType: dto.mimeType,
        data: dto.data,
        uploadedBy: dto.uploadedBy,
      },
      select: { id: true, donorId: true, title: true, activityDate: true, fileName: true, mimeType: true, uploadedBy: true, createdAt: true },
    });
  }

  // Metadata only (no `data`) — keeps the list light; fetch the full video
  // (with its base64 content) via getActivityVideo() when playing/downloading.
  async getActivityVideos(donorId: string) {
    return this.prisma.donorActivityVideo.findMany({
      where: { donorId },
      select: { id: true, donorId: true, title: true, activityDate: true, fileName: true, mimeType: true, uploadedBy: true, createdAt: true },
      orderBy: { activityDate: 'desc' },
    });
  }

  async getActivityVideo(videoId: string) {
    const video = await this.prisma.donorActivityVideo.findUnique({ where: { id: videoId } });
    if (!video) throw new NotFoundException('Video not found');
    return video;
  }

  async removeActivityVideo(videoId: string) {
    return this.prisma.donorActivityVideo.delete({ where: { id: videoId } });
  }

  async addActivityImage(donorId: string, dto: CreateDonorActivityImageDto) {
    await this.findOne(donorId);
    if (dto.data.length > MAX_IMAGE_BASE64_CHARS) {
      throw new BadRequestException('Image is too large — please upload a smaller photo (max ~5MB).');
    }
    return this.prisma.donorActivityImage.create({
      data: {
        donorId,
        title: dto.title,
        activityDate: dto.activityDate ? new Date(dto.activityDate) : new Date(),
        fileName: dto.fileName,
        mimeType: dto.mimeType,
        data: dto.data,
        uploadedBy: dto.uploadedBy,
      },
      select: { id: true, donorId: true, title: true, activityDate: true, fileName: true, mimeType: true, uploadedBy: true, createdAt: true },
    });
  }

  // Metadata only (no `data`) — keeps the list light; fetch the full image
  // (with its base64 content) via getActivityImage() when viewing.
  async getActivityImages(donorId: string) {
    return this.prisma.donorActivityImage.findMany({
      where: { donorId },
      select: { id: true, donorId: true, title: true, activityDate: true, fileName: true, mimeType: true, uploadedBy: true, createdAt: true },
      orderBy: { activityDate: 'desc' },
    });
  }

  async getActivityImage(imageId: string) {
    const image = await this.prisma.donorActivityImage.findUnique({ where: { id: imageId } });
    if (!image) throw new NotFoundException('Image not found');
    return image;
  }

  async removeActivityImage(imageId: string) {
    return this.prisma.donorActivityImage.delete({ where: { id: imageId } });
  }

  async summary() {
    const [total, byTier, totalRaised] = await Promise.all([
      this.prisma.donor.count({ where: { isActive: true } }),
      this.prisma.donor.groupBy({ by: ['tier'], _count: true, where: { isActive: true } }),
      this.prisma.donation.aggregate({ _sum: { amount: true } }),
    ]);
    return { total, byTier, totalRaised: totalRaised._sum.amount ?? 0 };
  }
}
