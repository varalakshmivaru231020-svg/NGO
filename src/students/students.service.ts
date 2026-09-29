import { BadRequestException, ConflictException, Injectable, NotFoundException, OnModuleInit, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateStudentDto } from './dto/create-student.dto';
import { UpdateStudentDto } from './dto/update-student.dto';
import { StudentQueryDto } from './dto/student-query.dto';
import { CreateSponsorshipDto } from './dto/create-sponsorship.dto';
import { MarkAttendanceDto } from './dto/mark-attendance.dto';
import { CreateGrowthRecordDto } from './dto/create-growth-record.dto';
import { CreateStudentDocumentDto } from './dto/create-student-document.dto';
import { CreateProgressRecordDto } from './dto/create-progress-record.dto';
import { CreateStudentCategoryDto, UpdateStudentCategoryDto } from './dto/student-category.dto';
import { CreateStudentLookupDto, UpdateStudentLookupDto, STUDENT_LOOKUP_TYPES, StudentLookupType } from './dto/student-lookup.dto';
import { paginate, paginatedResponse } from '../common/dto/pagination.dto';

// Seeded the first time a list is empty. Keys match the values the app has
// always stored in Student.status, so existing children keep their status.
const DEFAULT_LOOKUPS: Record<StudentLookupType, { key: string; label: string; isSystem?: boolean }[]> = {
  STATUS: [
    { key: 'ACTIVE', label: 'Active', isSystem: true },
    { key: 'DROPPED', label: 'Drop Out' },
    { key: 'INACTIVE', label: 'Relieved' },
    { key: 'GRADUATED', label: 'Graduated' },
    { key: 'FORMER', label: 'Former Student' },
  ],
  EDUCATION_LEVEL: [
    { key: 'PRIMARY', label: 'Primary School' },
    { key: 'HIGH_SCHOOL', label: 'High School' },
    { key: 'INTERMEDIATE', label: 'Intermediate / Junior College' },
    { key: 'COLLEGE', label: 'College / Degree' },
  ],
};

@Injectable()
export class StudentsService implements OnModuleInit {
  private readonly logger = new Logger(StudentsService.name);
  constructor(private prisma: PrismaService) {}

  async onModuleInit() {
    try {
      for (const type of STUDENT_LOOKUP_TYPES) {
        if (await this.prisma.studentLookup.count({ where: { type } })) continue;
        await this.prisma.studentLookup.createMany({
          data: DEFAULT_LOOKUPS[type].map((d, i) => ({ type, key: d.key, label: d.label, isSystem: !!d.isSystem, sortOrder: i })),
          skipDuplicates: true,
        });
      }
    } catch (e) {
      // Table not pushed yet — the app still runs, lists just come back empty.
      this.logger.warn(`Could not seed student lookups: ${(e as Error).message}`);
    }
  }

  private include = {
    center: true,
    category: true,
    sponsorships: {
      where: { isActive: true },
      include: { donor: { select: { id: true, name: true, mobile: true, donorCode: true } } },
    },
    _count: { select: { achievements: true, attendance: true } },
  };

  // List rows leave out the base64 photo (100–300KB each). Returning it for
  // every row made a page of 100 students several MB; the app pages through
  // everything, so lists timed out and showed 0. Cards lazy-load the photo
  // from GET /students/:id/photo using the `hasPhoto` flag instead.
  private listSelect = {
    ...Object.fromEntries(
      Object.keys(Prisma.StudentScalarFieldEnum).filter((k) => k !== 'photo').map((k) => [k, true]),
    ),
    center: true,
    category: true,
    sponsorships: this.include.sponsorships,
    _count: this.include._count,
  } as Prisma.StudentSelect;

  // A bad categoryId would otherwise surface as an opaque Prisma FK error —
  // reject it up front. Empty string means "no category" (app convenience).
  private async assertCategoryExists(categoryId?: string | null) {
    if (!categoryId) return;
    const cat = await this.prisma.studentCategory.findUnique({ where: { id: categoryId } });
    if (!cat) throw new NotFoundException('Student category not found');
  }

  // status / educationLevel hold StudentLookup keys; reject anything that
  // isn't in the admin-managed list instead of storing free text.
  private async assertLookupKey(type: StudentLookupType, key?: string | null) {
    if (!key) return;
    const row = await this.prisma.studentLookup.findUnique({ where: { type_key: { type, key } } });
    if (!row) {
      const what = type === 'STATUS' ? 'student status' : 'education level';
      throw new BadRequestException(`Unknown ${what} "${key}" — add it under Settings first`);
    }
  }

