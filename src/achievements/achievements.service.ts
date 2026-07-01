import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateAchievementDto } from './dto/create-achievement.dto';
import { UpdateAchievementDto } from './dto/update-achievement.dto';
import { PaginationDto, paginate, paginatedResponse } from '../common/dto/pagination.dto';

@Injectable()
export class AchievementsService {
  constructor(private prisma: PrismaService) {}

  private include = {
    student: { select: { id: true, name: true, childId: true, center: true } },
  };

  async create(dto: CreateAchievementDto) {
    return this.prisma.achievement.create({
      data: { ...dto, date: dto.date ? new Date(dto.date) : new Date() },
      include: this.include,
    });
  }

  async findAll(query: PaginationDto & { category?: string; studentId?: string }) {
    const { page = 1, limit = 20, search, category, studentId } = query;
    const where: any = {};
    if (search) where.title = { contains: search, mode: 'insensitive' };
    if (category) where.category = category;
    if (studentId) where.studentId = studentId;
    const [data, total] = await Promise.all([
      this.prisma.achievement.findMany({ where, include: this.include, ...paginate(page, limit), orderBy: { date: 'desc' } }),
      this.prisma.achievement.count({ where }),
    ]);
    return paginatedResponse(data, total, page, limit);
  }

  async findOne(id: string) {
    const a = await this.prisma.achievement.findUnique({ where: { id }, include: this.include });
    if (!a) throw new NotFoundException('Achievement not found');
    return a;
  }

  async update(id: string, dto: UpdateAchievementDto) {
    await this.findOne(id);
    return this.prisma.achievement.update({
      where: { id },
      data: { ...dto, date: dto.date ? new Date(dto.date) : undefined },
      include: this.include,
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    return this.prisma.achievement.delete({ where: { id } });
  }
}
