import { Processor, Process } from '@nestjs/bull';
import { Logger } from '@nestjs/common';
import { BidStatus, BookingLane, BookingStatus } from '@prisma/client';
import { Job } from 'bull';

import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

export const BOOKINGS_QUEUE = 'bookings';
export const EXPIRE_BOOKING_JOB = 'expire-booking';

export interface ExpireBookingJobData {
  bookingId: string;
}

/**
 * 72h auto-expiry for PENDING bookings across all lanes, mirroring the
 * workers.processor.ts auto-offline pattern: deterministic jobId, re-check
 * current DB state before acting (guards against races with an assignment/
 * cancellation/bid-acceptance that already happened since the job was queued).
 */
@Processor(BOOKINGS_QUEUE)
export class BookingsProcessor {
  private readonly logger = new Logger(BookingsProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
  ) {}

  @Process(EXPIRE_BOOKING_JOB)
  async handleExpireBooking(job: Job<ExpireBookingJobData>): Promise<void> {
    const { bookingId } = job.data;
    this.logger.log(`[expire-booking] fired for bookingId=${bookingId}`);

    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: {
        id: true,
        status: true,
        lane: true,
        clientProfile: { select: { userId: true } },
      },
    });

    if (!booking || booking.status !== BookingStatus.PENDING) {
      this.logger.log(
        `[expire-booking] skipped — booking is not PENDING (bookingId=${bookingId})`,
      );
      return;
    }

    // BIDDING lane: only expire if no bid has been accepted. (If a bid was
    // accepted the booking would already be ACCEPTED, not PENDING — this is
    // an extra guard against any race between bid-acceptance and this job.)
    if (booking.lane === BookingLane.BIDDING) {
      const acceptedBid = await this.prisma.bid.findFirst({
        where: { bookingId, status: BidStatus.ACCEPTED },
        select: { id: true },
      });
      if (acceptedBid) {
        this.logger.log(
          `[expire-booking] skipped — accepted bid exists (bookingId=${bookingId})`,
        );
        return;
      }
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: { status: BookingStatus.EXPIRED },
      });
      await tx.bookingStatusHistory.create({
        data: {
          bookingId,
          status: BookingStatus.EXPIRED,
          note: 'Auto-expired after 72 hours with no worker hired',
        },
      });
    });

    this.logger.log(`[expire-booking] set EXPIRED bookingId=${bookingId}`);

    if (booking.clientProfile?.userId) {
      void this.notificationsService.notify({
        userId: booking.clientProfile.userId,
        eventKey: 'booking.expired',
        title: 'Job Expired',
        body: 'Your job request expired after 72 hours with no worker hired. Tap to make it live again.',
        bookingId,
        route: `/client/booking/${bookingId}`,
        entityType: 'booking',
        entityId: bookingId,
      });
    }
  }
}
