import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { ReportsService } from './reports.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('reports')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard)
@Controller('reports')
export class ReportsController {
  constructor(private svc: ReportsService) {}

  @Get('overview') @ApiOperation({ summary: 'Full NGO overview report' })
  overview() { return this.svc.overview(); }

  @Get('monthly-trend') @ApiOperation({ summary: 'Monthly donation trend' })
  @ApiQuery({ name: 'months', type: Number, required: false })
  monthlyTrend(@Query('months') months = 12) { return this.svc.monthlyTrend(+months); }

  @Get('donor-retention') @ApiOperation({ summary: 'Donor retention stats' })
  donorRetention() { return this.svc.donorRetention(); }
}
