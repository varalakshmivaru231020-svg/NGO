import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  Headers,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { ApprovalsService } from './approvals.service';
import type { SessionUser } from './approvals.service';
import { ApprovalQueryDto } from './dto/approval-query.dto';
import { RejectDto, BulkApproveDto, BulkRejectDto } from './dto/review.dto';

@ApiTags('approvals')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('approvals')
export class ApprovalsController {
  constructor(private svc: ApprovalsService) {}

  // Any authenticated user can see the status of their own requests.
  @Get('mine') @ApiOperation({ summary: 'My approval requests' })
  mine(@CurrentUser() user: SessionUser) {
    return this.svc.mine(user.id);
  }

  // ── Admin + Super Admin below (RolesGuard always passes SUPER_ADMIN) ────
  // ADMIN accounts get the full admin UI, so they review approvals too —
  // previously SUPER_ADMIN-only, which left ADMINs a badge count with an
  // empty, silently-403ing list.
  @Get('stats') @Roles('ADMIN') @ApiOperation({ summary: 'Approval counts' })
  stats() {
    return this.svc.stats();
  }

  @Get() @Roles('ADMIN') @ApiOperation({ summary: 'List approval requests (filterable)' })
  list(@Query() q: ApprovalQueryDto) {
    return this.svc.list(q);
  }

  @Get(':id') @Roles('ADMIN') @ApiOperation({ summary: 'Approval request detail (old vs new)' })
  findOne(@Param('id') id: string) {
    return this.svc.findOne(id);
  }

  @Post('bulk-approve') @Roles('ADMIN') @ApiOperation({ summary: 'Approve many' })
  bulkApprove(
    @Body() dto: BulkApproveDto,
    @Headers('authorization') auth: string,
    @CurrentUser() user: SessionUser,
  ) {
    return this.svc.bulkApprove(dto.ids, auth, user);
  }

  @Post('bulk-reject') @Roles('ADMIN') @ApiOperation({ summary: 'Reject many' })
  bulkReject(@Body() dto: BulkRejectDto, @CurrentUser() user: SessionUser) {
    return this.svc.bulkReject(dto.ids, dto.reason, user);
  }

  @Post(':id/approve') @Roles('ADMIN') @ApiOperation({ summary: 'Approve & execute' })
  approve(
    @Param('id') id: string,
    @Headers('authorization') auth: string,
    @CurrentUser() user: SessionUser,
  ) {
    return this.svc.approve(id, auth, user);
  }

  @Post(':id/reject') @Roles('ADMIN') @ApiOperation({ summary: 'Reject with reason' })
  reject(
    @Param('id') id: string,
    @Body() dto: RejectDto,
    @CurrentUser() user: SessionUser,
  ) {
    return this.svc.reject(id, dto.reason, user);
  }
}
