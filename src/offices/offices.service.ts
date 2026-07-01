import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateOfficeDto } from './dto/create-office.dto';
import { UpdateOfficeDto } from './dto/update-office.dto';

@Injectable()
export class OfficesService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreateOfficeDto) {
    return this.prisma.office.create({ data: dto, include: { _count: { select: { users: true } } } });
  }

  async findAll() {
    return this.prisma.office.findMany({
      where: { isActive: true },
      include: { _count: { select: { users: true } } },
      orderBy: [{ isHQ: 'desc' }, { name: 'asc' }],
    });
  }

  async findOne(id: string) {
    const office = await this.prisma.office.findUnique({
      where: { id },
      include: {
        users: { select: { id: true, name: true, role: true, email: true } },
        _count: { select: { users: true } },
      },
    });
    if (!office) throw new NotFoundException('Office not found');
    return office;
  }

  async update(id: string, dto: UpdateOfficeDto) {
    await this.findOne(id);
    return this.prisma.office.update({ where: { id }, data: dto });
  }

  async remove(id: string) {
    await this.findOne(id);
    return this.prisma.office.update({ where: { id }, data: { isActive: false } });
  }
}
