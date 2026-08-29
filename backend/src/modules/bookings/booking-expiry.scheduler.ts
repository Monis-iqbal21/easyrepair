import { InjectQueue } from '@nestjs/bull';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Queue } from 'bull';

import { PostListenService } from '../../common/startup/http-startup';
import { BOOKINGS_QUEUE, SWEEP_EXPIRED_BOOKINGS_JOB } from './bookings.processor';

export const SWEEP_EXPIRED_BOOKINGS_REPEAT_JOB_ID =
  'sweep-expired-bookings-repeat';

/** Hourly, at :07 — off the top of the hour so it never piles onto whatever
 *  else the platform schedules on the hour boundary. */
export const EXPIRY_SWEEP_CRON = '7 * * * *';

/**
 * Registers the hourly DB reconciliation sweep on the existing bookings queue.
 *
 * Reuses the repeatable-job convention already established by
 * AdminOperationsScheduler rather than pulling in @nestjs/schedule, and is
 * started from main.ts AFTER app.listen() so Bull/Redis stays out of the API's
 * readiness path.
 *
 * Restart-safe by construction: the repeat registration is re-issued on every
 * process start under a fixed jobId, so it is recreated after any deploy,
 * crash or Redis flush — it never depends on one delayed job surviving. Safe
 * with multiple instances: Bull dedupes the repeat key, only one worker picks
 * up each occurrence, and BookingExpiryService.expireBooking guards the
 * transition at write time anyway.
 */
@Injectable()
export class BookingExpiryScheduler implements PostListenService {
  private readonly logger = new Logger(BookingExpiryScheduler.name);
  private started = false;

  constructor(
    @InjectQueue(BOOKINGS_QUEUE) private readonly bookingsQueue: Queue,
    private readonly config: ConfigService,
  ) {}

  start(): void {
    if (this.started) return;
    this.started = true;

    const tz = this.config.get<string>('business.timezone') ?? 'Asia/Karachi';

    // Never awaited: Bull retries Redis commands indefinitely while the
    // connection is down, and the HTTP server must not wait on that.
    void this.bookingsQueue
      .add(
        SWEEP_EXPIRED_BOOKINGS_JOB,
        {},
        {
          jobId: SWEEP_EXPIRED_BOOKINGS_REPEAT_JOB_ID,
          repeat: { cron: EXPIRY_SWEEP_CRON, tz },
          removeOnComplete: true,
          removeOnFail: 100,
        },
      )
      .then(() => {
        this.logger.log(
          `[expiry-sweep] repeatable job registered (cron="${EXPIRY_SWEEP_CRON}" timezone=${tz})`,
        );
      })
      .catch((error: unknown) => {
        this.logger.warn(
          `[expiry-sweep] failed to schedule repeatable job: ${(error as Error)?.message}`,
        );
      });
  }
}
