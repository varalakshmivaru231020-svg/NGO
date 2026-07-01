import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';

@Injectable()
export class CategoriesService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreateCategoryDto) {
    return this.prisma.donorCategory.create({ data: dto });
  }

  async findAll() {
    const cats = await this.prisma.donorCategory.findMany({
      orderBy: { sortOrder: 'asc' },
      include: { _count: { select: { donors: true } } },
    });
    return cats;
  }

  async findOne(id: string) {
    const cat = await this.prisma.donorCategory.findUnique({
      where: { id },
      include: {
        donors: { include: { donor: { select: { id: true, name: true, tier: true, mobile: true } } } },
        _count: { select: { donors: true } },
      },
    });
    if (!cat) throw new NotFoundException('Category not found');
    return cat;
  }

  async update(id: string, dto: UpdateCategoryDto) {
    await this.findOne(id);
    return this.prisma.donorCategory.update({ where: { id }, data: dto });
  }

  async remove(id: string) {
    await this.findOne(id);
    return this.prisma.donorCategory.delete({ where: { id } });
  }
}
