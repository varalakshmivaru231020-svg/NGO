import { Injectable, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateDonorDto } from './dto/create-donor.dto';
import { UpdateDonorDto } from './dto/update-donor.dto';
import { DonorQueryDto } from './dto/donor-query.dto';
import { ImportDonorsDto, ImportDonorRowDto } from './dto/import-donors.dto';
import { CreateDonorActivityVideoDto } from './dto/create-donor-activity-video.dto';
import { CreateDonorActivityImageDto } from './dto/create-donor-activity-image.dto';
import { paginate, paginatedResponse } from '../common/dto/pagination.dto';

// ~20MB original video / ~27MB once base64-encoded — keeps well under the
// 30mb JSON body-parser limit configured in main.ts.
const MAX_VIDEO_BASE64_CHARS = 27 * 1024 * 1024;
// ~5MB original image / ~7MB once base64-encoded.
const MAX_IMAGE_BASE64_CHARS = 7 * 1024 * 1024;

// ── Bulk import helpers ──────────────────────────────────────────────
// Pure functions so the per-row rules can be unit-tested without a database.

export type ImportRowStatus = 'created' | 'skipped' | 'failed';

export interface ImportRowResult {
  row: number; // spreadsheet row number (header = 1), echoed from the client
  status: ImportRowStatus;
  name: string;
  mobile: string;
  donorCode?: string; // created
  reason?: string; // skipped (duplicate) / failed (bad data)
  note?: string; // created, but something in the row was ignored
}

const GENDER_WORDS: Record<string, string> = {
  m: 'MALE', male: 'MALE', f: 'FEMALE', female: 'FEMALE', o: 'OTHER', other: 'OTHER', others: 'OTHER',
};
const TIERS = new Set(['PLATINUM', 'GOLD', 'SILVER', 'BRONZE']);
const CONTACT_WORDS: Record<string, string> = {
  call: 'CALL', calls: 'CALL', phone: 'CALL', mobile: 'CALL',
  whatsapp: 'WHATSAPP', wa: 'WHATSAPP',
  email: 'EMAIL', mail: 'EMAIL', 'e-mail': 'EMAIL',
};
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const cleanCell = (v: unknown): string => (v === null || v === undefined ? '' : String(v).trim());

function ymd(y: number, mo: number, d: number): Date | null {
  if (y < 1900 || y > 2100 || mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  const dt = new Date(Date.UTC(y, mo - 1, d));
  return dt.getUTCMonth() === mo - 1 && dt.getUTCDate() === d ? dt : null; // rejects 31/02
}

/**
 * Reads the date forms a spreadsheet realistically holds: ISO (2024-03-15,
 * with or without a time), day-first with / - . separators (15/03/2024,
 * 15-3-24) and Excel's serial day count. Month-first is deliberately not
 * guessed — day-first is the convention here.
 *   undefined → cell blank (leave unset)    null → present but unreadable
 */
export function parseSheetDate(raw: unknown): Date | null | undefined {
  const s = cleanCell(raw);
  if (!s) return undefined;
  let m = /^(\d{4})-(\d{1,2})-(\d{1,2})(?:[T\s].*)?$/.exec(s);
  if (m) return ymd(+m[1], +m[2], +m[3]);
  m = /^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2}|\d{4})$/.exec(s);
  if (m) {
    let y = +m[3];
    if (y < 100) y += y < 50 ? 2000 : 1900;
    return ymd(y, +m[2], +m[1]);
  }
  if (/^\d{5}(\.\d+)?$/.test(s)) {
    const days = Math.floor(Number(s)); // Excel serial: days since 1899-12-30
    return new Date(Date.UTC(1899, 11, 30) + days * 86_400_000);
  }
  return null;
}

