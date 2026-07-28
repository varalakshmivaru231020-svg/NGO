import { Controller, Get, Post, Put, Patch, Body, Param, Query, Delete, UseGuards, BadRequestException } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { StudentsService } from './students.service';
import { CreateStudentDto } from './dto/create-student.dto';
import { UpdateStudentDto } from './dto/update-student.dto';
import { StudentQueryDto } from './dto/student-query.dto';
import { CreateSponsorshipDto } from './dto/create-sponsorship.dto';
import { MarkAttendanceDto } from './dto/mark-attendance.dto';
import { CreateGrowthRecordDto } from './dto/create-growth-record.dto';
import { CreateStudentDocumentDto } from './dto/create-student-document.dto';
import { CreateProgressRecordDto } from './dto/create-progress-record.dto';
import { CreateCenterDto, UpdateCenterDto } from './dto/center.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';

@ApiTags('students')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('students')
export class StudentsController {
  constructor(private svc: StudentsService) {}

  @Get('summary') @ApiOperation({ summary: 'Student summary stats' })
  summary() { return this.svc.summary(); }

  @Get('centers') @ApiOperation({ summary: 'List all centers' })
  centers() { return this.svc.findCenters(); }

  @Post('centers') @ApiOperation({ summary: 'Create a center' })
  createCenter(@Body() dto: CreateCenterDto) {
    return this.svc.createCenter(dto.name, dto.city, dto.address);
  }

  @Patch('centers/:id') @ApiOperation({ summary: 'Update a center' })
  updateCenter(@Param('id') id: string, @Body() dto: UpdateCenterDto) {
    return this.svc.updateCenter(id, { name: dto.name, city: dto.city, address: dto.address });
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
    if (!/^\d{4}-\d{2}$/.test(month ?? ''))
      throw new BadRequestException('month must be in YYYY-MM format');
    return this.svc.getAttendance(id, month);
  }

  @Post(':id/growth') @ApiOperation({ summary: 'Add/update a date-wise height & weight record' })
  addGrowthRecord(@Param('id') id: string, @Body() dto: CreateGrowthRecordDto) {
    return this.svc.addGrowthRecord(id, dto);
  }

  @Get(':id/growth') @ApiOperation({ summary: 'Get full growth (height/weight) history' })
  getGrowthRecords(@Param('id') id: string) {
    return this.svc.getGrowthRecords(id);
  }

  @Delete('growth/:recordId') @ApiOperation({ summary: 'Remove a growth record' })
  removeGrowthRecord(@Param('recordId') recordId: string) {
    return this.svc.removeGrowthRecord(recordId);
  }

  @Post(':id/documents') @ApiOperation({ summary: 'Upload a document' })
  addDocument(@Param('id') id: string, @Body() dto: CreateStudentDocumentDto) {
    return this.svc.addDocument(id, dto);
  }

  @Get(':id/documents') @ApiOperation({ summary: 'List document metadata (no file content)' })
  getDocuments(@Param('id') id: string) {
    return this.svc.getDocuments(id);
  }

  @Get('documents/:docId') @ApiOperation({ summary: 'Get a document with its file content' })
  getDocument(@Param('docId') docId: string) {
    return this.svc.getDocument(docId);
  }

  // Deleting a child's document (Aadhaar/birth-certificate scans) is
  // destructive and — being approval-exempt — would otherwise leave no trail;
  // restrict it to admins. Uploads/reads stay open for day-to-day staff work.
  @Delete('documents/:docId') @Roles('ADMIN') @ApiOperation({ summary: 'Remove a document (admin only)' })
  removeDocument(@Param('docId') docId: string) {
    return this.svc.removeDocument(docId);
  }

  @Post(':id/progress') @ApiOperation({ summary: 'Add a progress/performance record' })
  addProgressRecord(@Param('id') id: string, @Body() dto: CreateProgressRecordDto) {
    return this.svc.addProgressRecord(id, dto);
  }

  @Get(':id/progress') @ApiOperation({ summary: 'Get progress/performance history (paginated, newest first)' })
  @ApiQuery({ name: 'page', required: false }) @ApiQuery({ name: 'limit', required: false })
  getProgressRecords(@Param('id') id: string, @Query('page') page?: string, @Query('limit') limit?: string) {
    // Clamp — raw Number() lets ?page=0 / ?page=abc reach Prisma as a
    // negative/NaN skip (500), and an unbounded limit dumps the whole table.
    const p = Math.max(1, Number(page) || 1);
    const l = Math.min(100, Math.max(1, Number(limit) || 10));
    return this.svc.getProgressRecords(id, p, l);
  }

  @Delete('progress/:recordId') @ApiOperation({ summary: 'Remove a progress record' })
  removeProgressRecord(@Param('recordId') recordId: string) {
    return this.svc.removeProgressRecord(recordId);
  }
}
