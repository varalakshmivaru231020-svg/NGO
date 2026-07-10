import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { WhatsappService } from '../whatsapp/whatsapp.service';
import { CreatePaymentLinkDto } from './dto/create-payment-link.dto';
import { randomBytes } from 'crypto';

// Node 18+ ships a global fetch; cast through globalThis so we don't depend
// on the DOM lib being enabled in tsconfig (matches WhatsappService).
const httpPost = (globalThis as any).fetch as (
  url: string,
  init?: any,
) => Promise<{ ok: boolean; status: number; json: () => Promise<any>; text: () => Promise<string> }>;

@Injectable()
export class PaymentLinksService {
  private readonly logger = new Logger('PaymentLinksService');

  constructor(
    private prisma: PrismaService,
    private whatsapp: WhatsappService,
    private config: ConfigService,
  ) {}

  async create(dto: CreatePaymentLinkDto) {
    const slug = randomBytes(8).toString('hex');

    let donor: { name: string; mobile: string; email: string | null } | null = null;
    if (dto.donorId) {
      donor = await this.prisma.donor.findUnique({
        where: { id: dto.donorId },
        select: { name: true, mobile: true, email: true },
      });
    }

    // Best-effort: only attempts a real Razorpay link when an amount is
    // given and Razorpay credentials are configured; otherwise the link
    // stays an internal-only bookkeeping link (razorpayShortUrl stays null).
    let razorpay: { id: string; short_url: string } | null = null;
    if (dto.amount) {
      razorpay = await this.createRazorpayLink(dto.amount, dto.purpose || 'Donation', donor);
    }

    return this.prisma.paymentLink.create({
      data: {
        ...dto,
        slug,
        expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : undefined,
        razorpayLinkId: razorpay?.id,
        razorpayShortUrl: razorpay?.short_url,
      },
    });
  }

  // Creates a real, live Razorpay Payment Link via their REST API. Returns
  // null (never throws) if Razorpay isn't configured or the call fails, so
  // donation-link creation never breaks because of Razorpay being down.
  private async createRazorpayLink(
    amountRupees: number,
    description: string,
    donor: { name: string; mobile: string; email: string | null } | null,
  ): Promise<{ id: string; short_url: string } | null> {
    const settings = await this.prisma.razorpaySetting.findUnique({ where: { id: 'singleton' } });
    const keyId = settings?.keyId;
    const keySecret = settings?.keySecret;
    if (!keyId || !keySecret) {
      this.logger.warn('Razorpay not configured — created an internal-only payment link');
      return null;
    }

    const body: any = {
      amount: Math.round(amountRupees * 100), // Razorpay expects paise
      currency: 'INR',
      description,
      notify: { sms: true, email: true },
      reminder_enable: true,
    };
    if (donor) {
      body.customer = {
        name: donor.name,
        contact: donor.mobile ? donor.mobile.replace(/\D/g, '') : undefined,
        email: donor.email || undefined,
      };
    }

    try {
      const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
      const res = await httpPost('https://api.razorpay.com/v1/payment_links', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Basic ${auth}` },
        body: JSON.stringify(body),
      });
      if (!res.ok) {
        const text = await res.text().catch(() => '');
        this.logger.error(`Razorpay link creation failed (${res.status}): ${text.slice(0, 300)}`);
        return null;
      }
      const json = await res.json();
      return { id: json.id, short_url: json.short_url };
    } catch (e) {
      this.logger.error(`Razorpay link creation error: ${String(e)}`);
      return null;
    }
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
