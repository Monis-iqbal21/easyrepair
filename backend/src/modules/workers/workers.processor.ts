import { Processor, Process } from '@nestjs/bull';
import { Logger } from '@nestjs/common';
import { AvailabilityStatus } from '@prisma/client';
import { Job } from 'bull';

import { NotificationsService } from '../notifications/notifications.service';
import { WorkersRepository } from './workers.repository';

export const WORKERS_QUEUE = 'workers';
export const AUTO_OFFLINE_JOB = 'auto-offline';

export interface AutoOfflineJobData {
  workerProfileId: string;
  userId: string;
}

@Processor(WORKERS_QUEUE)
export class WorkersProcessor {
  private readonly logger = new Logger(WorkersProcessor.name);

  constructor(
    private readonly workersRepository: WorkersRepository,
    private readonly notificationsService: NotificationsService,
  ) {}

  @Process(AUTO_OFFLINE_JOB)
  async handleAutoOffline(job: Job<AutoOfflineJobData>): Promise<void> {
    const { workerProfileId, userId } = job.data;
    this.logger.log(
      `[auto-offline] fired for workerProfileId=${workerProfileId}`,
    );

    // Guard: worker may have already gone offline manually — do nothing if so.
    const profile = await this.workersRepository.findById(workerProfileId);
    if (!profile || profile.availabilityStatus !== AvailabilityStatus.ONLINE) {
      this.logger.log(
        `[auto-offline] skipped — worker is not online (workerProfileId=${workerProfileId})`,
      );
      return;
    }

    await this.workersRepository.setOfflineById(workerProfileId);
    this.logger.log(
      `[auto-offline] set offline workerProfileId=${workerProfileId}`,
    );

    void this.notificationsService.notify({
      userId,
      eventKey: 'worker.auto_offline',
      title: 'You have been set offline',
      body: 'You were automatically set offline after 7 hours. Go online again to receive new jobs.',
      route: '/worker/home',
      entityType: 'worker',
      entityId: workerProfileId,
    });
  }
}
