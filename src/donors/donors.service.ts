import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
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

  private async nextCode(): Promise<string> {
    const count = await this.prisma.donor.count();
    return `DID${String(count + 1).padStart(5, '0')}`;
  }

  async create(dto: CreateDonorDto) {
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
        { name: { contains: search, mode: 'insensitive' } },
        { mobile: { contains: search } },
        { email: { contains: search, mode: 'insensitive' } },
        { donorCode: { contains: search, mode: 'insensitive' } },
      ];
    }
    if (tier) where.tier = tier;
    if (city) where.city = { contains: city, mode: 'insensitive' };
    if (categoryId) where.categories = { some: { categoryId } };

    const [data, total] = await Promise.all([
      this.prisma.donor.findMany({ where, include: this.include, ...paginate(page, limit), orderBy: { createdAt: 'desc' } }),
      this.prisma.donor.count({ where }),
    ]);
    return paginatedResponse(data, total, page, limit);
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
    await this.findOne(id);
    const { categoryIds, ...data } = dto;
    if (categoryIds !== undefined) {
      await this.prisma.donorCategoryMap.deleteMany({ where: { donorId: id } });
    }
    return this.prisma.donor.update({
      where: { id },
      data: {
        ...data,
        dob: data.dob ? new Date(data.dob) : undefined,
        anniversary: data.anniversary ? new Date(data.anniversary) : undefined,
        categories: categoryIds?.length
          ? { create: categoryIds.map((cid) => ({ categoryId: cid })) }
          : undefined,
      },
      include: this.include,
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
