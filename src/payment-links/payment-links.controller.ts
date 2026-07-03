import { Controller, Get, Post, Patch, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { PaymentLinksService } from './payment-links.service';
import { CreatePaymentLinkDto } from './dto/create-payment-link.dto';
import { UpdatePaymentLinkStatusDto } from './dto/update-status.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('payment-links')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard)
@Controller('payment-links')
export class PaymentLinksController {
  constructor(private svc: PaymentLinksService) {}

  @Post() @ApiOperation({ summary: 'Generate payment link' })
  create(@Body() dto: CreatePaymentLinkDto) { return this.svc.create(dto); }

  @Get() @ApiOperation({ summary: 'List payment links' })
  findAll() { return this.svc.findAll(); }

  @Get(':slug') @ApiOperation({ summary: 'Get payment link by slug (public)' })
  findBySlug(@Param('slug') slug: string) { return this.svc.findBySlug(slug); }

  @Patch(':id/expire') @ApiOperation({ summary: 'Expire a payment link' })
  expire(@Param('id') id: string) { return this.svc.expire(id); }

  @Patch(':id/status') @ApiOperation({ summary: 'Update payment link status (PAID/FAILED/…); FAILED sends payment_failed' })
  updateStatus(@Param('id') id: string, @Body() dto: UpdatePaymentLinkStatusDto) {
    return this.svc.updateStatus(id, dto.status);
  }
}
