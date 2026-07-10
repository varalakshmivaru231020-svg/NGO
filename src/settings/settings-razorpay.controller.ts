import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { SettingsService } from './settings.service';
import { UpdateRazorpaySettingsDto } from './dto/update-razorpay-settings.dto';

@ApiTags('settings')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('settings/razorpay')
export class SettingsRazorpayController {
  constructor(private svc: SettingsService) {}

  @Get()
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: 'Get Razorpay settings' })
  get() {
    return this.svc.getRazorpay();
  }

  @Patch()
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: 'Update Razorpay settings' })
  update(@Body() dto: UpdateRazorpaySettingsDto) {
    return this.svc.updateRazorpay(dto);
  }
}
