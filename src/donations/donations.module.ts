import { Module } from '@nestjs/common';
import { DonationsController } from './donations.controller';
import { ReceiptController } from './receipt.controller';
import { DonationsService } from './donations.service';
import { WhatsappModule } from '../whatsapp/whatsapp.module';
import { SettingsModule } from '../settings/settings.module';

@Module({
  imports: [WhatsappModule, SettingsModule],
  controllers: [DonationsController, ReceiptController],
  providers: [DonationsService],
  exports: [DonationsService],
})
export class DonationsModule {}
