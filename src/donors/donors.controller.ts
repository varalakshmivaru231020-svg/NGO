import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { DonorsService } from './donors.service';
import { CreateDonorDto } from './dto/create-donor.dto';
import { UpdateDonorDto } from './dto/update-donor.dto';
import { DonorQueryDto } from './dto/donor-query.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('donors')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard)
@Controller('donors')
export class DonorsController {
  constructor(private svc: DonorsService) {}

  @Get('summary') @ApiOperation({ summary: 'Donor summary stats' })
  summary() { return this.svc.summary(); }

  @Post() @ApiOperation({ summary: 'Create donor' })
  create(@Body() dto: CreateDonorDto) { return this.svc.create(dto); }

  @Get() @ApiOperation({ summary: 'List donors' })
  findAll(@Query() q: DonorQueryDto) { return this.svc.findAll(q); }

  @Get(':id') @ApiOperation({ summary: 'Get donor by ID' })
  findOne(@Param('id') id: string) { return this.svc.findOne(id); }

  @Put(':id') @ApiOperation({ summary: 'Update donor' })
  update(@Param('id') id: string, @Body() dto: UpdateDonorDto) { return this.svc.update(id, dto); }

  @Delete(':id') @ApiOperation({ summary: 'Soft-delete donor' })
  remove(@Param('id') id: string) { return this.svc.remove(id); }
}
