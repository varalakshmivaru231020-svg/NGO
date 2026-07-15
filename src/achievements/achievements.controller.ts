import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { AchievementsService } from './achievements.service';
import { CreateAchievementDto } from './dto/create-achievement.dto';
import { UpdateAchievementDto } from './dto/update-achievement.dto';
import { AchievementQueryDto } from './dto/achievement-query.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('achievements')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard)
@Controller('achievements')
export class AchievementsController {
  constructor(private svc: AchievementsService) {}

  @Post() @ApiOperation({ summary: 'Log an achievement' })
  create(@Body() dto: CreateAchievementDto) { return this.svc.create(dto); }

  @Get() @ApiOperation({ summary: 'List achievements' })
  findAll(@Query() q: AchievementQueryDto) { return this.svc.findAll(q); }

  @Get(':id') @ApiOperation({ summary: 'Get achievement by ID' })
  findOne(@Param('id') id: string) { return this.svc.findOne(id); }

  @Put(':id') @ApiOperation({ summary: 'Update achievement' })
  update(@Param('id') id: string, @Body() dto: UpdateAchievementDto) { return this.svc.update(id, dto); }

  @Delete(':id') @ApiOperation({ summary: 'Delete achievement' })
  remove(@Param('id') id: string) { return this.svc.remove(id); }
}
