import { Injectable } from '@nestjs/common';
import { BidStatus, BookingStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { computeCompletedJobs } from '../../common/utils/worker-stats.util';
import { WorkerUnavailableError } from '../../common/errors/worker-unavailable.error';
import { JOB_DISCOVERY_WINDOW_MS } from '../../common/utils/job-eligibility.util';
import { boundingBoxKm, boundingBoxWhere } from '../../common/utils/geo.util';

export const BID_INCLUDE = {
  workerProfile: {
    select: {
      id: true,
      userId: true,
      firstName: true,
      lastName: true,
      avatarUrl: true,
      rating: true,
    },
  },
  booking: {
    select: {
      id: true,
      status: true,
      clientProfileId: true,
      workerProfileId: true,
    },
  },
} satisfies Prisma.BidInclude;

export type BidWithRelations = Prisma.BidGetPayload<{
  include: typeof BID_INCLUDE;
}>;

@Injectable()
export class BidsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findBookingById(bookingId: string) {
    return this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: {
        id: true,
        status: true,
        lane: true,
        clientProfileId: true,
        categoryId: true,
        latitude: true,
        longitude: true,
        clientProfile: { select: { userId: true } },
        inspectionReport: {
          select: { decisionStatus: true, workerProfileId: true },
        },
        // Linked repair booking spawned by "Find Other Ustaad" — the source
        // inspection's report identifies the original inspector, who must
        // never bid on their own repair job.
        sourceInspectionBookingId: true,
        sourceInspectionBooking: {
          select: {
            inspectionReport: {
              select: { decisionStatus: true, workerProfileId: true },
            },
          },
        },
        workerExclusions: { select: { workerProfileId: true } },
      },
    });
  }

  async findWorkerProfileByUserId(userId: string) {
    return this.prisma.workerProfile.findUnique({
      where: { userId },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        status: true,
        onboardingStatus: true,
        availabilityStatus: true,
        currentlyWorking: true,
        currentLat: true,
        currentLng: true,
        locationUpdatedAt: true,
        lastSeenAt: true,
        profileCompleted: true,
        skills: { select: { categoryId: true } },
      },
    });
  }

  async findClientProfileByUserId(userId: string) {
    return this.prisma.clientProfile.findUnique({
      where: { userId },
      select: { id: true },
    });
  }

  async findExistingBid(bookingId: string, workerProfileId: string) {
    return this.prisma.bid.findUnique({
      where: { bookingId_workerProfileId: { bookingId, workerProfileId } },
      select: { id: true, updatedAt: true, status: true },
    });
  }

  async findBidById(bidId: string): Promise<BidWithRelations | null> {
    return this.prisma.bid.findUnique({
      where: { id: bidId },
      include: BID_INCLUDE,
    });
  }

  /**
   * `Bid @@unique([bookingId, workerProfileId])` backs "one active bid per
   * worker/job". A genuine concurrent double-submit (the caller's own
   * findExistingBid check raced another request creating the row first)
   * hits that constraint (P2002) — return the winning row instead of
   * surfacing a raw 500 or creating a duplicate bid.
   */
  async createBid(data: {
    bookingId: string;
    workerProfileId: string;
    amount: number;
    message?: string;
  }): Promise<BidWithRelations> {
    try {
      const bid = await this.prisma.bid.create({
        data: {
          bookingId: data.bookingId,
          workerProfileId: data.workerProfileId,
          amount: data.amount,
          message: data.message ?? null,
          status: BidStatus.PENDING,
        },
      });
      return await this.prisma.bid.findUniqueOrThrow({
        where: { id: bid.id },
        include: BID_INCLUDE,
      });
    } catch (err) {
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2002'
      ) {
        const existing = await this.prisma.bid.findUnique({
          where: {
            bookingId_workerProfileId: {
              bookingId: data.bookingId,
              workerProfileId: data.workerProfileId,
            },
          },
          include: BID_INCLUDE,
        });
        if (existing) return existing;
      }
      throw err;
    }
  }

  async updateBid(
    bidId: string,
    data: { amount: number; message?: string },
  ): Promise<BidWithRelations> {
    await this.prisma.bid.update({
      where: { id: bidId },
      data: {
        amount: data.amount,
        message: data.message ?? null,
        editCount: { increment: 1 },
      },
    });
    return this.prisma.bid.findUniqueOrThrow({
      where: { id: bidId },
      include: BID_INCLUDE,
    });
  }

  /** Update bid amount/message in-place, resetting the cooldown window (updatedAt). */
  async updateBidAmountAndMessage(
    bidId: string,
    amount: number,
    message?: string,
  ) {
    await this.prisma.bid.update({
      where: { id: bidId },
      data: { amount, message: message ?? null },
    });
    return this.prisma.bid.findUniqueOrThrow({
      where: { id: bidId },
      include: BID_INCLUDE,
    });
  }

  /** Find all bids for a booking, sorted by createdAt descending (newest first — live feed). */
  async findBidsByBookingIdNewestFirst(bookingId: string) {
    return this.prisma.bid.findMany({
      where: { bookingId },
      orderBy: { createdAt: 'desc' },
      include: {
        workerProfile: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            avatarUrl: true,
            rating: true,
            totalRatings: true,
            currentLat: true,
            currentLng: true,
            locationUpdatedAt: true,
            bookings: {
              where: { status: BookingStatus.COMPLETED },
              select: { id: true },
            },
          },
        },
      },
    });
  }

  /** Find all bids for a booking, sorted by amount ascending. */
  async findBidsByBookingId(bookingId: string) {
    return this.prisma.bid.findMany({
      where: { bookingId },
      orderBy: { amount: 'asc' },
      include: {
        workerProfile: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            avatarUrl: true,
            rating: true,
            totalRatings: true,
            currentLat: true,
            currentLng: true,
            locationUpdatedAt: true,
            bookings: {
              where: { status: BookingStatus.COMPLETED },
              select: { id: true },
            },
          },
        },
      },
    });
  }

  /** Find a specific bid by id + bookingId (for my-bid lookup). */
  async findMyBidOnBooking(
    bookingId: string,
    workerProfileId: string,
  ): Promise<BidWithRelations | null> {
    return this.prisma.bid.findUnique({
      where: { bookingId_workerProfileId: { bookingId, workerProfileId } },
      include: BID_INCLUDE,
    });
  }

  /**
   * Accept a bid: set it to ACCEPTED, reject all others on the same booking,
   * then assign the worker to the booking and transition it to ACCEPTED status.
   * All in one transaction.
   */
  async acceptBid(
    bidId: string,
    bookingId: string,
    workerProfileId: string,
    finalPrice: number,
    platformFee: number,
  ) {
    return this.prisma.$transaction(async (tx) => {
      // Assign worker and transition booking to ACCEPTED FIRST — this atomic
      // gate (conditional on workerProfileId still being null AND status
      // still PENDING) is what actually decides whether this accept "wins".
      // Doing it before touching the bid rows means a losing request never
      // mutates bid status at all, so a retry that loses this race leaves
      // every bid exactly as the winning request left it.
      //
      // finalPrice/platformFee are set here (mirroring assignWorkerToBooking's
      // STANDARD/INSPECTION behavior) so completion and worker earnings read
      // the accepted bid amount instead of staying null.
      const bookingRes = await tx.booking.updateMany({
        where: {
          id: bookingId,
          workerProfileId: null,
          status: BookingStatus.PENDING,
        },
        data: {
          workerProfileId,
          status: BookingStatus.ACCEPTED,
          acceptedAt: new Date(),
          finalPrice,
          platformFee,
        },
      });

      const bookingInclude = {
        category: { select: { name: true } },
        clientProfile: { select: { userId: true } },
        workerProfile: {
          select: { userId: true, firstName: true, lastName: true },
        },
      } as const;

      if (bookingRes.count === 0) {
        const booking = await tx.booking.findUniqueOrThrow({
          where: { id: bookingId },
          include: bookingInclude,
        });
        return { booking, changed: false };
      }

      // Accept the chosen bid
      await tx.bid.update({
        where: { id: bidId },
        data: { status: BidStatus.ACCEPTED },
      });

      // Reject all other bids on this booking
      await tx.bid.updateMany({
        where: { bookingId, id: { not: bidId } },
        data: { status: BidStatus.REJECTED },
      });

      const booking = await tx.booking.findUniqueOrThrow({
        where: { id: bookingId },
        include: bookingInclude,
      });

      // Record status history
      await tx.bookingStatusHistory.create({
        data: {
          bookingId,
          status: BookingStatus.ACCEPTED,
          note: 'Bid accepted by client',
        },
      });

      // Mark worker as busy so they don't appear in new searches or new-jobs
      // feed — conditional on the worker still being genuinely assignable so
      // two concurrent bid-accepts (or an assignWorker + acceptBid race)
      // can't both win. Worker eligibility (status/onboarding/profile) was
      // only checked at bid-creation time and may be stale by now, so it's
      // re-verified here as the final authoritative gate.
      const res = await tx.workerProfile.updateMany({
        where: {
          id: workerProfileId,
          currentlyWorking: false,
          status: 'ACTIVE',
          onboardingStatus: 'APPROVED',
          availabilityStatus: 'ONLINE',
          profileCompleted: true,
        },
        data: { currentlyWorking: true },
      });
      if (res.count === 0) throw new WorkerUnavailableError();

      return { booking, changed: true };
    });
  }

  /**
   * Find PENDING bookings that match the worker's skills.
   * Includes all jobs regardless of whether the worker already bid.
   * Returns `myBid` so callers can compute `hasMyBid`.
   */
  async findAvailableJobsForWorker(
    workerProfileId: string,
    categoryIds: string[],
    /**
     * The worker's location + match radius. When supplied, a lat/lng bounding
     * box is applied in SQL — a strict SUPERSET of the radius circle, so the
     * caller's authoritative `isEligibleForJob` (precise Haversine) decides
     * exactly as before; it just no longer has to load every open job in the
     * country to throw most of them away.
     *
     * NOTE: this is marketplace browsing. No availabilityStatus filter is
     * added here and none must be — a manually OFFLINE Worker still browses
     * and bids (see JobEligibilityOptions.requireLivePresence).
     */
    geo?: { lat?: number | null; lng?: number | null; radiusKm?: number },
  ) {
    // DB-level discovery-window filter — see JOB_DISCOVERY_WINDOW_MS. The
    // authoritative check still happens in checkJobEligibility (which the
    // caller applies to every row below), but excluding stale rows here
    // keeps the query itself from growing unbounded with ancient still-open
    // bookings.
    const discoveryCutoff = new Date(Date.now() - JOB_DISCOVERY_WINDOW_MS);
    const geoFilter =
      geo?.lat != null && geo.lng != null && geo.radiusKm != null
        ? boundingBoxWhere(
            boundingBoxKm(geo.lat, geo.lng, geo.radiusKm),
            'latitude',
            'longitude',
          )
        : null;
    return this.prisma.booking.findMany({
      where: {
        status: BookingStatus.PENDING,
        // Already hired — must never surface, even in the window before the
        // status catches up.
        workerProfileId: null,
        categoryId: { in: categoryIds },
        createdAt: { gte: discoveryCutoff },
        // A worker who cancelled (or was otherwise excluded from) a STANDARD
        // booking must never see it again in their own feed, even after relist.
        workerExclusions: { none: { workerProfileId } },
        // Wrapped in AND so the box's antimeridian `OR` cannot collide with
        // any other OR on this where object.
        ...(geoFilter ? { AND: [geoFilter] } : {}),
      },
      orderBy: { createdAt: 'desc' },
      include: {
        category: { select: { id: true, name: true, iconUrl: true } },
        clientProfile: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            avatarUrl: true,
          },
        },
        standardServiceItems: {
          select: {
            id: true,
            standardServiceId: true,
            nameSnapshot: true,
            priceSnapshot: true,
            quantity: true,
          },
        },
        _count: { select: { bids: true } },
        bids: {
          where: { workerProfileId },
          select: { id: true, updatedAt: true },
          take: 1,
        },
        inspectionReport: {
          select: { decisionStatus: true, workerProfileId: true },
        },
        // See findBookingById — identifies linked post-inspection repair
        // jobs and their original inspector for feed-level eligibility.
        sourceInspectionBooking: {
          select: {
            inspectionReport: {
              select: { decisionStatus: true, workerProfileId: true },
            },
          },
        },
      },
    });
  }

  async countCompletedJobsByWorkerProfileId(
    workerProfileId: string,
  ): Promise<number> {
    // Shared helper — single source of truth, see worker-stats.util.ts
    return computeCompletedJobs(this.prisma, workerProfileId);
  }
}
