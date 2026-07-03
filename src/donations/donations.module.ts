import { Module } from '@nestjs/common';
import { DonationsController } from './donations.controller';
import { ReceiptController } from './receipt.controller';
import { DonationsService } from './donations.service';
import { WhatsappModule } from '../whatsapp/whatsapp.module';

@Module({
  imports: [WhatsappModule],
  controllers: [DonationsController, ReceiptController],
  providers: [DonationsService],
  exports: [DonationsService],
})
export class DonationsModule {}
