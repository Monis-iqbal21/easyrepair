import { Injectable } from '@nestjs/common';
import { AvailabilityStatus, BookingStatus, WorkerStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  JOB_DISCOVERY_WINDOW_MS,
  LOCATION_FRESHNESS_MS,
  WORKER_PRESENCE_STALE_MS,
} from '../../common/utils/job-eligibility.util';
import { boundingBoxKm, boundingBoxWhere } from '../../common/utils/geo.util';

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
  createdAt: true,
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
  lastSeenAt: true,
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
   * COARSE candidate filter. Distance is now pre-filtered in SQL via a
   * lat/lng BOUNDING BOX, which is a strict SUPERSET of the radius circle —
   * it can only ever remove workers that the precise Haversine check would
   * have rejected anyway. The authoritative decision is still always
   * `isEligibleForJob` in the service, so broadcast and New Jobs visibility
   * cannot diverge; the box exists purely so the database stops handing Node
   * every online worker in the country for a 7 km job.
   *
   * [lat]/[lng]/[radiusKm] are optional: omitting them reproduces the previous
   * unbounded behaviour exactly, so callers without a job location are safe.
   */
  async findCandidateWorkers(params: {
    categoryId: string;
    lat?: number | null;
    lng?: number | null;
    radiusKm?: number;
    excludedWorkerIds?: string[];
  }) {
    const freshThreshold = new Date(Date.now() - LOCATION_FRESHNESS_MS);
    const presenceThreshold = new Date(Date.now() - WORKER_PRESENCE_STALE_MS);
    const geoFilter =
      params.lat != null && params.lng != null && params.radiusKm != null
        ? boundingBoxWhere(
            boundingBoxKm(params.lat, params.lng, params.radiusKm),
            'currentLat',
            'currentLng',
          )
        : null;
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
        lastSeenAt: { gte: presenceThreshold },
        skills: { some: { categoryId: params.categoryId } },
        ...(params.excludedWorkerIds?.length
          ? { id: { notIn: params.excludedWorkerIds } }
          : {}),
        // Wrapped in AND so the bounding box's own antimeridian `OR` can
        // never collide with another OR on this where object.
        ...(geoFilter ? { AND: [geoFilter] } : {}),
      },
      select: MATCHING_WORKER_SELECT,
    });
  }

  /**
   * Batched pre-push recheck. Same projection and therefore the same
   * authority as `findWorkerForMatching`, just for a whole chunk of
   * recipients in one round trip instead of one query per recipient.
   *
   * This is a re-read, NOT a cache: the broadcast fan-out calls it
   * immediately before pushing to each chunk, so a worker who went offline,
   * became busy, went stale or moved is still caught. Correctness is
   * unchanged; only the query count is.
   */
  async findWorkersForMatching(workerProfileIds: string[]) {
    if (workerProfileIds.length === 0) return [];
    return this.prisma.workerProfile.findMany({
      where: { id: { in: workerProfileIds } },
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
    /** The worker's own position — same bounding-box superset rule as
     *  findCandidateWorkers, applied from the job side this time. Omitting it
     *  reproduces the previous unbounded behaviour exactly. */
    geo?: { lat?: number | null; lng?: number | null; radiusKm?: number },
  ) {
    if (categoryIds.length === 0) return [];
    // Same discovery-window cutoff as the New Jobs feed — see
    // JOB_DISCOVERY_WINDOW_MS. Late-discovery push must never resurface a
    // job that has already aged out of the marketplace.
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
        workerProfileId: null,
        categoryId: { in: categoryIds },
        createdAt: { gte: discoveryCutoff },
        workerExclusions: { none: { workerProfileId } },
        ...(geoFilter ? { AND: [geoFilter] } : {}),
      },
      orderBy: { createdAt: 'desc' },
      select: MATCHING_BOOKING_SELECT,
    });
  }

  /**
   * Batched hire-race guard: re-reads a chunk of bookings in one round trip.
   * Same projection/authority as `findBookingForMatching`, so a job hired,
   * cancelled or expired mid-fan-out is still caught before any push.
   */
  async findBookingsForMatching(bookingIds: string[]) {
    if (bookingIds.length === 0) return [];
    return this.prisma.booking.findMany({
      where: { id: { in: bookingIds } },
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
