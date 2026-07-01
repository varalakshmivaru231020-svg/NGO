import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { OfficesService } from './offices.service';
import { CreateOfficeDto } from './dto/create-office.dto';
import { UpdateOfficeDto } from './dto/update-office.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('offices')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard)
@Controller('offices')
export class OfficesController {
  constructor(private svc: OfficesService) {}

  @Post() @ApiOperation({ summary: 'Create office' })
  create(@Body() dto: CreateOfficeDto) { return this.svc.create(dto); }

  @Get() @ApiOperation({ summary: 'List offices' })
  findAll() { return this.svc.findAll(); }

  @Get(':id') @ApiOperation({ summary: 'Get office by ID' })
  findOne(@Param('id') id: string) { return this.svc.findOne(id); }

  @Put(':id') @ApiOperation({ summary: 'Update office' })
  update(@Param('id') id: string, @Body() dto: UpdateOfficeDto) { return this.svc.update(id, dto); }

  @Delete(':id') @ApiOperation({ summary: 'Deactivate office' })
  remove(@Param('id') id: string) { return this.svc.remove(id); }
}
