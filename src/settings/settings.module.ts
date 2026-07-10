import { Module } from '@nestjs/common';
import { SettingsController } from './settings.controller';
import { SettingsRazorpayController } from './settings-razorpay.controller';
import { SettingsService } from './settings.service';

// PrismaModule is @Global, so PrismaService injects without importing.
@Module({
  controllers: [SettingsController, SettingsRazorpayController],
  providers: [SettingsService],
  exports: [SettingsService],
})
export class SettingsModule {}
