import { Module } from '@nestjs/common';
import { DonorsModule } from '../donors/donors.module';
import { PaymentLinksModule } from '../payment-links/payment-links.module';
import { DonationsModule } from '../donations/donations.module';
import { SettingsModule } from '../settings/settings.module';
import { PublicDonationsController } from './public-donations.controller';
import { RazorpayWebhookController } from './razorpay-webhook.controller';
import { PublicDonationsService } from './public-donations.service';

@Module({
  imports: [DonorsModule, PaymentLinksModule, DonationsModule, SettingsModule],
  controllers: [PublicDonationsController, RazorpayWebhookController],
  providers: [PublicDonationsService],
})
export class PublicDonationsModule {}
