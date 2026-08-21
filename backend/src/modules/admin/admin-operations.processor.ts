import { InjectQueue, Process, Processor } from '@nestjs/bull';
import { ConfigService } from '@nestjs/config';
import { Logger, OnModuleInit } from '@nestjs/common';
import { Job, Queue } from 'bull';
import { AdminOperationsService } from './admin-operations.service';

export const ADMIN_OPERATIONS_QUEUE = 'admin-operations';
export const NIGHTLY_COMMISSION_JOB = 'nightly-commission-generation';
export const NIGHTLY_COMMISSION_REPEAT_JOB_ID =
  'nightly-commission-generation-repeat';

@Processor(ADMIN_OPERATIONS_QUEUE)
export class AdminOperationsProcessor implements OnModuleInit {
  private readonly logger = new Logger(AdminOperationsProcessor.name);

  constructor(
    private readonly service: AdminOperationsService,
    private readonly config: ConfigService,
    @InjectQueue(ADMIN_OPERATIONS_QUEUE) private readonly queue: Queue,
  ) {}

  async onModuleInit(): Promise<void> {
    const tz = this.config.get<string>('business.timezone') ?? 'Asia/Karachi';
    try {
      await this.queue.add(
        NIGHTLY_COMMISSION_JOB,
        {},
        {
          jobId: NIGHTLY_COMMISSION_REPEAT_JOB_ID,
          repeat: { cron: '0 0 * * *', tz },
          removeOnComplete: true,
          removeOnFail: 100,
        },
      );
    } catch (error) {
      this.logger.warn(
        `[nightly-commission] failed to schedule repeatable job: ${(error as Error)?.message}`,
      );
    }
  }

  @Process(NIGHTLY_COMMISSION_JOB)
  async generateNightlyCollections(_job: Job): Promise<void> {
    const result = await this.service.runNightly({}, null);
    this.logger.log(
      `[nightly-commission] date=${result.collectionDate} workers=${result.workerCount} amount=${result.totalAmount}`,
    );
  }
}
