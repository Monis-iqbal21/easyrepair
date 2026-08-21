import { Inject, Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Queue, { Queue as BullQueue } from 'bull';
import { AdminOperationsService } from './admin-operations.service';

export const ADMIN_OPERATIONS_QUEUE = 'admin-operations';
export const NIGHTLY_COMMISSION_JOB = 'nightly-commission-generation';
export const NIGHTLY_COMMISSION_REPEAT_JOB_ID =
  'nightly-commission-generation-repeat';
export const NIGHTLY_COMMISSION_REGISTRATION_WARN_AFTER_MS = 10_000;
export const ADMIN_OPERATIONS_QUEUE_FACTORY = Symbol(
  'ADMIN_OPERATIONS_QUEUE_FACTORY',
);

export type AdminOperationsQueueFactory = (
  name: string,
  redisUrl: string,
) => BullQueue;

export const defaultAdminOperationsQueueFactory: AdminOperationsQueueFactory = (
  name,
  redisUrl,
) => new Queue(name, redisUrl);

/**
 * Deliberately not an @Processor or lifecycle-hook provider. main.ts starts it
 * only after app.listen() has bound the HTTP socket, keeping Bull/Redis out of
 * the API's critical readiness path.
 */
@Injectable()
export class AdminOperationsScheduler implements OnModuleDestroy {
  private readonly logger = new Logger(AdminOperationsScheduler.name);
  private queue?: BullQueue;
  private started = false;

  constructor(
    private readonly service: AdminOperationsService,
    private readonly config: ConfigService,
    @Inject(ADMIN_OPERATIONS_QUEUE_FACTORY)
    private readonly createQueue: AdminOperationsQueueFactory,
  ) {}

  start(): void {
    if (this.started) return;
    this.started = true;

    const tz = this.config.get<string>('business.timezone') ?? 'Asia/Karachi';
    const redisUrl = this.config.get<string>('redis.url');
    if (!redisUrl) {
      this.logger.warn(
        '[nightly-commission] REDIS_URL is unavailable; scheduler was not started',
      );
      return;
    }

    try {
      this.queue = this.createQueue(ADMIN_OPERATIONS_QUEUE, redisUrl);
    } catch (error) {
      this.logger.warn(
        `[nightly-commission] failed to create Bull queue: ${(error as Error)?.message}`,
      );
      return;
    }

    this.queue.on('error', (error: Error) => {
      this.logger.warn(`[nightly-commission] Bull error: ${error.message}`);
    });
    void this.queue
      .process(NIGHTLY_COMMISSION_JOB, (job) =>
        this.generateNightlyCollections(job),
      )
      .catch((error: unknown) => {
        this.logger.warn(
          `[nightly-commission] processor initialization failed: ${(error as Error)?.message}`,
        );
      });

    let settled = false;

    // Bull keeps retrying Redis commands while its connection is unavailable.
    // Do not await that retry loop from a Nest lifecycle hook: app.listen()
    // runs module initialization before binding the HTTP socket.
    const pendingWarning = setTimeout(() => {
      if (!settled) {
        this.logger.warn(
          `[nightly-commission] scheduler registration is still waiting for Redis after ${NIGHTLY_COMMISSION_REGISTRATION_WARN_AFTER_MS}ms; HTTP startup is not blocked and Bull will keep retrying`,
        );
      }
    }, NIGHTLY_COMMISSION_REGISTRATION_WARN_AFTER_MS);
    pendingWarning.unref?.();

    void this.queue
      .add(
        NIGHTLY_COMMISSION_JOB,
        {},
        {
          jobId: NIGHTLY_COMMISSION_REPEAT_JOB_ID,
          repeat: { cron: '0 0 * * *', tz },
          removeOnComplete: true,
          removeOnFail: 100,
        },
      )
      .then(() => {
        this.logger.log(
          `[nightly-commission] repeatable job registered (timezone=${tz})`,
        );
      })
      .catch((error: unknown) => {
        this.logger.warn(
          `[nightly-commission] failed to schedule repeatable job: ${(error as Error)?.message}`,
        );
      })
      .finally(() => {
        settled = true;
        clearTimeout(pendingWarning);
      });
  }

  async generateNightlyCollections(_job: unknown): Promise<void> {
    const result = await this.service.runNightly({}, null);
    this.logger.log(
      `[nightly-commission] date=${result.collectionDate} workers=${result.workerCount} amount=${result.totalAmount}`,
    );
  }

  onModuleDestroy(): void {
    if (this.queue) void this.queue.close().catch(() => undefined);
  }
}
