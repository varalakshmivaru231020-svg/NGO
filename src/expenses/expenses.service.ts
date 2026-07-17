import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { UpdateExpenseDto } from './dto/update-expense.dto';
import { ExpenseQueryDto } from './dto/expense-query.dto';
import { paginate, paginatedResponse } from '../common/dto/pagination.dto';
import type { SessionUser } from '../approvals/approvals.service';

@Injectable()
export class ExpensesService {
  constructor(private prisma: PrismaService) {}

  private include = { category: true };

  private async nextVoucherNo(): Promise<string> {
    const count = await this.prisma.expense.count();
    const year = new Date().getFullYear();
    return `EXP/${year}/${String(count + 1).padStart(6, '0')}`;
  }

  async create(dto: CreateExpenseDto, user: SessionUser) {
    const voucherNo = await this.nextVoucherNo();
    return this.prisma.expense.create({
      data: {
        ...dto,
        voucherNo,
        approvedBy: user.name ?? user.email,
        date: dto.date ? new Date(dto.date) : new Date(),
      },
      include: this.include,
    });
  }

  async findAll(query: ExpenseQueryDto) {
    const { page = 1, limit = 20, search, status, paymentMode, categoryId, from, to } = query;
    const where: any = {};
    if (search) {
      where.OR = [
        { voucherNo: { contains: search, mode: 'insensitive' } },
        { paidTo: { contains: search, mode: 'insensitive' } },
      ];
    }
    if (status) where.status = status;
    if (paymentMode) where.paymentMode = paymentMode;
    if (categoryId) where.categoryId = categoryId;
    if (from || to) {
      where.date = {};
      if (from) where.date.gte = new Date(from);
      if (to) where.date.lte = new Date(to);
    }

    const [data, total] = await Promise.all([
      this.prisma.expense.findMany({ where, include: this.include, ...paginate(page, limit), orderBy: { date: 'desc' } }),
      this.prisma.expense.count({ where }),
    ]);
    return paginatedResponse(data, total, page, limit);
  }

  async findCategories() {
    return this.prisma.expenseCategory.findMany({ where: { isActive: true }, orderBy: { label: 'asc' } });
  }

  async findOne(id: string) {
    const expense = await this.prisma.expense.findUnique({ where: { id }, include: this.include });
    if (!expense) throw new NotFoundException('Expense not found');
    return expense;
  }

  async update(id: string, dto: UpdateExpenseDto) {
    await this.findOne(id);
    return this.prisma.expense.update({
      where: { id },
      data: { ...dto, date: dto.date ? new Date(dto.date) : undefined },
      include: this.include,
    });
  }

  async summary() {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const startOfYear = new Date(now.getFullYear(), 0, 1);
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const [todayTotal, monthTotal, yearTotal, byCategory, byMode, recentExpenses] = await Promise.all([
      this.prisma.expense.aggregate({ where: { date: { gte: today }, status: 'COMPLETED' }, _sum: { amount: true }, _count: true }),
      this.prisma.expense.aggregate({ where: { date: { gte: startOfMonth }, status: 'COMPLETED' }, _sum: { amount: true }, _count: true }),
      this.prisma.expense.aggregate({ where: { date: { gte: startOfYear }, status: 'COMPLETED' }, _sum: { amount: true }, _count: true }),
      this.prisma.expense.groupBy({ by: ['categoryId'], _sum: { amount: true }, _count: true }),
      this.prisma.expense.groupBy({ by: ['paymentMode'], _sum: { amount: true }, _count: true }),
      this.prisma.expense.findMany({ where: { status: 'COMPLETED' }, include: this.include, orderBy: { date: 'desc' }, take: 10 }),
    ]);

    return {
      today: { amount: todayTotal._sum.amount ?? 0, count: todayTotal._count },
      month: { amount: monthTotal._sum.amount ?? 0, count: monthTotal._count },
      year: { amount: yearTotal._sum.amount ?? 0, count: yearTotal._count },
      byCategory, byMode, recentExpenses,
    };
  }
}
