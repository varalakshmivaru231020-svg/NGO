import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateStudentDto } from './dto/create-student.dto';
import { UpdateStudentDto } from './dto/update-student.dto';
import { StudentQueryDto } from './dto/student-query.dto';
import { CreateSponsorshipDto } from './dto/create-sponsorship.dto';
import { MarkAttendanceDto } from './dto/mark-attendance.dto';
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
    const childId = await this.nextChildId(dto.centerId);
    return this.prisma.student.create({
      data: {
        ...dto,
        childId,
        dob: new Date(dto.dob),
        admissionDate: dto.admissionDate ? new Date(dto.admissionDate) : new Date(),
      },
      include: this.include,
    });
  }

  async findAll(query: StudentQueryDto) {
    const { page = 1, limit = 20, search, status, centerId } = query;
    const where: any = {};
    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { childId: { contains: search, mode: 'insensitive' } },
        { fatherName: { contains: search, mode: 'insensitive' } },
      ];
    }
    if (status) where.status = status;
    if (centerId) where.centerId = centerId;

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
      },
    });
    if (!student) throw new NotFoundException('Student not found');
    return student;
  }

  async update(id: string, dto: UpdateStudentDto) {
    await this.findOne(id);
    return this.prisma.student.update({
      where: { id },
      data: {
        ...dto,
        dob: dto.dob ? new Date(dto.dob) : undefined,
        admissionDate: dto.admissionDate ? new Date(dto.admissionDate) : undefined,
      },
      include: this.include,
    });
  }

  async addSponsorship(studentId: string, dto: CreateSponsorshipDto) {
    await this.findOne(studentId);
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
