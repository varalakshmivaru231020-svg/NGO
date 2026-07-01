import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { CategoriesService } from './categories.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('categories')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard)
@Controller('categories')
export class CategoriesController {
  constructor(private svc: CategoriesService) {}

  @Post() @ApiOperation({ summary: 'Create category' })
  create(@Body() dto: CreateCategoryDto) { return this.svc.create(dto); }

  @Get() @ApiOperation({ summary: 'List all categories' })
  findAll() { return this.svc.findAll(); }

  @Get(':id') @ApiOperation({ summary: 'Get category with donors' })
  findOne(@Param('id') id: string) { return this.svc.findOne(id); }

  @Put(':id') @ApiOperation({ summary: 'Update category' })
  update(@Param('id') id: string, @Body() dto: UpdateCategoryDto) { return this.svc.update(id, dto); }

  @Delete(':id') @ApiOperation({ summary: 'Delete category' })
  remove(@Param('id') id: string) { return this.svc.remove(id); }
}
