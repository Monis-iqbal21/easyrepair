import { Processor, Process } from '@nestjs/bull';
import { Logger } from '@nestjs/common';
import { Job } from 'bull';

import { BookingExpiryService } from './booking-expiry.service';

export const BOOKINGS_QUEUE = 'bookings';
export const EXPIRE_BOOKING_JOB = 'expire-booking';
export const SWEEP_EXPIRED_BOOKINGS_JOB = 'sweep-expired-bookings';

export interface ExpireBookingJobData {
  bookingId: string;
}

/**
 * 72h auto-expiry for PENDING bookings across all lanes.
 *
 * Both handlers are thin: the transition, its guards and its side effects live
 * once, in BookingExpiryService. The delayed job is the fast path; the sweep
 * job is the DB-backed safety net registered by BookingExpiryScheduler.
 */
@Processor(BOOKINGS_QUEUE)
export class BookingsProcessor {
  private readonly logger = new Logger(BookingsProcessor.name);

  constructor(private readonly expiryService: BookingExpiryService) {}

  @Process(EXPIRE_BOOKING_JOB)
  async handleExpireBooking(job: Job<ExpireBookingJobData>): Promise<void> {
    const { bookingId } = job.data;
    this.logger.log(`[expire-booking] fired for bookingId=${bookingId}`);
    await this.expiryService.expireBooking(bookingId, 'job');
  }

  @Process(SWEEP_EXPIRED_BOOKINGS_JOB)
  async handleSweepExpiredBookings(): Promise<void> {
    await this.expiryService.sweepExpiredBookings();
  }
}
