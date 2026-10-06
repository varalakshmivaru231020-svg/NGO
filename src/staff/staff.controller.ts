import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { StaffService } from './staff.service';
import { CreateStaffDto } from './dto/create-staff.dto';
import { UpdateStaffDto } from './dto/update-staff.dto';
import { StaffQueryDto } from './dto/staff-query.dto';
import { CreateStaffLookupDto } from './dto/staff-lookup.dto';
import { CreateStaffSalaryDto, UpdateStaffSalaryDto } from './dto/staff-salary.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ModuleAccessGuard } from '../common/guards/module-access.guard';
import { RequiresModule } from '../common/decorators/requires-module.decorator';

// Salary, PAN, Aadhaar and bank details live here, so unlike most modules
// the API itself checks the member's role grants "staff" (not just the app).
// Non-admin create/edit/delete still goes through the approval queue via the
// global ApprovalInterceptor, like every other mutation — except adding a
// Designation/Status option, which is approval-exempt (see ApprovalsService).
@ApiTags('staff')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard, ModuleAccessGuard)
@RequiresModule('staff')
@Controller('staff')
export class StaffController {
  constructor(private svc: StaffService) {}

  // ── option lists (declared before :id routes) ─────────────────────────
  @Get('lookups/:type') @ApiOperation({ summary: 'Active options of a staff list (DESIGNATION / STATUS)' })
  lookups(@Param('type') type: string) { return this.svc.findLookups(type); }

  @Post('lookups/:type') @ApiOperation({ summary: 'Add an option ("+" in the staff form); returns the existing one for a duplicate' })
  createLookup(@Param('type') type: string, @Body() dto: CreateStaffLookupDto) { return this.svc.createLookup(type, dto); }

  // ── monthly salary records ────────────────────────────────────────────
  @Get('salaries/:salaryId') @ApiOperation({ summary: 'One salary month' })
  salary(@Param('salaryId') salaryId: string) { return this.svc.findSalary(salaryId); }

  @Put('salaries/:salaryId') @ApiOperation({ summary: 'Update a salary month' })
  updateSalary(@Param('salaryId') salaryId: string, @Body() dto: UpdateStaffSalaryDto) {
    return this.svc.updateSalary(salaryId, dto);
  }

  @Delete('salaries/:salaryId') @ApiOperation({ summary: 'Delete a salary month' })
  removeSalary(@Param('salaryId') salaryId: string) { return this.svc.removeSalary(salaryId); }

  // ── staff ─────────────────────────────────────────────────────────────
  @Post() @ApiOperation({ summary: 'Add a staff member' })
  create(@Body() dto: CreateStaffDto) { return this.svc.create(dto); }

  @Get() @ApiOperation({ summary: 'List staff' })
  findAll(@Query() q: StaffQueryDto) { return this.svc.findAll(q); }

  @Get(':id/photo') @ApiOperation({ summary: 'Staff photo only (list rows omit it)' })
  photo(@Param('id') id: string) { return this.svc.getPhoto(id); }

  @Get(':id/salaries') @ApiOperation({ summary: 'All salary months for a staff member, newest first, with gross/deductions/net' })
  salaries(@Param('id') id: string) { return this.svc.findSalaries(id); }

  @Post(':id/salaries') @ApiOperation({ summary: 'Record a month’s salary (one per month)' })
  addSalary(@Param('id') id: string, @Body() dto: CreateStaffSalaryDto) { return this.svc.addSalary(id, dto); }

  @Get(':id') @ApiOperation({ summary: 'Get staff member by ID' })
  findOne(@Param('id') id: string) { return this.svc.findOne(id); }

  @Put(':id') @ApiOperation({ summary: 'Update staff member (children list is replaced when sent)' })
  update(@Param('id') id: string, @Body() dto: UpdateStaffDto) { return this.svc.update(id, dto); }

  @Delete(':id') @ApiOperation({ summary: 'Permanently delete a staff member' })
  remove(@Param('id') id: string) { return this.svc.remove(id); }
}
