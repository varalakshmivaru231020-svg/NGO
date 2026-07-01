import { Module } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { NotificationsModule } from '../notifications/notifications.module';
import { ApprovalsService } from './approvals.service';
import { ApprovalsController } from './approvals.controller';
import { ApprovalInterceptor } from './approval.interceptor';

@Module({
  imports: [NotificationsModule],
  controllers: [ApprovalsController],
  providers: [
    ApprovalsService,
    // Registered globally — every mutating request flows through it.
    { provide: APP_INTERCEPTOR, useClass: ApprovalInterceptor },
  ],
  exports: [ApprovalsService],
})
export class ApprovalsModule {}
