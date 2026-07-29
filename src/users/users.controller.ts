import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards, ForbiddenException } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { CreateUserDocumentDto } from './dto/create-user-document.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { UpdateMyProfileDto } from './dto/update-my-profile.dto';
import { PaginationDto } from '../common/dto/pagination.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import type { SessionUser } from '../approvals/approvals.service';

@ApiTags('users')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('users')
export class UsersController {
  constructor(private usersService: UsersService) {}

  @Post()
  @Roles('ADMIN')
  @ApiOperation({ summary: 'Create a new user' })
  create(@Body() dto: CreateUserDto) { return this.usersService.create(dto); }

  @Get()
  @Roles('ADMIN')
  @ApiOperation({ summary: 'List all users' })
  findAll(@Query() query: PaginationDto) { return this.usersService.findAll(query); }

  @Get('me')
  @ApiOperation({ summary: 'Get my profile' })
  getMe(@CurrentUser('id') id: string) { return this.usersService.findOne(id); }

  // No @Roles(...) — any authenticated user (not just ADMIN) can fetch this
  // lightweight list, e.g. to populate the Expense "Approved By" dropdown.
  @Get('approvers')
  @ApiOperation({ summary: 'List active staff eligible to be picked as an approver' })
  findApprovers() { return this.usersService.findApprovers(); }

  // Declared before ':id' routes so 'me' can't be captured as an id.
  @Patch('me/profile')
  @ApiOperation({ summary: 'Update my own name/phone/photo' })
  updateMyProfile(@CurrentUser('id') id: string, @Body() dto: UpdateMyProfileDto) {
    return this.usersService.updateOwnProfile(id, dto);
  }

  @Patch('me/password')
  @ApiOperation({ summary: 'Change my own password (verifies the current one)' })
  changeMyPassword(@CurrentUser('id') id: string, @Body() dto: ChangePasswordDto) {
    return this.usersService.changeOwnPassword(id, dto.currentPassword, dto.newPassword);
  }

  @Get(':id')
  @Roles('ADMIN')
  @ApiOperation({ summary: 'Get user by ID' })
  findOne(@Param('id') id: string) { return this.usersService.findOne(id); }

  @Patch(':id')
  @Roles('ADMIN')
  @ApiOperation({ summary: 'Update user' })
  update(@Param('id') id: string, @Body() dto: UpdateUserDto) { return this.usersService.update(id, dto); }

  @Patch(':id/toggle-active')
  @Roles('ADMIN')
  @ApiOperation({ summary: 'Toggle user active status' })
  toggleActive(@Param('id') id: string) { return this.usersService.toggleActive(id); }

  @Delete(':id')
  @Roles('ADMIN')
  @ApiOperation({ summary: 'Remove (deactivate) a team member so they can no longer log in' })
  remove(@Param('id') id: string) { return this.usersService.remove(id); }

  // ── Staff/own-profile documents ──────────────────────────────────────────
  // No @Roles(...) — access is "self OR ADMIN/SUPER_ADMIN", which @Roles()
  // alone can't express, so it's checked inline against the target userId.
  // These routes are also listed in ApprovalsService.EXEMPT_PATH_PATTERNS so
  // uploads by non-SUPER_ADMIN staff save immediately instead of queuing.

  private assertSelfOrAdmin(caller: SessionUser, targetUserId: string) {
    const isSelf = caller.id === targetUserId;
    const isAdmin = caller.role === 'ADMIN' || caller.role === 'SUPER_ADMIN';
    if (!isSelf && !isAdmin) throw new ForbiddenException('Not allowed to access this user\'s documents');
  }

  @Post(':id/documents')
  @ApiOperation({ summary: "Upload a document to a user's own profile (self or ADMIN)" })
  async addDocument(@Param('id') id: string, @Body() dto: CreateUserDocumentDto, @CurrentUser() user: SessionUser) {
    this.assertSelfOrAdmin(user, id);
    return this.usersService.addDocument(id, dto);
  }

  @Get(':id/documents')
  @ApiOperation({ summary: "List a user's document metadata (no file content)" })
  async getDocuments(@Param('id') id: string, @CurrentUser() user: SessionUser) {
    this.assertSelfOrAdmin(user, id);
    return this.usersService.getDocuments(id);
  }

  @Get('documents/:docId')
  @ApiOperation({ summary: 'Get a document with its file content' })
  async getDocument(@Param('docId') docId: string, @CurrentUser() user: SessionUser) {
    const doc = await this.usersService.getDocument(docId);
    this.assertSelfOrAdmin(user, doc.userId);
    return doc;
  }

  @Delete('documents/:docId')
  @ApiOperation({ summary: 'Remove a document' })
  async removeDocument(@Param('docId') docId: string, @CurrentUser() user: SessionUser) {
    const doc = await this.usersService.getDocument(docId);
    this.assertSelfOrAdmin(user, doc.userId);
    return this.usersService.removeDocument(docId);
  }
}