  private async nextChildId(centerId: string): Promise<string> {
    const center = await this.prisma.center.findUnique({ where: { id: centerId } });
    const prefix = center?.name?.substring(0, 3).toUpperCase() ?? 'SKT';
    // childId is globally @unique, but a per-centre row count collides after
    // any deletion (count shrinks, id gets re-minted) and across centres that
    // share a 3-letter prefix — so derive the next number from the highest
    // existing id with this prefix instead.
    const existing = await this.prisma.student.findMany({
      where: { childId: { startsWith: prefix } },
      select: { childId: true },
    });
    let max = 0;
    for (const { childId } of existing) {
      const n = parseInt(childId.slice(prefix.length), 10);
      if (!isNaN(n) && n > max) max = n;
    }
    return `${prefix}${String(max + 1).padStart(4, '0')}`;
  }

  async create(dto: CreateStudentDto) {
    const { documents, ...rest } = dto;
    await this.assertCategoryExists(dto.categoryId);
    await this.assertLookupKey('STATUS', dto.status);
    await this.assertLookupKey('EDUCATION_LEVEL', dto.educationLevel);
    // The student and its documents are written in one transaction: a failed
    // document insert used to leave the student behind while the app showed an
    // error, so the retry created a duplicate child.
    const attempt = async () => {
      const childId = await this.nextChildId(dto.centerId);
      return this.prisma.$transaction(async (tx) => {
        const student = await tx.student.create({
          data: {
            ...rest,
            childId,
            categoryId: dto.categoryId || null,
            educationLevel: dto.educationLevel || null,
            dob: new Date(dto.dob),
            admissionDate: dto.admissionDate ? new Date(dto.admissionDate) : new Date(),
            joiningDate: dto.joiningDate ? new Date(dto.joiningDate) : undefined,
          },
          include: this.include,
        });
        // Documents picked before the student existed (see CreateStudentDto).
        if (documents?.length) {
          await tx.studentDocument.createMany({
            data: documents.map((d) => ({
              studentId: student.id,
              category: d.category,
              fileName: d.fileName,
              mimeType: d.mimeType,
              data: d.data,
            })),
          });
        }
        return student;
      }, { timeout: 60_000 });
    };
    // Two children added at the same moment can compute the same childId;
    // the unique index rejects the second, so mint a fresh id and retry.
    for (let i = 0; ; i++) {
      try {
        return await attempt();
      } catch (e) {
        const dup = e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002'
          && String((e.meta as any)?.target ?? '').includes('childId');
        if (!dup || i >= 3) throw e;
      }
    }
  }

  async findAll(query: StudentQueryDto) {
    const { page = 1, limit = 20, search, status, centerId, categoryId, sponsorDonorId } = query;
    const where: any = {};
    if (search) {
      where.OR = [
        { name: { contains: search } },
        { childId: { contains: search } },
        { fatherName: { contains: search } },
      ];
    }
    if (status) where.status = status;
    if (centerId) where.centerId = centerId;
    if (categoryId) where.categoryId = categoryId;
    if (sponsorDonorId) where.sponsorships = { some: { donorId: sponsorDonorId, isActive: true } };

    const [rows, total] = await Promise.all([
      this.prisma.student.findMany({ where, select: this.listSelect, ...paginate(page, limit), orderBy: { createdAt: 'desc' } }),
      this.prisma.student.count({ where }),
    ]);
    const withPhoto = new Set(
      (await this.prisma.student.findMany({
        where: { id: { in: rows.map((r: any) => r.id) }, photo: { not: null } },
        select: { id: true },
      })).map((r) => r.id),
    );
    const data = rows.map((r: any) => ({ ...r, hasPhoto: withPhoto.has(r.id) }));
    return paginatedResponse(data, total, page, limit);
  }

  async findOne(id: string) {
    const student = await this.prisma.student.findUnique({
      where: { id },
      include: {
        ...this.include,
        achievements: { orderBy: { date: 'desc' }, take: 10 },
        attendance: { orderBy: { date: 'desc' }, take: 30 },
        progressRecords: { orderBy: { date: 'desc' }, take: 10 },
        _count: { select: { achievements: true, attendance: true, progressRecords: true } },
      },
    });
    if (!student) throw new NotFoundException('Student not found');
    return student;
  }

  async getPhoto(id: string) {
    const row = await this.prisma.student.findUnique({ where: { id }, select: { id: true, photo: true } });
    if (!row) throw new NotFoundException('Student not found');
    return row;
  }

