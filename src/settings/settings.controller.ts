import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { SettingsService } from './settings.service';
import { UpdateWhatsappSettingsDto } from './dto/update-whatsapp-settings.dto';

@ApiTags('settings')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('settings/whatsapp')
export class SettingsController {
  constructor(private svc: SettingsService) {}

  @Get()
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: 'Get WhatsApp Business API settings' })
  get() {
    return this.svc.getWhatsapp();
  }

  @Patch()
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: 'Update WhatsApp Business API settings' })
  update(@Body() dto: UpdateWhatsappSettingsDto) {
    return this.svc.updateWhatsapp(dto);
  }
}
