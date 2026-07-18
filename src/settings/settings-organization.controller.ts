import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { SettingsService } from './settings.service';
import { UpdateOrganizationSettingsDto } from './dto/update-organization-settings.dto';

@ApiTags('settings')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('settings/organization')
export class SettingsOrganizationController {
  constructor(private svc: SettingsService) {}

  // No @Roles(...) — nothing here is secret (unlike WhatsApp's apiToken or
  // Razorpay's keySecret), and every authenticated staff member (not just
  // SUPER_ADMIN) needs it to render a donation receipt/voucher.
  @Get()
  @ApiOperation({ summary: 'Get organization identity (name, address, PAN, etc.) shown on receipts' })
  get() {
    return this.svc.getOrganization();
  }

  @Patch()
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: 'Update organization identity' })
  update(@Body() dto: UpdateOrganizationSettingsDto) {
    return this.svc.updateOrganization(dto);
  }
}