  async update(id: string, dto: UpdateStudentDto) {
    await this.findOne(id);
    await this.assertCategoryExists(dto.categoryId);
    await this.assertLookupKey('STATUS', dto.status);
    await this.assertLookupKey('EDUCATION_LEVEL', dto.educationLevel);
    const { documents: _documents, ...rest } = dto;
    return this.prisma.student.update({
      where: { id },
      data: {
        ...rest,
        // '' clears the category; absent leaves it untouched.
        categoryId: dto.categoryId === undefined ? undefined : (dto.categoryId || null),
        educationLevel: dto.educationLevel === undefined ? undefined : (dto.educationLevel || null),
        dob: dto.dob ? new Date(dto.dob) : undefined,
        admissionDate: dto.admissionDate ? new Date(dto.admissionDate) : undefined,
        joiningDate: dto.joiningDate ? new Date(dto.joiningDate) : undefined,
      },
      include: this.include,
    });
  }

  // ── Student categories (Settings → Student Categories) ────────────────
  async findCategories() {
    return this.prisma.studentCategory.findMany({ where: { isActive: true }, orderBy: { label: 'asc' } });
  }

  async findAllCategories() {
    return this.prisma.studentCategory.findMany({
      orderBy: { label: 'asc' },
      include: { _count: { select: { students: true } } },
    });
  }

