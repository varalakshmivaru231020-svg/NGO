import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateStudentDto } from './dto/create-student.dto';
import { UpdateStudentDto } from './dto/update-student.dto';
import { StudentQueryDto } from './dto/student-query.dto';
import { CreateSponsorshipDto } from './dto/create-sponsorship.dto';
import { MarkAttendanceDto } from './dto/mark-attendance.dto';
import { CreateGrowthRecordDto } from './dto/create-growth-record.dto';
import { CreateStudentDocumentDto } from './dto/create-student-document.dto';
import { CreateProgressRecordDto } from './dto/create-progress-record.dto';
import { paginate, paginatedResponse } from '../common/dto/pagination.dto';

@Injectable()
export class StudentsService {
  constructor(private prisma: PrismaService) {}

  private include = {
    center: true,
    sponsorships: {
      where: { isActive: true },
      include: { donor: { select: { id: true, name: true, mobile: true, donorCode: true } } },
    },
    _count: { select: { achievements: true, attendance: true } },
  };

  private async nextChildId(centerId: string): Promise<string> {
    const center = await this.prisma.center.findUnique({ where: { id: centerId } });
    const prefix = center?.name?.substring(0, 3).toUpperCase() ?? 'SKT';
    const count = await this.prisma.student.count({ where: { centerId } });
    return `${prefix}${String(count + 1).padStart(4, '0')}`;
  }

  async create(dto: CreateStudentDto) {
    const { documents, ...rest } = dto;
    const childId = await this.nextChildId(dto.centerId);
    const student = await this.prisma.student.create({
      data: {
        ...rest,
        childId,
        dob: new Date(dto.dob),
        admissionDate: dto.admissionDate ? new Date(dto.admissionDate) : new Date(),
        joiningDate: dto.joiningDate ? new Date(dto.joiningDate) : undefined,
      },
      include: this.include,
    });
    // Documents picked before the student existed — created here, using the
    // real new id, instead of a separate follow-up request (see CreateStudentDto).
    if (documents?.length) {
      await this.prisma.studentDocument.createMany({
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
  }

  async findAll(query: StudentQueryDto) {
    const { page = 1, limit = 20, search, status, centerId, sponsorDonorId } = query;
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
    if (sponsorDonorId) where.sponsorships = { some: { donorId: sponsorDonorId, isActive: true } };

    const [data, total] = await Promise.all([
      this.prisma.student.findMany({ where, include: this.include, ...paginate(page, limit), orderBy: { createdAt: 'desc' } }),
      this.prisma.student.count({ where }),
    ]);
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

  async update(id: string, dto: UpdateStudentDto) {
    await this.findOne(id);
    const { documents: _documents, ...rest } = dto;
    return this.prisma.student.update({
      where: { id },
      data: {
        ...rest,
        dob: dto.dob ? new Date(dto.dob) : undefined,
        admissionDate: dto.admissionDate ? new Date(dto.admissionDate) : undefined,
        joiningDate: dto.joiningDate ? new Date(dto.joiningDate) : undefined,
      },
      include: this.include,
    });
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
    const start = new Date(`${month}-01`);
    const end = new Date(start.getFullYear(), start.getMonth() + 1, 0);
    return this.prisma.attendance.findMany({
      where: { studentId, date: { gte: start, lte: end } },
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
