import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { RemindersService } from './reminders.service';
import { CreateReminderDto } from './dto/create-reminder.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('reminders')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard)
@Controller('reminders')
export class RemindersController {
  constructor(private svc: RemindersService) {}

  @Get('today') @ApiOperation({ summary: 'Reminders due today' })
  today() { return this.svc.today(); }

  @Get('birthdays') @ApiOperation({ summary: 'Donor birthdays today' })
  birthdays() { return this.svc.birthdaysToday(); }

  @Get('upcoming-birthdays') @ApiOperation({ summary: 'Donor + student birthdays in the next N days (default 31)' })
  upcomingBirthdays(@Query('days') days?: string) {
    return this.svc.upcomingBirthdays(days ? parseInt(days, 10) : 31);
  }

  @Get('upcoming-anniversaries') @ApiOperation({ summary: 'Donor anniversaries in the next N days (default 31)' })
  upcomingAnniversaries(@Query('days') days?: string) {
    return this.svc.upcomingAnniversaries(days ? parseInt(days, 10) : 31);
  }

  @Post() @ApiOperation({ summary: 'Create reminder' })
  create(@Body() dto: CreateReminderDto) { return this.svc.create(dto); }

  @Get() @ApiOperation({ summary: 'List reminders' })
  findAll(@Query() q: { upcoming?: boolean; type?: string }) { return this.svc.findAll(q); }

  @Patch(':id/done') @ApiOperation({ summary: 'Mark reminder as done' })
  markDone(@Param('id') id: string) { return this.svc.markDone(id); }

  @Delete(':id') @ApiOperation({ summary: 'Delete reminder' })
  remove(@Param('id') id: string) { return this.svc.remove(id); }
}
