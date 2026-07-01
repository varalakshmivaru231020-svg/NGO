import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateNotificationDto } from './dto/create-notification.dto';

@Injectable()
export class NotificationsService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreateNotificationDto) {
    return this.prisma.notification.create({ data: dto });
  }

  async findForUser(userId: string, unreadOnly = false) {
    return this.prisma.notification.findMany({
      where: { userId, ...(unreadOnly ? { status: 'UNREAD' } : {}) },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async markRead(id: string) {
    return this.prisma.notification.update({ where: { id }, data: { status: 'READ' } });
  }

  async markAllRead(userId: string) {
    return this.prisma.notification.updateMany({ where: { userId, status: 'UNREAD' }, data: { status: 'READ' } });
  }

  async unreadCount(userId: string) {
    const count = await this.prisma.notification.count({ where: { userId, status: 'UNREAD' } });
    return { count };
  }

  async registerDeviceToken(userId: string, token: string, platform = 'android') {
    return this.prisma.deviceToken.upsert({
      where: { token },
      create: { userId, token, platform },
      update: { userId },
    });
  }

  async removeDeviceToken(token: string) {
    return this.prisma.deviceToken.deleteMany({ where: { token } });
  }
}
