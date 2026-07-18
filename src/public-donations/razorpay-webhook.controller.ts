import { Controller, Post, Req } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { Request } from 'express';
import { PublicDonationsService } from './public-donations.service';

// Genuinely public/unauthenticated — Razorpay calls this directly, it can't
// send a JWT. Authenticity is instead established by verifying the HMAC
// webhook signature inside handleWebhook() (see PublicDonationsService).
@ApiTags('public-donations')
@Controller('public/webhooks/razorpay')
export class RazorpayWebhookController {
  constructor(private svc: PublicDonationsService) {}

  @Post()
  @ApiOperation({ summary: 'Razorpay payment_link.paid webhook (public, HMAC-signature verified)' })
  async handle(@Req() req: Request & { rawBody?: Buffer }) {
    const signature = req.headers['x-razorpay-signature'] as string | undefined;
    return this.svc.handleWebhook(req.rawBody ?? Buffer.from(''), signature, req.body);
  }
}
