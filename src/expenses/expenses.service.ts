import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { UpdateExpenseDto } from './dto/update-expense.dto';
import { ExpenseQueryDto } from './dto/expense-query.dto';
import { CreateExpenseCategoryDto, UpdateExpenseCategoryDto } from './dto/create-expense-category.dto';
import { paginate, paginatedResponse } from '../common/dto/pagination.dto';
import type { SessionUser } from '../approvals/approvals.service';

@Injectable()
export class ExpensesService {
  constructor(private prisma: PrismaService) {}

  private include = { category: true };

  private async nextVoucherNo(): Promise<string> {
    const year = new Date().getFullYear();
    // voucherNo is unique — a row count collides with existing numbers once
    // any expense is deleted, so derive the next from the highest existing.
    const existing = await this.prisma.expense.findMany({ select: { voucherNo: true } });
    let max = 0;
    for (const { voucherNo } of existing) {
      const n = parseInt(voucherNo.split('/').pop() ?? '', 10);
      if (!isNaN(n) && n > max) max = n;
    }
    return `EXP/${year}/${String(max + 1).padStart(6, '0')}`;
  }

  async create(dto: CreateExpenseDto, user: SessionUser) {
    const voucherNo = await this.nextVoucherNo();
    return this.prisma.expense.create({
      data: {
        ...dto,
        voucherNo,
        // Client-submitted (the admin's dropdown pick) takes precedence;
        // falls back to the recording user so older callers that don't send
        // approvedBy behave exactly as before.
        approvedBy: dto.approvedBy || user.name || user.email,
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
        { voucherNo: { contains: search } },
        { paidTo: { contains: search } },
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
      // Newest entry first — same reasoning as donations (backdated vouchers
      // must still surface at the top right after being added).
      this.prisma.expense.findMany({ where, include: this.include, ...paginate(page, limit), orderBy: { createdAt: 'desc' } }),
      this.prisma.expense.count({ where }),
    ]);
    return paginatedResponse(data, total, page, limit);
  }

  async findCategories() {
    return this.prisma.expenseCategory.findMany({ where: { isActive: true }, orderBy: { label: 'asc' } });
  }

  async createCategory(dto: CreateExpenseCategoryDto) {
    const label = dto.label.trim();
    // Blank or duplicate labels break the app's label-keyed pickers.
    if (!label) throw new BadRequestException('Category name is required');
    if (await this.prisma.expenseCategory.findFirst({ where: { label } }))
      throw new ConflictException('A category with this name already exists');
    const base = label.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '') || 'category';
    let key = base;
    for (let i = 2; await this.prisma.expenseCategory.findUnique({ where: { key } }); i++) key = `${base}-${i}`;
    return this.prisma.expenseCategory.create({ data: { key, label, icon: dto.icon ?? 'wallet' } });
  }

  // Settings screen needs inactive ones too so they can be re-enabled.
  async findAllCategories() {
    return this.prisma.expenseCategory.findMany({ orderBy: { label: 'asc' } });
  }

  async updateCategory(id: string, dto: UpdateExpenseCategoryDto) {
    const existing = await this.prisma.expenseCategory.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Expense category not found');
    if (dto.label !== undefined) {
      const label = dto.label.trim();
      if (!label) throw new BadRequestException('Category name is required');
      if (await this.prisma.expenseCategory.findFirst({ where: { label, NOT: { id } } }))
        throw new ConflictException('A category with this name already exists');
    }
    return this.prisma.expenseCategory.update({
      where: { id },
      data: {
        ...(dto.label !== undefined ? { label: dto.label.trim() } : {}),
        ...(dto.description !== undefined ? { description: dto.description?.trim() || null } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
      },
    });
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

  // Hard delete, but the full voucher is first copied into the audit log so a
  // deleted voucher can still be looked up (GET /expenses/deleted). Runs in
  // one transaction — never a delete without its record, or vice versa.
  async remove(id: string, user: SessionUser) {
    const expense = await this.findOne(id);
    await this.prisma.$transaction([
      this.prisma.auditLog.create({
        data: {
          userId: user?.id ?? null,
          action: 'DELETE',
          entity: 'Expense',
          entityId: id,
          oldValue: JSON.stringify(expense),
          newValue: JSON.stringify({ deletedBy: user?.name ?? user?.email ?? null }),
        },
      }),
      this.prisma.expense.delete({ where: { id } }),
    ]);
    return { id, voucherNo: expense.voucherNo, deleted: true };
  }

  async findDeleted() {
    const logs = await this.prisma.auditLog.findMany({
      where: { entity: 'Expense', action: 'DELETE' },
      include: { user: { select: { name: true, email: true } } },
      orderBy: { createdAt: 'desc' },
      take: 500,
    });
    return logs.map((l) => ({
      id: l.id,
      deletedAt: l.createdAt,
      deletedBy: l.user?.name ?? l.user?.email ?? null,
      record: l.oldValue ? JSON.parse(l.oldValue) : null,
    }));
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
      // Same COMPLETED filter as the headline totals above.
      this.prisma.expense.groupBy({ by: ['categoryId'], where: { status: 'COMPLETED' }, _sum: { amount: true }, _count: true }),
      this.prisma.expense.groupBy({ by: ['paymentMode'], where: { status: 'COMPLETED' }, _sum: { amount: true }, _count: true }),
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
