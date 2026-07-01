import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateDonorDto } from './dto/create-donor.dto';
import { UpdateDonorDto } from './dto/update-donor.dto';
import { DonorQueryDto } from './dto/donor-query.dto';
import { paginate, paginatedResponse } from '../common/dto/pagination.dto';

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
    return donor;
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

  async summary() {
    const [total, byTier, totalRaised] = await Promise.all([
      this.prisma.donor.count({ where: { isActive: true } }),
      this.prisma.donor.groupBy({ by: ['tier'], _count: true, where: { isActive: true } }),
      this.prisma.donation.aggregate({ _sum: { amount: true } }),
    ]);
    return { total, byTier, totalRaised: totalRaised._sum.amount ?? 0 };
  }
}
