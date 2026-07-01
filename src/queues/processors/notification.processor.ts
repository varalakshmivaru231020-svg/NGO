import { Process, Processor } from '@nestjs/bull';
import type { Job } from 'bull';
import { Logger } from '@nestjs/common';

export const NOTIFICATION_QUEUE = 'notifications';

@Processor(NOTIFICATION_QUEUE)
export class NotificationProcessor {
  private readonly logger = new Logger(NotificationProcessor.name);

  @Process('send-push')
  async handleSendPush(job: Job<{ tokens: string[]; title: string; body: string; data?: any }>) {
    const { tokens, title, body } = job.data;
    this.logger.log(`Sending push to ${tokens.length} devices: "${title}"`);
    // FCM integration point — inject firebase-admin and call messaging().sendEachForMulticast()
    // const messaging = admin.messaging();
    // await messaging.sendEachForMulticast({ tokens, notification: { title, body } });
  }

  @Process('send-reminder')
  async handleReminder(job: Job<{ donorId: string; message: string }>) {
    this.logger.log(`Processing reminder for donor ${job.data.donorId}`);
  }
}
