import { Module } from '@nestjs/common';
import { WhatsappService } from './whatsapp.service';

// ConfigModule is registered globally in AppModule, so ConfigService injects
// without importing it here.
@Module({
  providers: [WhatsappService],
  exports: [WhatsappService],
})
export class WhatsappModule {}
