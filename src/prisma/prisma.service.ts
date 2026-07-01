import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  // Neon (serverless Postgres) scales to zero when idle, so the first connect
  // after a cold start can fail. Retry a few times and, if it still fails,
  // start anyway — the first query will wake the DB — rather than crashing the
  // whole app on boot.
  async onModuleInit() {
    for (let attempt = 1; attempt <= 5; attempt++) {
      try {
        await this.$connect();
        return;
      } catch (e: any) {
        this.logger.warn(
          `DB connect attempt ${attempt}/5 failed (${e?.errorCode ?? e?.message}). Retrying…`,
        );
        await new Promise((r) => setTimeout(r, attempt * 1500));
      }
    }
    this.logger.error('Could not connect to the database at startup; continuing (will retry on first query).');
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
