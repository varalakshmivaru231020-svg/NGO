import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { PaginationDto } from '../common/dto/pagination.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

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
}
