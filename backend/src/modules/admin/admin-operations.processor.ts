import { InjectQueue, Process, Processor } from '@nestjs/bull';
import { ConfigService } from '@nestjs/config';
import { Logger, OnModuleInit } from '@nestjs/common';
import { Job, Queue } from 'bull';
import { AdminOperationsService } from './admin-operations.service';

export const ADMIN_OPERATIONS_QUEUE = 'admin-operations';
export const NIGHTLY_COMMISSION_JOB = 'nightly-commission-generation';
export const NIGHTLY_COMMISSION_REPEAT_JOB_ID =
  'nightly-commission-generation-repeat';
export const NIGHTLY_COMMISSION_REGISTRATION_WARN_AFTER_MS = 10_000;

@Processor(ADMIN_OPERATIONS_QUEUE)
export class AdminOperationsProcessor implements OnModuleInit {
  private readonly logger = new Logger(AdminOperationsProcessor.name);

  constructor(
    private readonly service: AdminOperationsService,
    private readonly config: ConfigService,
    @InjectQueue(ADMIN_OPERATIONS_QUEUE) private readonly queue: Queue,
  ) {}

  onModuleInit(): void {
    const tz = this.config.get<string>('business.timezone') ?? 'Asia/Karachi';
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

  @Process(NIGHTLY_COMMISSION_JOB)
  async generateNightlyCollections(_job: Job): Promise<void> {
    const result = await this.service.runNightly({}, null);
    this.logger.log(
      `[nightly-commission] date=${result.collectionDate} workers=${result.workerCount} amount=${result.totalAmount}`,
    );
  }
}
