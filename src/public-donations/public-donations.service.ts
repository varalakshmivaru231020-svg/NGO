import { Injectable, Logger, NotFoundException, OnModuleInit, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { DonorsService } from '../donors/donors.service';
import { PaymentLinksService } from '../payment-links/payment-links.service';
import { DonationsService } from '../donations/donations.service';
import { SettingsService } from '../settings/settings.service';
import { CreatePublicDonationDto } from './dto/create-public-donation.dto';

// Public website cause slugs → existing DonationType.key values. 'nutrition'
// maps onto the already-seeded 'food' type; 'skill' and 'women' are new
// types this module ensures exist (see onModuleInit below).
const CAUSE_TO_TYPE_KEY: Record<string, string> = {
  education: 'education',
  sponsorship: 'sponsorship',
  health: 'health',
  general: 'general',
  nutrition: 'food',
  skill: 'skill',
  women: 'women',
};

// Razorpay payment method strings → this app's PAYMENT_MODES.
const RAZORPAY_METHOD_TO_PAYMENT_MODE: Record<string, string> = {
  upi: 'UPI',
  card: 'CARD',
  netbanking: 'BANK_TRANSFER',
  wallet: 'UPI',
  emi: 'CARD',
};

@Injectable()
export class PublicDonationsService implements OnModuleInit {
  private readonly logger = new Logger('PublicDonationsService');

  constructor(
    private prisma: PrismaService,
    private donorsService: DonorsService,
    private paymentLinksService: PaymentLinksService,
    private donationsService: DonationsService,
    private settingsService: SettingsService,
    private config: ConfigService,
  ) {}

  // Ensures the two DonationType rows the public donate form needs (but that
  // aren't part of the original seed) exist in every environment, without
  // relying on someone re-running seed.ts. Never throws — a failure here
  // must not crash app boot.
  async onModuleInit() {
    try {
      await this.prisma.donationType.upsert({
        where: { key: 'skill' },
        update: {},
        create: { key: 'skill', label: 'Skill Development', icon: 'wallet' },
      });
      await this.prisma.donationType.upsert({
        where: { key: 'women' },
        update: {},
        create: { key: 'women', label: 'Women Empowerment', icon: 'users' },
      });
    } catch (e) {
      this.logger.warn(`Failed to ensure public donation types exist: ${String(e)}`);
    }
  }

  async initiate(dto: CreatePublicDonationDto) {
    const normalizedMobile = dto.mobile.replace(/\D/g, '');

    let donor = await this.prisma.donor.findFirst({ where: { mobile: normalizedMobile } });
    if (!donor) {
      donor = await this.donorsService.create({
        name: dto.name,
        mobile: normalizedMobile,
        email: dto.email,
        pan: dto.pan,
      } as any);
    }

    const typeKey = CAUSE_TO_TYPE_KEY[dto.cause];
    const type = await this.prisma.donationType.findUnique({ where: { key: typeKey } });
    if (!type) {
      // Should never happen post onModuleInit(), but never silently drop a
      // donation attempt if it somehow does.
      throw new Error(`Donation type '${typeKey}' is missing — cannot initiate donation`);
    }

    const websiteUrl = (this.config.get<string>('WEBSITE_URL') || 'http://localhost:3008').replace(/\/+$/, '');
    const link = await this.paymentLinksService.create({
      donorId: donor.id,
      amount: dto.amount,
      typeId: type.id,
      purpose: type.label,
      callbackUrl: `${websiteUrl}/donate/thank-you`,
    } as any);

    if (!link.razorpayShortUrl) {
      return { success: false as const, code: 'GATEWAY_NOT_CONFIGURED' as const };
    }

    return { success: true as const, razorpayShortUrl: link.razorpayShortUrl, slug: link.slug };
  }

  async getStatusBySlug(slug: string) {
    const link = await this.prisma.paymentLink.findUnique({ where: { slug } });
    if (!link) throw new NotFoundException('Payment link not found');
    return { status: link.status, donated: !!link.donationId };
  }

  async handleWebhook(rawBody: Buffer, signatureHeader: string | undefined, body: any) {
    const razorpaySettings = await this.settingsService.getRazorpay();
    const webhookSecret = razorpaySettings.webhookSecret;
    if (!webhookSecret) {
      throw new UnauthorizedException('Webhook not configured');
    }

    const expected = crypto.createHmac('sha256', webhookSecret).update(rawBody).digest('hex');

    const sigBuf = Buffer.from(signatureHeader || '', 'utf8');
    const expectedBuf = Buffer.from(expected, 'utf8');
    // timingSafeEqual throws on mismatched lengths rather than returning
    // false — check the length first so a malformed/missing signature
    // header can never crash the request (or short-circuit into a
    // non-constant-time comparison path).
    if (!signatureHeader || sigBuf.length !== expectedBuf.length || !crypto.timingSafeEqual(sigBuf, expectedBuf)) {
      throw new UnauthorizedException('Invalid webhook signature');
    }

    // Razorpay sends many event types and retries aggressively on non-2xx —
    // no-op (but still 200) for anything we don't care about.
    if (body?.event !== 'payment_link.paid') {
      return { received: true };
    }

    const razorpayLinkId: string | undefined = body.payload?.payment_link?.entity?.id;
    const paymentId: string | undefined = body.payload?.payment?.entity?.id;
    const method: string | undefined = body.payload?.payment?.entity?.method;

    if (!razorpayLinkId) {
      return { received: true };
    }

    const link = await this.prisma.paymentLink.findUnique({ where: { razorpayLinkId } });
    // Idempotent no-op: unrelated/test webhook, or already processed.
    if (!link || link.donationId) {
      return { received: true };
    }

    if (!link.donorId || !link.typeId || !link.amount) {
      this.logger.warn(`payment_link.paid webhook for link ${link.id} missing donorId/typeId/amount — skipping`);
      return { received: true };
    }

    const paymentMode = (method && RAZORPAY_METHOD_TO_PAYMENT_MODE[method]) || 'PAYMENT_LINK';

    const donation = await this.donationsService.create({
      donorId: link.donorId,
      typeId: link.typeId,
      amount: link.amount,
      paymentMode,
      reference: paymentId,
      notes: 'Public website donation via Razorpay Payment Link',
    });

    await this.prisma.paymentLink.update({
      where: { id: link.id },
      data: { status: 'PAID', donationId: donation.id },
    });

    return { received: true, donationId: donation.id };
  }
}
