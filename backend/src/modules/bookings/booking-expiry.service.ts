import { Injectable, Logger } from '@nestjs/common';
import { BidStatus, BookingLane, BookingStatus } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

/** Why a single expiry attempt did not transition the booking. */
export type ExpireBookingOutcome = 'EXPIRED' | 'SKIPPED';

export interface ExpirySweepResult {
  scanned: number;
  expired: number;
  skipped: number;
  failed: number;
}

/** Bounded batch so one sweep can never hold a long transaction or hog Redis. */
export const EXPIRY_SWEEP_BATCH_SIZE = 200;

/**
 * The ONE authoritative 72h auto-expiry transition for PENDING bookings.
 *
 * Two callers drive it and must never diverge:
 *   1. the BullMQ delayed `expire-booking` job (fast path, fires at expiresAt)
 *   2. the hourly DB sweeper (safety net — see BookingExpiryScheduler)
 *
 * Redis-delayed jobs are ephemeral: a Redis restart/flush, a failed enqueue
 * (BookingsService._scheduleExpiry is fire-and-forget behind a 1.8s timeout)
 * or a lost job leaves `bookings.expiresAt` in the past with the row still
 * PENDING forever. The DB is authoritative, so the sweeper reconciles from it.
 */
@Injectable()
export class BookingExpiryService {
  private readonly logger = new Logger(BookingExpiryService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
  ) {}

  /**
   * Expire ONE booking, idempotently.
   *
   * The status guard is applied twice on purpose: once when reading (cheap
   * early-out, and it gives us the lane/client for the side effects) and once
   * inside the write itself via `updateMany({ where: { id, status: PENDING } })`.
   * Only the second one is authoritative — it is what makes a BullMQ job and a
   * concurrent sweeper produce exactly ONE transition, one history row and one
   * notification. ACCEPTED / EN_ROUTE / IN_PROGRESS / COMPLETED / CANCELLED /
   * REJECTED / already-EXPIRED bookings are never touched, however old their
   * `expiresAt` is.
   */
  async expireBooking(
    bookingId: string,
    source: 'job' | 'sweeper' = 'job',
  ): Promise<ExpireBookingOutcome> {
    const tag = `[expire-booking:${source}]`;

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
        `${tag} skipped — booking is not PENDING (bookingId=${bookingId})`,
      );
      return 'SKIPPED';
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
          `${tag} skipped — accepted bid exists (bookingId=${bookingId})`,
        );
        return 'SKIPPED';
      }
    }

    const transitioned = await this.prisma.$transaction(async (tx) => {
      // Authoritative guard: whoever wins this conditional update owns the
      // transition. The loser gets count === 0 and writes nothing at all —
      // no history row, and (below) no duplicate notification.
      const { count } = await tx.booking.updateMany({
        where: { id: bookingId, status: BookingStatus.PENDING },
        data: { status: BookingStatus.EXPIRED },
      });
      if (count !== 1) return false;

      await tx.bookingStatusHistory.create({
        data: {
          bookingId,
          status: BookingStatus.EXPIRED,
          note: 'Auto-expired after 72 hours with no worker hired',
        },
      });
      return true;
    });

    if (!transitioned) {
      this.logger.log(
        `${tag} skipped — lost the expiry race (bookingId=${bookingId})`,
      );
      return 'SKIPPED';
    }

    this.logger.log(`${tag} set EXPIRED bookingId=${bookingId}`);

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

    return 'EXPIRED';
  }

  /**
   * DB-backed reconciliation: expire every booking whose authoritative state
   * is `status = PENDING AND expiresAt IS NOT NULL AND expiresAt <= now()`.
   *
   * Oldest first and capped at [limit] so a large backlog drains over
   * successive hourly runs instead of in one unbounded pass. Each row is
   * expired independently — a failure on one row is logged and the sweep
   * continues, so it can never corrupt or block unrelated bookings.
   */
  async sweepExpiredBookings(
    limit: number = EXPIRY_SWEEP_BATCH_SIZE,
  ): Promise<ExpirySweepResult> {
    const candidates = await this.prisma.booking.findMany({
      where: {
        status: BookingStatus.PENDING,
        expiresAt: { not: null, lte: new Date() },
      },
      select: { id: true },
      orderBy: { expiresAt: 'asc' },
      take: limit,
    });

    const result: ExpirySweepResult = {
      scanned: candidates.length,
      expired: 0,
      skipped: 0,
      failed: 0,
    };

    for (const candidate of candidates) {
      try {
        const outcome = await this.expireBooking(candidate.id, 'sweeper');
        if (outcome === 'EXPIRED') result.expired += 1;
        else result.skipped += 1;
      } catch (err) {
        result.failed += 1;
        this.logger.warn(
          `[expiry-sweep] failed for bookingId=${candidate.id}: ${(err as Error)?.message}`,
        );
      }
    }

    if (result.scanned > 0) {
      this.logger.log(
        `[expiry-sweep] scanned=${result.scanned} expired=${result.expired} skipped=${result.skipped} failed=${result.failed}`,
      );
    }

    return result;
  }
}
