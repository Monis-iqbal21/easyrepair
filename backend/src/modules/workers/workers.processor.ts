import { Processor, Process, InjectQueue } from '@nestjs/bull';
import { Logger, OnModuleInit } from '@nestjs/common';
import { AvailabilityStatus } from '@prisma/client';
import { Job, Queue } from 'bull';

import { NotificationsService } from '../notifications/notifications.service';
import { WORKER_PRESENCE_STALE_MS } from '../../common/utils/job-eligibility.util';
import { WorkersRepository } from './workers.repository';

export const WORKERS_QUEUE = 'workers';
export const AUTO_OFFLINE_JOB = 'auto-offline';
export const STALE_PRESENCE_CLEANUP_JOB = 'stale-presence-cleanup';

/** 10–15 minute cadence, per the presence-lease design — see WORKER_PRESENCE_STALE_MS. */
const STALE_PRESENCE_CLEANUP_INTERVAL_MS = 15 * 60 * 1000;
const STALE_PRESENCE_CLEANUP_REPEAT_JOB_ID = 'stale-presence-cleanup-repeat';

export interface AutoOfflineJobData {
  workerProfileId: string;
  userId: string;
}

@Processor(WORKERS_QUEUE)
export class WorkersProcessor implements OnModuleInit {
  private readonly logger = new Logger(WorkersProcessor.name);

  constructor(
    private readonly workersRepository: WorkersRepository,
    private readonly notificationsService: NotificationsService,
    @InjectQueue(WORKERS_QUEUE) private readonly queue: Queue,
  ) {}

  /**
   * Registers the periodic stale-presence cleanup as a Bull repeatable job.
   * Idempotent across restarts/multiple instances — Bull dedupes repeatable
   * jobs by their (name, repeat options, jobId) key, so this never produces
   * more than one active schedule.
   */
  async onModuleInit(): Promise<void> {
    try {
      await this.queue.add(
        STALE_PRESENCE_CLEANUP_JOB,
        {},
        {
          jobId: STALE_PRESENCE_CLEANUP_REPEAT_JOB_ID,
          repeat: { every: STALE_PRESENCE_CLEANUP_INTERVAL_MS },
          removeOnComplete: true,
          removeOnFail: true,
        },
      );
    } catch (err) {
      // Redis unreachable at boot — the matching-time eligibility gate
      // (checkJobEligibility) still enforces the presence lease independently,
      // so this is a scheduling-only degradation, never a correctness gap.
      this.logger.warn(
        `[stale-presence-cleanup] failed to schedule repeatable job: ${(err as Error)?.message}`,
      );
    }
  }

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
      title: 'Aap offline ho gaye hain',
      body: '7 ghantay baad aap automatically offline ho gaye hain. Naye kaam paane ke liye dobara online hon.',
      route: '/worker/home',
      entityType: 'worker',
      entityId: workerProfileId,
    });
  }

  /**
   * Periodic reconciliation for the presence lease: force-flips any ONLINE
   * worker whose `lastSeenAt` has gone stale to OFFLINE and persists exactly
   * one INACTIVITY notification per genuine transition.
   *
   * This is a SAFETY NET, not the primary defense — checkJobEligibility
   * already rejects a stale-but-still-ONLINE worker at matching time even
   * before this job next runs (see job-eligibility.util.ts). This job exists
   * so the Worker's own OFFLINE state (and their own UI) eventually catches
   * up too, and so the account gets the persisted "why am I offline" notice.
   */
  @Process(STALE_PRESENCE_CLEANUP_JOB)
  async handleStalePresenceCleanup(): Promise<void> {
    const staleBefore = new Date(Date.now() - WORKER_PRESENCE_STALE_MS);
    const candidates =
      await this.workersRepository.findStaleOnlineWorkers(staleBefore);
    if (candidates.length === 0) return;

    this.logger.log(
      `[stale-presence-cleanup] found ${candidates.length} stale ONLINE worker(s)`,
    );

    for (const candidate of candidates) {
      // Atomic, race-safe transition — see setOfflineIfStillOnline. A
      // worker who manually went offline (or was already handled by a
      // concurrent pass) is skipped here, never double-notified.
      const transitioned = await this.workersRepository.setOfflineIfStillOnline(
        candidate.id,
      );
      if (!transitioned) continue;

      await this.queue
        .getJob(`auto-offline-${candidate.id}`)
        .then((job) => job?.remove())
        .catch(() => undefined);

      void this.notificationsService.notify({
        userId: candidate.userId,
        eventKey: 'worker.availability.forced_offline',
        title: 'Ap offline ho gaye hain',
        body: 'App kuch dair se active nahi thi, is liye apko offline kar diya gaya hai.',
        route: '/worker/home',
        entityType: 'worker',
        entityId: candidate.id,
        payload: { reason: 'INACTIVITY' },
      });
    }
  }
}
