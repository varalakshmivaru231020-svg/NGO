import { Injectable, NotFoundException } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { WhatsappService } from '../whatsapp/whatsapp.service';
import { CreateReminderDto } from './dto/create-reminder.dto';

@Injectable()
export class RemindersService {
  constructor(
    private prisma: PrismaService,
    private whatsapp: WhatsappService,
  ) {}

  private include = {
    donor: { select: { id: true, name: true, mobile: true, whatsapp: true } },
  };

  async create(dto: CreateReminderDto) {
    return this.prisma.reminder.create({
      data: { ...dto, dueDate: new Date(dto.dueDate) },
      include: this.include,
    });
  }

  async findAll(query: { upcoming?: boolean | string; type?: string }) {
    const where: any = {};
    // Query params arrive as strings — 'false' is truthy, and qs can turn
    // ?type[contains]=x into an object that would inject a Prisma operator.
    if (query.upcoming === true || query.upcoming === 'true') where.dueDate = { gte: new Date() };
    if (typeof query.type === 'string' && query.type) where.type = query.type;
    return this.prisma.reminder.findMany({ where, include: this.include, orderBy: { dueDate: 'asc' } });
  }

  async today() {
    const today = new Date();
    const start = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const end = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);
    return this.prisma.reminder.findMany({
      where: { dueDate: { gte: start, lt: end }, isDone: false },
      include: this.include,
    });
  }

  async birthdaysToday() {
    const today = new Date();
    const mm = String(today.getMonth() + 1).padStart(2, '0');
    const dd = String(today.getDate()).padStart(2, '0');
    return this.prisma.donor.findMany({
      where: {
        isActive: true,
        dob: { not: null },
      },
      select: { id: true, name: true, mobile: true, whatsapp: true, dob: true },
    }).then((donors) =>
      donors.filter((d) => {
        if (!d.dob) return false;
        const dob = new Date(d.dob);
        return (
          String(dob.getMonth() + 1).padStart(2, '0') === mm &&
          String(dob.getDate()).padStart(2, '0') === dd
        );
      }),
    );
  }

  // Next occurrence (this year or next) of a recurring month/day, relative to
  // `from` (e.g. a birthday or anniversary) — used to project real donor/
  // student dob & anniversary fields onto upcoming dates for the Reminders
  // screen, which previously only ever showed hardcoded sample data.
  private nextOccurrence(month: number, day: number, from: Date): Date {
    const fromMidnight = new Date(from.getFullYear(), from.getMonth(), from.getDate());
    let next = new Date(fromMidnight.getFullYear(), month, day);
    if (next < fromMidnight) next = new Date(fromMidnight.getFullYear() + 1, month, day);
    return next;
  }

  // Donor + student birthdays falling within the next `days` days (default a
  // month out), each annotated with the age they'll be turning.
  async upcomingBirthdays(days = 31) {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const horizon = new Date(today);
    horizon.setDate(horizon.getDate() + days);

    const [donors, students] = await Promise.all([
      this.prisma.donor.findMany({
        where: { isActive: true, dob: { not: null } },
        select: { id: true, name: true, mobile: true, whatsapp: true, dob: true },
      }),
      this.prisma.student.findMany({
        where: { status: 'ACTIVE' },
        select: { id: true, name: true, guardianPhone: true, dob: true },
      }),
    ]);

    const result: {
      id: string; name: string; type: 'Donor' | 'Student';
      mobile: string; date: string; turningAge: number;
    }[] = [];

    for (const d of donors) {
      if (!d.dob) continue;
      const dob = new Date(d.dob);
      const next = this.nextOccurrence(dob.getMonth(), dob.getDate(), today);
      if (next < horizon) {
        result.push({
          id: d.id, name: d.name, type: 'Donor',
          mobile: d.whatsapp || d.mobile || '',
          date: next.toISOString(), turningAge: next.getFullYear() - dob.getFullYear(),
        });
      }
    }
    for (const s of students) {
      const dob = new Date(s.dob);
      const next = this.nextOccurrence(dob.getMonth(), dob.getDate(), today);
      if (next < horizon) {
        result.push({
          id: s.id, name: s.name, type: 'Student',
          mobile: s.guardianPhone || '',
          date: next.toISOString(), turningAge: next.getFullYear() - dob.getFullYear(),
        });
      }
    }
    result.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
    return result;
  }

  // Donor wedding/relationship anniversaries falling within the next `days`
  // days, annotated with the number of years.
  async upcomingAnniversaries(days = 31) {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const horizon = new Date(today);
    horizon.setDate(horizon.getDate() + days);

    const donors = await this.prisma.donor.findMany({
      where: { isActive: true, anniversary: { not: null } },
      select: { id: true, name: true, mobile: true, whatsapp: true, anniversary: true },
    });

    const result: {
      id: string; name: string; type: 'Donor';
      mobile: string; date: string; years: number;
    }[] = [];

    for (const d of donors) {
      if (!d.anniversary) continue;
      const ann = new Date(d.anniversary);
      const next = this.nextOccurrence(ann.getMonth(), ann.getDate(), today);
      if (next < horizon) {
        result.push({
          id: d.id, name: d.name, type: 'Donor',
          mobile: d.whatsapp || d.mobile || '',
          date: next.toISOString(), years: next.getFullYear() - ann.getFullYear(),
        });
      }
    }
    result.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
    return result;
  }

  async markDone(id: string) {
    return this.prisma.reminder.update({ where: { id }, data: { isDone: true } });
  }

  async remove(id: string) {
    return this.prisma.reminder.delete({ where: { id } });
  }

  // Runs every morning: creates in-app birthday reminders AND sends the
  // birthday_wishes WhatsApp template — on the birthday itself, once per donor.
  @Cron(CronExpression.EVERY_DAY_AT_8AM)
  async autoCreateBirthdayReminders() {
    const donors = await this.birthdaysToday();
    for (const donor of donors) {
      const existing = await this.prisma.reminder.findFirst({
        where: {
          donorId: donor.id,
          type: 'BIRTHDAY',
          dueDate: { gte: new Date(new Date().setHours(0, 0, 0, 0)) },
        },
      });
      if (!existing) {
        await this.prisma.reminder.create({
          data: {
            donorId: donor.id,
            type: 'BIRTHDAY',
            title: `Birthday: ${donor.name}`,
            message: `Today is ${donor.name}'s birthday! Consider sending wishes.`,
            dueDate: new Date(),
          },
        });
        // The reminder-existence check above dedupes so we send at most once/day.
        const to = donor.whatsapp || donor.mobile;
        if (to) this.whatsapp.sendBirthdayWishes(to, donor.name).catch(() => undefined);
      }
    }
  }

  // Runs every morning: sends the donation_anniversary template to donors whose
  // FIRST donation was on this day in a prior year (once per donor per day).
  @Cron(CronExpression.EVERY_DAY_AT_8AM)
  async sendDonationAnniversaries() {
    const today = new Date();
    const mm = today.getMonth();
    const dd = today.getDate();
    const donors = await this.prisma.donor.findMany({
      where: { isActive: true },
      select: {
        id: true,
        name: true,
        mobile: true,
        whatsapp: true,
        donations: { select: { date: true }, orderBy: { date: 'asc' }, take: 1 },
      },
    });
    for (const donor of donors) {
      const first = donor.donations[0]?.date;
      if (!first) continue;
      const fd = new Date(first);
      if (fd.getMonth() !== mm || fd.getDate() !== dd) continue;
      const years = today.getFullYear() - fd.getFullYear();
      if (years < 1) continue;

      // Dedupe with an ANNIVERSARY reminder gate (mirrors the birthday flow).
      const existing = await this.prisma.reminder.findFirst({
        where: {
          donorId: donor.id,
          type: 'ANNIVERSARY',
          dueDate: { gte: new Date(new Date().setHours(0, 0, 0, 0)) },
        },
      });
      if (existing) continue;
      await this.prisma.reminder.create({
        data: {
          donorId: donor.id,
          type: 'ANNIVERSARY',
          title: `Donation anniversary: ${donor.name}`,
          message: `${years} year(s) since ${donor.name}'s first donation.`,
          dueDate: new Date(),
        },
      });
      const to = donor.whatsapp || donor.mobile;
      if (to) this.whatsapp.sendDonationAnniversary(to, donor.name, years).catch(() => undefined);
    }
  }
}
