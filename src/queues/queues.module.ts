import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bull';
import { NotificationProcessor, NOTIFICATION_QUEUE } from './processors/notification.processor';

@Module({
  imports: [BullModule.registerQueue({ name: NOTIFICATION_QUEUE })],
  providers: [NotificationProcessor],
  exports: [BullModule],
})
export class QueuesModule {}
