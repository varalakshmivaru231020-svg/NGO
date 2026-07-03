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

  async findAll(query: { upcoming?: boolean; type?: string }) {
    const where: any = {};
    if (query.upcoming) where.dueDate = { gte: new Date() };
    if (query.type) where.type = query.type;
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
