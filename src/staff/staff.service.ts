import { BadRequestException, ConflictException, Injectable, Logger, NotFoundException, OnModuleInit } from '@nestjs/common';
import { Prisma, StaffSalary } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateStaffDto, StaffChildDto } from './dto/create-staff.dto';
import { UpdateStaffDto } from './dto/update-staff.dto';
import { StaffQueryDto } from './dto/staff-query.dto';
import { CreateStaffLookupDto, STAFF_LOOKUP_TYPES, StaffLookupType } from './dto/staff-lookup.dto';
import { CreateStaffSalaryDto, UpdateStaffSalaryDto } from './dto/staff-salary.dto';
import { paginate, paginatedResponse } from '../common/dto/pagination.dto';

// "Office Admin" -> "OFFICE_ADMIN": a stable key, so the same label typed
// twice (any case/spacing) resolves to one entry.
function lookupKey(label: string) {
  return label.trim().toUpperCase().replace(/[^A-Z0-9]+/g, '_').replace(/^_+|_+$/g, '').slice(0, 60);
}

// Seeded the first time a list is empty. Status keys match what staff rows
// already hold, so existing records keep their status.
const DEFAULT_LOOKUPS: Record<StaffLookupType, { key: string; label: string; isSystem?: boolean }[]> = {
  DESIGNATION: [
    'Teacher', 'Warden', 'Cook', 'Accountant', 'Counsellor', 'Driver',
    'Office Admin', 'Security', 'Marketing Executive', 'Volunteer Coordinator',
  ].map((label) => ({ key: lookupKey(label), label })),
  STATUS: [
    { key: 'ACTIVE', label: 'Active', isSystem: true },
    { key: 'ON_LEAVE', label: 'On Leave' },
    { key: 'RELIEVED', label: 'Relieved' },
  ],
};

type SalaryAmounts = Pick<StaffSalary,
  'basic' | 'hra' | 'allowances' | 'overtime' | 'bonus' | 'leaveDeduction' | 'pf' | 'advance' | 'otherDeduction'>;

@Injectable()
export class StaffService implements OnModuleInit {
  private readonly logger = new Logger(StaffService.name);
  constructor(private prisma: PrismaService) {}

  async onModuleInit() {
    try {
      for (const type of STAFF_LOOKUP_TYPES) {
        if (await this.prisma.staffLookup.count({ where: { type } })) continue;
        await this.prisma.staffLookup.createMany({
          data: DEFAULT_LOOKUPS[type].map((d, i) => ({ type, key: d.key, label: d.label, isSystem: !!d.isSystem, sortOrder: i })),
          skipDuplicates: true,
        });
      }
    } catch (e) {
      // Table not pushed yet: the app still runs, lists just come back empty.
      this.logger.warn(`Could not seed staff lookups: ${(e as Error).message}`);
    }
  }

  private include = {
    center: { select: { id: true, name: true } },
    children: { orderBy: { createdAt: 'asc' as const } },
  };

  // List rows leave out the base64 photo, same as students — the app loads
  // it per row from GET /staff/:id/photo using the `hasPhoto` flag.
  private listSelect = {
    ...Object.fromEntries(
      Object.keys(Prisma.StaffScalarFieldEnum).filter((k) => k !== 'photo').map((k) => [k, true]),
    ),
    center: this.include.center,
    _count: { select: { children: true } },
  } as Prisma.StaffSelect;

