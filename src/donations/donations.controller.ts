import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { DonationsService } from './donations.service';
import { CreateDonationDto } from './dto/create-donation.dto';
import { UpdateDonationDto } from './dto/update-donation.dto';
import { DonationQueryDto } from './dto/donation-query.dto';
import { CreateDonationTypeDto, UpdateDonationTypeDto } from './dto/donation-type.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import type { SessionUser } from '../approvals/approvals.service';

@ApiTags('donations')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard, RolesGuard)
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

  // Admin/Super Admin only — Settings → Donation Types management.
  @Get('types/all') @Roles('ADMIN') @ApiOperation({ summary: 'List all donation types incl. inactive' })
  findAllTypes() { return this.svc.findAllTypes(); }

  @Post('types') @Roles('ADMIN') @ApiOperation({ summary: 'Create a donation type' })
  createType(@Body() dto: CreateDonationTypeDto) { return this.svc.createType(dto); }

  @Put('types/:id') @Roles('ADMIN') @ApiOperation({ summary: 'Update a donation type' })
  updateType(@Param('id') id: string, @Body() dto: UpdateDonationTypeDto) { return this.svc.updateType(id, dto); }

  // Declared before ':id' so 'deleted' isn't captured as an id.
  @Get('deleted') @Roles('ADMIN') @ApiOperation({ summary: 'Record of deleted donation invoices' })
  findDeleted() { return this.svc.findDeleted(); }

  @Get(':id') @ApiOperation({ summary: 'Get donation by ID' })
  findOne(@Param('id') id: string) { return this.svc.findOne(id); }

  @Put(':id') @ApiOperation({ summary: 'Update donation' })
  update(@Param('id') id: string, @Body() dto: UpdateDonationDto) { return this.svc.update(id, dto); }

  @Delete(':id') @ApiOperation({ summary: 'Delete a donation (a copy is kept in the deleted record)' })
  remove(@Param('id') id: string, @CurrentUser() user: SessionUser) { return this.svc.remove(id, user); }
}