/** Digits only, keeping a leading "+": "+91 99860-64411" → "+919986064411". */
export function normalizeSheetMobile(raw: string): string {
  const s = raw.replace(/\.0+$/, ''); // "9986064411.0" from a numeric cell
  const digits = s.replace(/\D/g, '');
  return s.startsWith('+') && digits ? `+${digits}` : digits;
}

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

  // Same counter as nextCode(), but reserves `count` consecutive codes under
  // one lock — a 500-row import must not take the sequence lock 500 times.
  private async nextCodes(count: number): Promise<string[]> {
    if (count <= 0) return [];
    const key = 'donor-code';
    const last = await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`INSERT IGNORE INTO sequence_counters (\`key\`, seq) VALUES (${key}, 0)`;
      const rows = await tx.$queryRaw<{ seq: number }[]>`SELECT seq FROM sequence_counters WHERE \`key\` = ${key} FOR UPDATE`;
      const next = Number(rows[0].seq) + count;
      await tx.$executeRaw`UPDATE sequence_counters SET seq = ${next} WHERE \`key\` = ${key}`;
      return next;
    });
    const first = last - count + 1;
    return Array.from({ length: count }, (_, i) => `DID${String(first + i).padStart(5, '0')}`);
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

  /**
   * Bulk create from a spreadsheet. Never throws for a bad row — each row is
   * validated on its own and reported back as created / skipped / failed, so
   * one blank mobile doesn't sink a 300-row file. A duplicate (same name +
   * mobile as an existing donor, or as an earlier row of the same file) is
   * skipped rather than failed. Donor codes are reserved in one block for the
   * rows that will actually be created.
   */
  async importMany(dto: ImportDonorsDto) {
    const rows = dto.donors ?? [];

    // Lookups once per import, not per row.
    const [categories, existing] = await Promise.all([
      this.prisma.donorCategory.findMany({ select: { id: true, name: true } }),
      this.prisma.donor.findMany({
        where: { isActive: true },
        select: { name: true, mobile: true, donorCode: true },
      }),
    ]);
    const categoryByName = new Map(categories.map((c) => [DonorsService.normName(c.name), c.id]));
    const pairKey = (name: string, mobile: string) =>
      `${DonorsService.normName(name)}|${DonorsService.normMobile(mobile)}`;
    const taken = new Map<string, string>(); // name|mobile → donorCode or "row N"
    for (const d of existing) taken.set(pairKey(d.name, d.mobile), d.donorCode);

    const prepared = rows.map((r, i) => this.prepareImportRow(r, r.row ?? i + 2, categoryByName));

    // Duplicate pass runs after validation so a bad row never reserves a pair.
    for (const p of prepared) {
      if (p.result.status !== 'created') continue;
      const key = pairKey(p.result.name, p.result.mobile);
      const holder = taken.get(key);
      if (holder) {
        p.result.status = 'skipped';
        p.result.reason = holder.startsWith('row ')
          ? `Same name and mobile as ${holder} of this file`
          : `Already added as ${holder}`;
        p.data = undefined;
        continue;
      }
      taken.set(key, `row ${p.result.row}`);
    }

    const toCreate = prepared.filter((p) => p.data);
    const codes = await this.nextCodes(toCreate.length);
    for (let i = 0; i < toCreate.length; i++) {
      const p = toCreate[i];
      const donorCode = codes[i];
      try {
        await this.prisma.donor.create({
          data: {
            ...p.data!,
            donorCode,
            categories: p.categoryIds?.length
              ? { create: p.categoryIds.map((categoryId) => ({ categoryId })) }
              : undefined,
          },
          select: { id: true },
        });
        p.result.donorCode = donorCode;
      } catch (e) {
        // A DB-level refusal (value too long, etc.) fails just this row.
        p.result.status = 'failed';
        p.result.reason =
          (e instanceof Error && e.message.trim().split('\n').pop()?.trim()) || 'Database error';
      }
    }

    const results = prepared.map((p) => p.result);
    const count = (s: ImportRowStatus) => results.filter((r) => r.status === s).length;
    return {
      total: results.length,
      created: count('created'),
      skipped: count('skipped'),
      failed: count('failed'),
      results,
    };
  }

  // One row → a create payload, or a failure reason naming every bad cell.
  private prepareImportRow(
    r: ImportDonorRowDto,
    rowNo: number,
    categoryByName: Map<string, string>,
  ): {
    result: ImportRowResult;
    data?: Omit<Prisma.DonorCreateInput, 'donorCode' | 'categories'>;
    categoryIds?: string[];
  } {
    const name = cleanCell(r.name).replace(/\s+/g, ' ');
    const rawMobile = cleanCell(r.mobile);
    const mobile = normalizeSheetMobile(rawMobile);
    const result: ImportRowResult = { row: rowNo, status: 'created', name, mobile: mobile || rawMobile };

    const problems: string[] = [];
    if (!name) problems.push('Name is missing');
    else if (name.length > 191) problems.push('Name is too long');
    const digits = mobile.replace(/\D/g, '');
    if (!digits) problems.push('Mobile is missing');
    else if (digits.length < 10 || digits.length > 15) problems.push(`Mobile "${rawMobile}" must have 10–15 digits`);

    const genderWord = cleanCell(r.gender).toLowerCase();
    const gender = genderWord ? GENDER_WORDS[genderWord] : 'MALE';
    if (!gender) problems.push(`Gender "${r.gender}" should be Male, Female or Other`);

    const tier = cleanCell(r.tier).toUpperCase() || 'SILVER';
    if (!TIERS.has(tier)) problems.push(`Tier "${r.tier}" should be Platinum, Gold, Silver or Bronze`);

    const email = cleanCell(r.email).toLowerCase();
    if (email && !EMAIL_RE.test(email)) problems.push(`Email "${email}" is not valid`);

    const dob = parseSheetDate(r.dob);
    if (dob === null) problems.push(`Date of birth "${r.dob}" is not a readable date (use DD/MM/YYYY)`);
    const anniversary = parseSheetDate(r.anniversary);
    if (anniversary === null) problems.push(`Anniversary "${r.anniversary}" is not a readable date (use DD/MM/YYYY)`);

    if (problems.length) return { result: { ...result, status: 'failed', reason: problems.join('; ') } };

    const notes: string[] = [];
    const categoryIds: string[] = [];
    for (const label of cleanCell(r.category).split(/[,;|]/)) {
      const want = DonorsService.normName(label);
      if (!want) continue;
      const id = categoryByName.get(want);
      if (!id) notes.push(`Category "${label.trim()}" not found — left unassigned`);
      else if (!categoryIds.includes(id)) categoryIds.push(id);
    }

    const contactWords = cleanCell(r.preferredContactMethod)
      .split(/[,;|/&]/)
      .map((w) => CONTACT_WORDS[w.trim().toLowerCase()])
      .filter((w): w is string => !!w);
    const contact = Array.from(new Set(contactWords)).join(',');

    const opt = (v: unknown) => cleanCell(v) || undefined;
    const data = {
      name,
      mobile,
      whatsapp: opt(normalizeSheetMobile(cleanCell(r.whatsapp))),
      email: email || undefined,
      gender,
      dob: dob ?? undefined,
      anniversary: anniversary ?? undefined,
      address: opt(r.address),
      city: opt(r.city),
      state: opt(r.state),
      country: opt(r.country),
      pincode: opt(cleanCell(r.pincode).replace(/\.0+$/, '')),
      occupation: opt(r.occupation),
      company: opt(r.company),
      tier,
      notes: opt(r.notes),
      pan: opt(cleanCell(r.pan).toUpperCase()),
      aadhaar: opt(cleanCell(r.aadhaar).replace(/\.0+$/, '').replace(/\s+/g, '')),
      preferredContactMethod: contact || undefined,
    };
    if (notes.length) result.note = notes.join('; ');
    return { result, data, categoryIds };
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
