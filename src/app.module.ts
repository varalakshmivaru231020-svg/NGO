import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { ScheduleModule } from '@nestjs/schedule';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { DonorsModule } from './donors/donors.module';
import { DonationsModule } from './donations/donations.module';
import { StudentsModule } from './students/students.module';
import { CategoriesModule } from './categories/categories.module';
import { AchievementsModule } from './achievements/achievements.module';
import { RemindersModule } from './reminders/reminders.module';
import { OfficesModule } from './offices/offices.module';
import { ReportsModule } from './reports/reports.module';
import { NotificationsModule } from './notifications/notifications.module';
import { PaymentLinksModule } from './payment-links/payment-links.module';
import { WebsocketModule } from './websocket/websocket.module';
import { ApprovalsModule } from './approvals/approvals.module';
import { SettingsModule } from './settings/settings.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),

    ThrottlerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => [
        {
          ttl: config.get('THROTTLE_TTL', 60) * 1000,
          limit: config.get('THROTTLE_LIMIT', 100),
        },
      ],
    }),

    ScheduleModule.forRoot(),

    PrismaModule,
    AuthModule,
    UsersModule,
    DonorsModule,
    DonationsModule,
    StudentsModule,
    CategoriesModule,
    AchievementsModule,
    RemindersModule,
    OfficesModule,
    ReportsModule,
    NotificationsModule,
    PaymentLinksModule,
    WebsocketModule,
    ApprovalsModule,
    SettingsModule,
  ],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