  async createCategory(dto: CreateStudentCategoryDto) {
    const label = dto.label.trim();
    // @IsNotEmpty passes '   ' — and the app's edit sheet maps selections by
    // label, so blank or duplicate labels must be rejected here.
    if (!label) throw new BadRequestException('Category name is required');
    if (await this.prisma.studentCategory.findFirst({ where: { label } }))
      throw new ConflictException('A category with this name already exists');
    const base = label.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '') || 'category';
    let key = base;
    for (let i = 2; await this.prisma.studentCategory.findUnique({ where: { key } }); i++) key = `${base}-${i}`;
    return this.prisma.studentCategory.create({
      data: { key, label, description: dto.description?.trim() || null },
    });
  }

  async updateCategory(id: string, dto: UpdateStudentCategoryDto) {
    const existing = await this.prisma.studentCategory.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Student category not found');
    if (dto.label !== undefined) {
      const label = dto.label.trim();
      if (!label) throw new BadRequestException('Category name is required');
      if (await this.prisma.studentCategory.findFirst({ where: { label, NOT: { id } } }))
        throw new ConflictException('A category with this name already exists');
    }
    return this.prisma.studentCategory.update({
      where: { id },
      data: {
        ...(dto.label !== undefined ? { label: dto.label.trim() } : {}),
        ...(dto.description !== undefined ? { description: dto.description?.trim() || null } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
      },
    });
  }

  // Only an unused category can be removed — otherwise children would lose
  // their category silently. Deactivating hides it from Add Student instead.
  async removeCategory(id: string) {
    const existing = await this.prisma.studentCategory.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Student category not found');
    const inUse = await this.prisma.student.count({ where: { categoryId: id } });
    if (inUse) {
      throw new ConflictException(
        `"${existing.label}" is assigned to ${inUse} student${inUse === 1 ? '' : 's'}. ` +
        'Move them to another category first, or switch it off instead of deleting.');
    }
    await this.prisma.studentCategory.delete({ where: { id } });
    return { id, deleted: true };
  }

  // ── Student status / education level lists (Settings) ─────────────────
  private assertLookupType(type: string): StudentLookupType {
    const t = (type ?? '').toUpperCase();
    if (!(STUDENT_LOOKUP_TYPES as readonly string[]).includes(t))
      throw new BadRequestException(`Unknown list "${type}" — use ${STUDENT_LOOKUP_TYPES.join(' or ')}`);
    return t as StudentLookupType;
  }

  private async lookupUsage(type: StudentLookupType, key?: string) {
    return type === 'STATUS'
      ? this.prisma.student.count({ where: key ? { status: key } : {} })
      : this.prisma.student.count({ where: key ? { educationLevel: key } : {} });
  }

  async findLookups(type: string, includeInactive = false) {
    const t = this.assertLookupType(type);
    const rows = await this.prisma.studentLookup.findMany({
      where: { type: t, ...(includeInactive ? {} : { isActive: true }) },
      orderBy: [{ sortOrder: 'asc' }, { label: 'asc' }],
    });
    if (!includeInactive) return rows;
    // The admin list also shows how many children use each entry.
    const counts: { key: string | null; n: number }[] = t === 'STATUS'
      ? (await this.prisma.student.groupBy({ by: ['status'], _count: { _all: true } }))
          .map((c) => ({ key: c.status, n: c._count._all }))
      : (await this.prisma.student.groupBy({ by: ['educationLevel'], _count: { _all: true } }))
          .map((c) => ({ key: c.educationLevel, n: c._count._all }));
    const byKey = new Map(counts.map((c) => [c.key, c.n]));
    return rows.map((r) => ({ ...r, studentCount: byKey.get(r.key) ?? 0 }));
  }

  async createLookup(type: string, dto: CreateStudentLookupDto) {
    const t = this.assertLookupType(type);
    const label = dto.label.trim();
    if (!label) throw new BadRequestException('Name is required');
    if (await this.prisma.studentLookup.findFirst({ where: { type: t, label } }))
      throw new ConflictException(`"${label}" already exists`);
    const base = label.toUpperCase().replace(/[^A-Z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'ITEM';
    let key = base;
    for (let i = 2; await this.prisma.studentLookup.findUnique({ where: { type_key: { type: t, key } } }); i++) key = `${base}_${i}`;
    const max = await this.prisma.studentLookup.aggregate({ where: { type: t }, _max: { sortOrder: true } });
    return this.prisma.studentLookup.create({
      data: {
        type: t, key, label,
        description: dto.description?.trim() || null,
        sortOrder: dto.sortOrder ?? (max._max.sortOrder ?? -1) + 1,
      },
    });
  }

  async updateLookup(id: string, dto: UpdateStudentLookupDto) {
    const existing = await this.prisma.studentLookup.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Entry not found');
    let label: string | undefined;
    if (dto.label !== undefined) {
      label = dto.label.trim();
      if (!label) throw new BadRequestException('Name is required');
      if (await this.prisma.studentLookup.findFirst({ where: { type: existing.type, label, NOT: { id } } }))
        throw new ConflictException(`"${label}" already exists`);
    }
    if (dto.isActive === false && existing.isSystem)
      throw new BadRequestException(`"${existing.label}" is built in and cannot be switched off (you can rename it)`);
    return this.prisma.studentLookup.update({
      where: { id },
      data: {
        ...(label !== undefined ? { label } : {}),
        ...(dto.description !== undefined ? { description: dto.description?.trim() || null } : {}),
        ...(dto.sortOrder !== undefined ? { sortOrder: dto.sortOrder } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
      },
    });
  }

  async removeLookup(id: string) {
    const existing = await this.prisma.studentLookup.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Entry not found');
    if (existing.isSystem)
      throw new BadRequestException(`"${existing.label}" is built in and cannot be deleted (you can rename it)`);
    const inUse = await this.lookupUsage(existing.type as StudentLookupType, existing.key);
    if (inUse) {
      throw new ConflictException(
        `"${existing.label}" is used by ${inUse} student${inUse === 1 ? '' : 's'}. ` +
        'Change them first, or switch it off instead of deleting.');
    }
    await this.prisma.studentLookup.delete({ where: { id } });
    return { id, deleted: true };
  }

  async addSponsorship(studentId: string, dto: CreateSponsorshipDto) {
    await this.findOne(studentId);
    // A student has at most one active sponsor at a time — retire any
    // existing one so assigning a new sponsor behaves like "replace", not "add".
    await this.prisma.sponsorship.updateMany({
      where: { studentId, isActive: true },
      data: { isActive: false, endDate: new Date() },
    });
    return this.prisma.sponsorship.create({
      data: {
        studentId,
        donorId: dto.donorId,
        amount: dto.amount,
        frequency: dto.frequency ?? 'ANNUAL',
        endDate: dto.endDate ? new Date(dto.endDate) : undefined,
        notes: dto.notes,
      },
      include: { donor: { select: { id: true, name: true, mobile: true } } },
    });
  }

  async removeSponsorship(sponsorshipId: string) {
    return this.prisma.sponsorship.update({
      where: { id: sponsorshipId },
      data: { isActive: false, endDate: new Date() },
    });
  }

  async markAttendance(studentId: string, dto: MarkAttendanceDto) {
    await this.findOne(studentId);
    return this.prisma.attendance.upsert({
      where: { studentId_date: { studentId, date: new Date(dto.date) } },
      create: { studentId, date: new Date(dto.date), present: dto.present ?? true, notes: dto.notes },
      update: { present: dto.present ?? true, notes: dto.notes },
    });
  }

  async getAttendance(studentId: string, month: string) {
    // Explicit numeric construction — new Date('YYYY-MM-01') parses as UTC
    // while the old end-of-month used local getters, silently dropping the
    // last day of every month (or the whole month in UTC-behind timezones).
    const [y, m] = month.split('-').map(Number);
    const start = new Date(y, m - 1, 1);
    const end = new Date(y, m, 1); // first day of next month, exclusive
    return this.prisma.attendance.findMany({
      where: { studentId, date: { gte: start, lt: end } },
      orderBy: { date: 'asc' },
    });
  }

  // One entry per day; re-adding the same date overwrites it rather than
  // duplicating (matches markAttendance's upsert-by-date pattern).
  async addGrowthRecord(studentId: string, dto: CreateGrowthRecordDto) {
    await this.findOne(studentId);
    return this.prisma.growthRecord.upsert({
      where: { studentId_date: { studentId, date: new Date(dto.date) } },
      create: { studentId, date: new Date(dto.date), heightCm: dto.heightCm, weightKg: dto.weightKg, notes: dto.notes },
      update: { heightCm: dto.heightCm, weightKg: dto.weightKg, notes: dto.notes },
    });
  }

  // Full history (small dataset — a handful of measurements over a
  // childhood), oldest first so it plots directly on a chart.
  async getGrowthRecords(studentId: string) {
    return this.prisma.growthRecord.findMany({
      where: { studentId },
      orderBy: { date: 'asc' },
    });
  }

  async removeGrowthRecord(recordId: string) {
    return this.prisma.growthRecord.delete({ where: { id: recordId } });
  }

  async addDocument(studentId: string, dto: CreateStudentDocumentDto) {
    await this.findOne(studentId);
    return this.prisma.studentDocument.create({
      data: { studentId, category: dto.category, fileName: dto.fileName, mimeType: dto.mimeType, data: dto.data },
      select: { id: true, studentId: true, category: true, fileName: true, mimeType: true, createdAt: true },
    });
  }

  // Metadata only (no `data`) — keeps the list light; fetch the full
  // document (with its base64 content) via getDocument() when viewing.
  async getDocuments(studentId: string) {
    return this.prisma.studentDocument.findMany({
      where: { studentId },
      select: { id: true, studentId: true, category: true, fileName: true, mimeType: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getDocument(docId: string) {
    const doc = await this.prisma.studentDocument.findUnique({ where: { id: docId } });
    if (!doc) throw new NotFoundException('Document not found');
    return doc;
  }

  async removeDocument(docId: string) {
    return this.prisma.studentDocument.delete({ where: { id: docId } });
  }

  async addProgressRecord(studentId: string, dto: CreateProgressRecordDto) {
    await this.findOne(studentId);
    return this.prisma.progressRecord.create({
      data: { studentId, ...dto, date: dto.date ? new Date(dto.date) : new Date() },
    });
  }

  // Newest-first history; paginated (page/limit) since a student can
  // accumulate many check-ins over the years.
  async getProgressRecords(studentId: string, page = 1, limit = 10) {
    const [data, total] = await Promise.all([
      this.prisma.progressRecord.findMany({
        where: { studentId },
        orderBy: { date: 'desc' },
        ...paginate(page, limit),
      }),
      this.prisma.progressRecord.count({ where: { studentId } }),
    ]);
    return paginatedResponse(data, total, page, limit);
  }

  async removeProgressRecord(recordId: string) {
    return this.prisma.progressRecord.delete({ where: { id: recordId } });
  }

  async summary() {
    const [total, byStatus, byCenter] = await Promise.all([
      this.prisma.student.count(),
      this.prisma.student.groupBy({ by: ['status'], _count: true }),
      this.prisma.student.groupBy({ by: ['centerId'], _count: true }),
    ]);
    return { total, byStatus, byCenter };
  }

  async findCenters() {
    return this.prisma.center.findMany({ where: { isActive: true }, include: { _count: { select: { students: true } } } });
  }

  async createCenter(name: string, city?: string, address?: string) {
    return this.prisma.center.create({ data: { name, city, address } });
  }

  async updateCenter(id: string, data: { name?: string; city?: string; address?: string }) {
    return this.prisma.center.update({
      where: { id },
      data,
      include: { _count: { select: { students: true } } },
    });
  }

  async removeCenter(id: string) {
    return this.prisma.center.update({
      where: { id },
      data: { isActive: false },
      include: { _count: { select: { students: true } } },
    });
  }
}
