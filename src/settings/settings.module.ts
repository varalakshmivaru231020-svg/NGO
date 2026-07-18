import { Module } from '@nestjs/common';
import { SettingsController } from './settings.controller';
import { SettingsRazorpayController } from './settings-razorpay.controller';
import { SettingsOrganizationController } from './settings-organization.controller';
import { SettingsService } from './settings.service';

// PrismaModule is @Global, so PrismaService injects without importing.
@Module({
  controllers: [SettingsController, SettingsRazorpayController, SettingsOrganizationController],
  providers: [SettingsService],
  exports: [SettingsService],
})
export class SettingsModule {}
