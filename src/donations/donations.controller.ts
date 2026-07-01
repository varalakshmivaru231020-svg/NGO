import { Controller, Get, Post, Put, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { DonationsService } from './donations.service';
import { CreateDonationDto } from './dto/create-donation.dto';
import { UpdateDonationDto } from './dto/update-donation.dto';
import { DonationQueryDto } from './dto/donation-query.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('donations')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard)
@Controller('donations')
export class DonationsController {
  constructor(private svc: DonationsService) {}

  @Get('summary') @ApiOperation({ summary: 'Donation summary stats' })
  summary() { return this.svc.summary(); }

  @Get('tracker') @ApiOperation({ summary: 'Donation tracker by date range' })
  @ApiQuery({ name: 'range', enum: ['today', 'week', 'month', 'last', 'all'], required: false })
  tracker(@Query('range') range = 'week') { return this.svc.tracker(range); }

  @Post() @ApiOperation({ summary: 'Record a donation' })
  create(@Body() dto: CreateDonationDto) { return this.svc.create(dto); }

  @Get() @ApiOperation({ summary: 'List donations' })
  findAll(@Query() q: DonationQueryDto) { return this.svc.findAll(q); }

  @Get('types') @ApiOperation({ summary: 'List donation types' })
  findTypes() { return this.svc.findTypes(); }

  @Get(':id') @ApiOperation({ summary: 'Get donation by ID' })
  findOne(@Param('id') id: string) { return this.svc.findOne(id); }

  @Put(':id') @ApiOperation({ summary: 'Update donation' })
  update(@Param('id') id: string, @Body() dto: UpdateDonationDto) { return this.svc.update(id, dto); }
}