  // Same race-free counter as donor codes (see SequenceCounter in the schema).
  // Never reused after a delete, so a staff code always means one person.
  private async nextCode(): Promise<string> {
    const key = 'staff-code';
    const seq = await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`INSERT IGNORE INTO sequence_counters (\`key\`, seq) VALUES (${key}, 0)`;
      const rows = await tx.$queryRaw<{ seq: number }[]>`SELECT seq FROM sequence_counters WHERE \`key\` = ${key} FOR UPDATE`;
      const next = rows[0].seq + 1;
      await tx.$executeRaw`UPDATE sequence_counters SET seq = ${next} WHERE \`key\` = ${key}`;
      return next;
    });
    return `STF${String(seq).padStart(4, '0')}`;
  }

  private async assertCenterExists(centerId?: string | null) {
    if (!centerId) return;
    const c = await this.prisma.center.findUnique({ where: { id: centerId } });
    if (!c) throw new NotFoundException('Centre not found');
  }

  // undefined → leave untouched, '' / null → clear, otherwise parse.
  private date(v: string | null | undefined) {
    return v === undefined ? undefined : v ? new Date(v) : null;
  }

  private childRows(children: StaffChildDto[]) {
    return children.map((c) => ({
      name: c.name.trim(),
      relation: c.relation || null,
      dob: c.dob ? new Date(c.dob) : null,
      school: c.school || null,
    }));
  }

  private async assertStatus(key?: string | null) {
    if (!key) return;
    const row = await this.prisma.staffLookup.findUnique({ where: { type_key: { type: 'STATUS', key } } });
    if (!row) throw new BadRequestException(`Unknown staff status "${key}" - add it with "+" first`);
  }

  async create(dto: CreateStaffDto) {
    const { children, ...rest } = dto;
    await this.assertCenterExists(dto.centerId);
    await this.assertStatus(dto.status);
    const staffCode = await this.nextCode();
    return this.prisma.staff.create({
      data: {
        ...rest,
        staffCode,
        centerId: dto.centerId || null,
        dob: this.date(dto.dob),
        joiningDate: this.date(dto.joiningDate),
        children: children?.length ? { create: this.childRows(children) } : undefined,
      },
      include: this.include,
    });
  }

  async findAll(query: StaffQueryDto) {
    const { page = 1, limit = 20, search, status, employmentType, centerId } = query;
    const where: Prisma.StaffWhereInput = {};
    if (search) {
      where.OR = [
        { name: { contains: search } },
        { staffCode: { contains: search } },
        { designation: { contains: search } },
        { mobile: { contains: search } },
      ];
    }
    if (status) where.status = status;
    if (employmentType) where.employmentType = employmentType;
    if (centerId) where.centerId = centerId;

    const [rows, total] = await Promise.all([
      this.prisma.staff.findMany({ where, select: this.listSelect, ...paginate(page, limit), orderBy: { createdAt: 'desc' } }),
      this.prisma.staff.count({ where }),
    ]);
    const withPhoto = new Set(
      (await this.prisma.staff.findMany({
        where: { id: { in: rows.map((r: any) => r.id) }, photo: { not: null } },
        select: { id: true },
      })).map((r) => r.id),
    );
    const data = rows.map((r: any) => ({ ...r, hasPhoto: withPhoto.has(r.id) }));
    return paginatedResponse(data, total, page, limit);
  }

  async findOne(id: string) {
    const staff = await this.prisma.staff.findUnique({ where: { id }, include: this.include });
    if (!staff) throw new NotFoundException('Staff member not found');
    return staff;
  }

  async getPhoto(id: string) {
    const row = await this.prisma.staff.findUnique({ where: { id }, select: { id: true, photo: true } });
    if (!row) throw new NotFoundException('Staff member not found');
    return row;
  }

  async update(id: string, dto: UpdateStaffDto) {
    await this.findOne(id);
    await this.assertCenterExists(dto.centerId);
    await this.assertStatus(dto.status);
    const { children, ...rest } = dto;
    // The record and its children change together, so a failed child insert
    // can't leave the profile half-saved.
    return this.prisma.$transaction(async (tx) => {
      if (children) {
        await tx.staffChild.deleteMany({ where: { staffId: id } });
        if (children.length) {
          await tx.staffChild.createMany({ data: this.childRows(children).map((c) => ({ ...c, staffId: id })) });
        }
      }
      return tx.staff.update({
        where: { id },
        data: {
          ...rest,
          centerId: dto.centerId === undefined ? undefined : (dto.centerId || null),
          dob: this.date(dto.dob),
          joiningDate: this.date(dto.joiningDate),
        },
        include: this.include,
      });
    });
  }

  // Children are onDelete: Cascade, so this removes the whole record.
  async remove(id: string) {
    const staff = await this.prisma.staff.findUnique({ where: { id }, select: { id: true, name: true, staffCode: true } });
    if (!staff) throw new NotFoundException('Staff member not found');
    await this.prisma.staff.delete({ where: { id } });
    return { ...staff, deleted: true };
  }
  // ── Option lists (Designation / Status) ───────────────────────────────
  private assertLookupType(type: string): StaffLookupType {
    const t = (type ?? '').toUpperCase();
    if (!(STAFF_LOOKUP_TYPES as readonly string[]).includes(t))
      throw new BadRequestException(`Unknown list "${type}" - use ${STAFF_LOOKUP_TYPES.join(' or ')}`);
    return t as StaffLookupType;
  }

  async findLookups(type: string) {
    const t = this.assertLookupType(type);
    return this.prisma.staffLookup.findMany({
      where: { type: t, isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { label: 'asc' }],
    });
  }

  // Adding a label that already exists (any case/spacing) returns that entry,
  // reactivated if it had been switched off, so "+" never fails on a
  // duplicate and the form just selects it.
  async createLookup(type: string, dto: CreateStaffLookupDto) {
    const t = this.assertLookupType(type);
    const label = dto.label.trim().replace(/\s+/g, ' ');
    const key = lookupKey(label);
    if (!key) throw new BadRequestException('Enter a name with at least one letter or number');
    const existing = await this.prisma.staffLookup.findUnique({ where: { type_key: { type: t, key } } });
    if (existing) {
      return existing.isActive ? existing : this.prisma.staffLookup.update({ where: { id: existing.id }, data: { isActive: true } });
    }
    const last = await this.prisma.staffLookup.aggregate({ where: { type: t }, _max: { sortOrder: true } });
    try {
      return await this.prisma.staffLookup.create({
        data: { type: t, key, label, sortOrder: (last._max.sortOrder ?? -1) + 1 },
      });
    } catch (e) {
      // Two people adding the same label at once: hand back the winner.
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        return this.prisma.staffLookup.findUniqueOrThrow({ where: { type_key: { type: t, key } } });
      }
      throw e;
    }
  }

  // ── Monthly salary records (payslips + monthly / yearly report) ───────
  private withTotals(r: StaffSalary) {
    const gross = r.basic + r.hra + r.allowances + r.overtime + r.bonus;
    const deductions = r.leaveDeduction + r.pf + r.advance + r.otherDeduction;
    return { ...r, gross, deductions, net: gross - deductions };
  }

  private assertNotNegative(r: SalaryAmounts) {
    const gross = r.basic + r.hra + r.allowances + r.overtime + r.bonus;
    const deductions = r.leaveDeduction + r.pf + r.advance + r.otherDeduction;
    if (deductions > gross) throw new BadRequestException('Deductions are more than the earnings for this month');
  }

  private monthTaken(e: unknown, month: string): never {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002')
      throw new ConflictException(`Salary for ${month} is already recorded - edit that month instead`);
    throw e;
  }

  // Every month on record, newest first. A staff member has at most twelve a
  // year, so the app groups by year itself instead of paging.
  async findSalaries(staffId: string) {
    await this.findOne(staffId);
    const rows = await this.prisma.staffSalary.findMany({ where: { staffId }, orderBy: { month: 'desc' } });
    return rows.map((r) => this.withTotals(r));
  }

  async findSalary(salaryId: string) {
    const row = await this.prisma.staffSalary.findUnique({ where: { id: salaryId } });
    if (!row) throw new NotFoundException('Salary record not found');
    return this.withTotals(row);
  }

  async addSalary(staffId: string, dto: CreateStaffSalaryDto) {
    await this.findOne(staffId);
    const amounts: SalaryAmounts = {
      basic: dto.basic ?? 0, hra: dto.hra ?? 0, allowances: dto.allowances ?? 0,
      overtime: dto.overtime ?? 0, bonus: dto.bonus ?? 0,
      leaveDeduction: dto.leaveDeduction ?? 0, pf: dto.pf ?? 0,
      advance: dto.advance ?? 0, otherDeduction: dto.otherDeduction ?? 0,
    };
    this.assertNotNegative(amounts);
    try {
      const row = await this.prisma.staffSalary.create({
        data: { ...dto, ...amounts, staffId, paidOn: this.date(dto.paidOn) },
      });
      return this.withTotals(row);
    } catch (e) {
      this.monthTaken(e, dto.month);
    }
  }

  async updateSalary(salaryId: string, dto: UpdateStaffSalaryDto) {
    const current = await this.findSalary(salaryId);
    const pick = (k: keyof SalaryAmounts) => dto[k] ?? current[k];
    this.assertNotNegative({
      basic: pick('basic'), hra: pick('hra'), allowances: pick('allowances'), overtime: pick('overtime'),
      bonus: pick('bonus'), leaveDeduction: pick('leaveDeduction'), pf: pick('pf'),
      advance: pick('advance'), otherDeduction: pick('otherDeduction'),
    });
    try {
      const row = await this.prisma.staffSalary.update({
        where: { id: salaryId },
        data: { ...dto, paidOn: this.date(dto.paidOn) },
      });
      return this.withTotals(row);
    } catch (e) {
      this.monthTaken(e, dto.month ?? current.month);
    }
  }

  async removeSalary(salaryId: string) {
    const row = await this.findSalary(salaryId);
    await this.prisma.staffSalary.delete({ where: { id: salaryId } });
    return { id: row.id, month: row.month, deleted: true };
  }
}
