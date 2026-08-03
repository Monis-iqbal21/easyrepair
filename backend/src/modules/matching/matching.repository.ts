import { Injectable } from '@nestjs/common';
import { AvailabilityStatus, BookingStatus, WorkerStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { LOCATION_FRESHNESS_MS } from '../../common/utils/job-eligibility.util';

/**
 * All Prisma access for job↔worker matching. Kept here (rather than reaching
 * into BookingsRepository/WorkersRepository) so MatchingModule stays a leaf
 * with no dependency on the feature modules that consume it.
 */

/** Everything the central matcher and the broadcast copy need about a job. */
export const MATCHING_BOOKING_SELECT = {
  id: true,
  status: true,
  lane: true,
  categoryId: true,
  latitude: true,
  longitude: true,
  workerProfileId: true,
  /** Marks the current live/searching cycle — resets on relist/reopen. */
  liveStartedAt: true,
  sourceInspectionBookingId: true,
  clientProfile: { select: { userId: true } },
  workerExclusions: { select: { workerProfileId: true } },
  inspectionReport: {
    select: { decisionStatus: true, workerProfileId: true },
  },
  sourceInspectionBooking: {
    select: {
      inspectionReport: {
        select: { decisionStatus: true, workerProfileId: true },
      },
    },
  },
} as const;

/** Everything the central matcher needs about a worker, plus their userId. */
export const MATCHING_WORKER_SELECT = {
  id: true,
  userId: true,
  status: true,
  onboardingStatus: true,
  profileCompleted: true,
  availabilityStatus: true,
  currentlyWorking: true,
  currentLat: true,
  currentLng: true,
  locationUpdatedAt: true,
  skills: { select: { categoryId: true } },
} as const;

export type MatchingBooking = Awaited<
  ReturnType<MatchingRepository['findBookingForMatching']>
>;
export type MatchingWorker = Awaited<
  ReturnType<MatchingRepository['findWorkerForMatching']>
>;

@Injectable()
export class MatchingRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** Fresh read of a booking — re-run before every push (hire race guard). */
  async findBookingForMatching(bookingId: string) {
    return this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: MATCHING_BOOKING_SELECT,
    });
  }

  /** Fresh read of a worker — re-run before every push (they may have moved). */
  async findWorkerForMatching(workerProfileId: string) {
    return this.prisma.workerProfile.findUnique({
      where: { id: workerProfileId },
      select: MATCHING_WORKER_SELECT,
    });
  }

  /**
   * COARSE candidate filter only. Distance is deliberately NOT applied here —
   * the authoritative decision is always `isEligibleForJob` in the service,
   * so broadcast and New Jobs visibility cannot diverge.
   */
  async findCandidateWorkers(params: {
    categoryId: string;
    excludedWorkerIds?: string[];
  }) {
    const freshThreshold = new Date(Date.now() - LOCATION_FRESHNESS_MS);
    return this.prisma.workerProfile.findMany({
      where: {
        status: WorkerStatus.ACTIVE,
        onboardingStatus: 'APPROVED',
        profileCompleted: true,
        availabilityStatus: AvailabilityStatus.ONLINE,
        currentlyWorking: false,
        currentLat: { not: null },
        currentLng: { not: null },
        locationUpdatedAt: { gte: freshThreshold },
        skills: { some: { categoryId: params.categoryId } },
        ...(params.excludedWorkerIds?.length
          ? { id: { notIn: params.excludedWorkerIds } }
          : {}),
      },
      select: MATCHING_WORKER_SELECT,
    });
  }

  /**
   * Open, unassigned jobs in any of the worker's skill categories — the
   * candidate set for late discovery. Distance is applied by the caller via
   * the central matcher.
   */
  async findOpenBookingsForCategories(
    categoryIds: string[],
    workerProfileId: string,
  ) {
    if (categoryIds.length === 0) return [];
    return this.prisma.booking.findMany({
      where: {
        status: BookingStatus.PENDING,
        workerProfileId: null,
        categoryId: { in: categoryIds },
        workerExclusions: { none: { workerProfileId } },
      },
      orderBy: { createdAt: 'desc' },
      select: MATCHING_BOOKING_SELECT,
    });
  }

  /** Client userId for completion notifications. */
  async findBookingForCompletionNotice(bookingId: string) {
    return this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: {
        id: true,
        status: true,
        clientProfile: { select: { userId: true } },
      },
    });
  }
}
