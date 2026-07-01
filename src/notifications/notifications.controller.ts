import { Controller, Get, Post, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { NotificationsService } from './notifications.service';
import { CreateNotificationDto } from './dto/create-notification.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('notifications')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private svc: NotificationsService) {}

  @Get() @ApiOperation({ summary: 'My notifications' })
  findMine(@CurrentUser('id') uid: string, @Query('unread') unread?: string) {
    return this.svc.findForUser(uid, unread === 'true');
  }

  @Get('unread-count') @ApiOperation({ summary: 'Unread notification count' })
  unreadCount(@CurrentUser('id') uid: string) { return this.svc.unreadCount(uid); }

  @Patch(':id/read') @ApiOperation({ summary: 'Mark notification as read' })
  markRead(@Param('id') id: string) { return this.svc.markRead(id); }

  @Patch('read-all') @ApiOperation({ summary: 'Mark all as read' })
  markAllRead(@CurrentUser('id') uid: string) { return this.svc.markAllRead(uid); }

  @Post('device-token') @ApiOperation({ summary: 'Register FCM device token' })
  registerToken(@CurrentUser('id') uid: string, @Body() body: { token: string; platform?: string }) {
    return this.svc.registerDeviceToken(uid, body.token, body.platform);
  }

  @Post('send') @ApiOperation({ summary: 'Create in-app notification (admin)' })
  create(@Body() dto: CreateNotificationDto) { return this.svc.create(dto); }
}
