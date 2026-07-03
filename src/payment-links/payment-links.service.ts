import { Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { WhatsappService } from '../whatsapp/whatsapp.service';
import { CreatePaymentLinkDto } from './dto/create-payment-link.dto';
import { randomBytes } from 'crypto';

@Injectable()
export class PaymentLinksService {
  constructor(
    private prisma: PrismaService,
    private whatsapp: WhatsappService,
    private config: ConfigService,
  ) {}

  async create(dto: CreatePaymentLinkDto) {
    const slug = randomBytes(8).toString('hex');
    return this.prisma.paymentLink.create({
      data: { ...dto, slug, expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : undefined },
    });
  }

  async findAll() {
    return this.prisma.paymentLink.findMany({
      orderBy: { createdAt: 'desc' },
      include: { donation: { include: { donor: { select: { id: true, name: true } } } } },
    });
  }

  async findBySlug(slug: string) {
    const link = await this.prisma.paymentLink.findUnique({ where: { slug } });
    if (!link) throw new NotFoundException('Payment link not found');
    return link;
  }

  async expire(id: string) {
    return this.prisma.paymentLink.update({ where: { id }, data: { status: 'EXPIRED' } });
  }

  // Update a link's status. Called by the admin or a future payment-gateway
  // webhook. On FAILED, sends the payment_failed WhatsApp template with a
  // retry link (fire-and-forget, never blocks the response).
  async updateStatus(id: string, status: string) {
    const link = await this.prisma.paymentLink.update({ where: { id }, data: { status } });
    if (status === 'FAILED' && link.donorId) {
      const donor = await this.prisma.donor.findUnique({
        where: { id: link.donorId },
        select: { name: true, mobile: true, whatsapp: true },
      });
      const to = donor?.whatsapp || donor?.mobile;
      if (donor && to) {
        const base = (
          this.config.get<string>('PAY_BASE_URL') ||
          `${(this.config.get<string>('FRONTEND_URL') || '').replace(/\/+$/, '')}/pay`
        ).replace(/\/+$/, '');
        const retryUrl = `${base}/${link.slug}`;
        this.whatsapp
          .sendPaymentFailed(to, donor.name, link.amount || 0, retryUrl)
          .catch(() => undefined);
      }
    }
    return link;
  }
}
