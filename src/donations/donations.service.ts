import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateDonationDto } from './dto/create-donation.dto';
import { UpdateDonationDto } from './dto/update-donation.dto';
import { DonationQueryDto } from './dto/donation-query.dto';
import { ConfigService } from '@nestjs/config';
import { paginate, paginatedResponse } from '../common/dto/pagination.dto';
import { WhatsappService } from '../whatsapp/whatsapp.service';

@Injectable()
export class DonationsService {
  constructor(
    private prisma: PrismaService,
    private whatsapp: WhatsappService,
    private config: ConfigService,
  ) {}

  private include = {
    donor: { select: { id: true, name: true, mobile: true, donorCode: true } },
    type: true,
  };

  private async nextReceipt(): Promise<string> {
    const count = await this.prisma.donation.count();
    const year = new Date().getFullYear();
    return `RCP/${year}/${String(count + 1).padStart(6, '0')}`;
  }

  async create(dto: CreateDonationDto) {
    const receiptNo = await this.nextReceipt();
    const donation = await this.prisma.donation.create({
      data: {
        ...dto,
        receiptNo,
        date: dto.date ? new Date(dto.date) : new Date(),
      },
      include: this.include,
    });

    // Fire-and-forget WhatsApp messages to the donor. Never awaited / never
    // throws, so they can't slow down or break the donation.
    if (donation.donor?.mobile) {
      const mobile = donation.donor.mobile;
      const name = donation.donor.name;
      // 1) Thank-you confirmation.
      this.whatsapp.sendDonationReceived(mobile, name, donation.amount).catch(() => undefined);
      // 2) Receipt with a tappable download link (needs a public base URL).
      const base = (this.config.get<string>('PUBLIC_BASE_URL') || '').replace(/\/+$/, '');
      if (base) {
        const receiptUrl = `${base}/receipts/${donation.id}`;
        this.whatsapp
          .sendReceiptGenerated(mobile, name, donation.amount, receiptUrl)
          .catch(() => undefined);
      }
    }

    return donation;
  }

  async findAll(query: DonationQueryDto) {
    const { page = 1, limit = 20, search, status, paymentMode, donorId, typeId, from, to } = query;
    const where: any = {};
    if (search) {
      where.OR = [
        { receiptNo: { contains: search, mode: 'insensitive' } },
        { donor: { name: { contains: search, mode: 'insensitive' } } },
      ];
    }
    if (status) where.status = status;
    if (paymentMode) where.paymentMode = paymentMode;
    if (donorId) where.donorId = donorId;
    if (typeId) where.typeId = typeId;
    if (from || to) {
      where.date = {};
      if (from) where.date.gte = new Date(from);
      if (to) where.date.lte = new Date(to);
    }
    const [data, total] = await Promise.all([
      this.prisma.donation.findMany({ where, include: this.include, ...paginate(page, limit), orderBy: { date: 'desc' } }),
      this.prisma.donation.count({ where }),
    ]);
    return paginatedResponse(data, total, page, limit);
  }

  async findTypes() {
    return this.prisma.donationType.findMany({ where: { isActive: true }, orderBy: { label: 'asc' } });
  }

  async findOne(id: string) {
    const donation = await this.prisma.donation.findUnique({ where: { id }, include: this.include });
    if (!donation) throw new NotFoundException('Donation not found');
    return donation;
  }

  async update(id: string, dto: UpdateDonationDto) {
    await this.findOne(id);
    return this.prisma.donation.update({ where: { id }, data: { ...dto, date: dto.date ? new Date(dto.date) : undefined }, include: this.include });
  }

  async summary() {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const startOfYear = new Date(now.getFullYear(), 0, 1);
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const [todayTotal, monthTotal, yearTotal, byType, byMode, recentDonations] = await Promise.all([
      this.prisma.donation.aggregate({ where: { date: { gte: today }, status: 'COMPLETED' }, _sum: { amount: true }, _count: true }),
      this.prisma.donation.aggregate({ where: { date: { gte: startOfMonth }, status: 'COMPLETED' }, _sum: { amount: true }, _count: true }),
      this.prisma.donation.aggregate({ where: { date: { gte: startOfYear }, status: 'COMPLETED' }, _sum: { amount: true }, _count: true }),
      this.prisma.donation.groupBy({ by: ['typeId'], _sum: { amount: true }, _count: true }),
      this.prisma.donation.groupBy({ by: ['paymentMode'], _sum: { amount: true }, _count: true }),
      this.prisma.donation.findMany({ where: { status: 'COMPLETED' }, include: this.include, orderBy: { date: 'desc' }, take: 10 }),
    ]);

    return {
      today: { amount: todayTotal._sum.amount ?? 0, count: todayTotal._count },
      month: { amount: monthTotal._sum.amount ?? 0, count: monthTotal._count },
      year: { amount: yearTotal._sum.amount ?? 0, count: yearTotal._count },
      byType, byMode, recentDonations,
    };
  }

  async tracker(range: string) {
    const now = new Date();
    let from: Date;
    if (range === 'today') from = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    else if (range === 'week') { from = new Date(now); from.setDate(from.getDate() - 7); }
    else if (range === 'month') from = new Date(now.getFullYear(), now.getMonth(), 1);
    else if (range === 'last') from = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    else from = new Date(0);

    return this.prisma.donation.findMany({
      where: { date: { gte: from } },
      include: {
        donor: { select: { id: true, name: true, mobile: true, whatsapp: true, email: true } },
        type: true,
      },
      orderBy: { date: 'desc' },
    });
  }
}
