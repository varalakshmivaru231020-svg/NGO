import { Controller, Get, Post, Put, Patch, Body, Param, Query, Delete, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { StudentsService } from './students.service';
import { CreateStudentDto } from './dto/create-student.dto';
import { UpdateStudentDto } from './dto/update-student.dto';
import { StudentQueryDto } from './dto/student-query.dto';
import { CreateSponsorshipDto } from './dto/create-sponsorship.dto';
import { MarkAttendanceDto } from './dto/mark-attendance.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('students')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard)
@Controller('students')
export class StudentsController {
  constructor(private svc: StudentsService) {}

  @Get('summary') @ApiOperation({ summary: 'Student summary stats' })
  summary() { return this.svc.summary(); }

  @Get('centers') @ApiOperation({ summary: 'List all centers' })
  centers() { return this.svc.findCenters(); }

  @Post('centers') @ApiOperation({ summary: 'Create a center' })
  createCenter(@Body() body: { name: string; city?: string; address?: string }) {
    return this.svc.createCenter(body.name, body.city, body.address);
  }

  @Patch('centers/:id') @ApiOperation({ summary: 'Update a center' })
  updateCenter(@Param('id') id: string, @Body() body: { name?: string; city?: string; address?: string }) {
    return this.svc.updateCenter(id, body);
  }

  @Delete('centers/:id') @ApiOperation({ summary: 'Delete (deactivate) a center' })
  removeCenter(@Param('id') id: string) { return this.svc.removeCenter(id); }

  @Post() @ApiOperation({ summary: 'Add a student' })
  create(@Body() dto: CreateStudentDto) { return this.svc.create(dto); }

  @Get() @ApiOperation({ summary: 'List students' })
  findAll(@Query() q: StudentQueryDto) { return this.svc.findAll(q); }

  @Get(':id') @ApiOperation({ summary: 'Get student by ID' })
  findOne(@Param('id') id: string) { return this.svc.findOne(id); }

  @Put(':id') @ApiOperation({ summary: 'Update student' })
  update(@Param('id') id: string, @Body() dto: UpdateStudentDto) { return this.svc.update(id, dto); }

  @Post(':id/sponsorships') @ApiOperation({ summary: 'Add sponsorship' })
  addSponsorship(@Param('id') id: string, @Body() dto: CreateSponsorshipDto) {
    return this.svc.addSponsorship(id, dto);
  }

  @Delete('sponsorships/:sponsorshipId') @ApiOperation({ summary: 'Remove sponsorship' })
  removeSponsorship(@Param('sponsorshipId') sid: string) { return this.svc.removeSponsorship(sid); }

  @Post(':id/attendance') @ApiOperation({ summary: 'Mark attendance' })
  markAttendance(@Param('id') id: string, @Body() dto: MarkAttendanceDto) {
    return this.svc.markAttendance(id, dto);
  }

  @Get(':id/attendance') @ApiOperation({ summary: 'Get attendance for a month' })
  @ApiQuery({ name: 'month', example: '2026-06', description: 'YYYY-MM' })
  getAttendance(@Param('id') id: string, @Query('month') month: string) {
    return this.svc.getAttendance(id, month);
  }
}
