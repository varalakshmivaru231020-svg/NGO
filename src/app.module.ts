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
import { ExpensesModule } from './expenses/expenses.module';
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
import { PublicDonationsModule } from './public-donations/public-donations.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),

    // Per-IP budget. It must comfortably cover one busy admin session: the
    // dashboard alone fires a dozen calls and list screens page through every
    // record, and an office shares one public IP between all its staff. At
    // the old 100/min, hitting the cap returned 429s that showed up as zeros
    // on screen — and a 429 on /auth/refresh signed the user out. Login keeps
    // its own much tighter limit (see AuthController).
    ThrottlerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => [
        {
          ttl: Number(config.get('THROTTLE_TTL', 60)) * 1000,
          limit: Math.max(Number(config.get('THROTTLE_LIMIT', 1000)), 1000),
        },
      ],
    }),

    ScheduleModule.forRoot(),

    PrismaModule,
    AuthModule,
    UsersModule,
    DonorsModule,
    DonationsModule,
    ExpensesModule,
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
    PublicDonationsModule,
  ],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
