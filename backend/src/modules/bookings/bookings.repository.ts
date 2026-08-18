import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  AttachmentType,
  AvailabilityStatus,
  BidStatus,
  BookingLane,
  BookingUrgency,
  BookingStatus,
  TimeSlot,
  UrgentWindow,
  Prisma,
  WorkerStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { WORKER_PRESENCE_STALE_MS } from '../../common/utils/job-eligibility.util';
import { boundingBoxKm, boundingBoxWhere } from '../../common/utils/geo.util';
import { WorkerUnavailableError } from '../../common/errors/worker-unavailable.error';

// Raw row shape returned by the PostGIS nearby-workers query.
interface RawNearbyWorkerRow {
  id: string;
  firstName: string;
  lastName: string;
  avatarUrl: string | null;
  rating: number;
  distance_meters: number;
  skills: string[];
}

/**
 * One candidate in the nearby-worker pool, as produced by either geographic
 * path (PostGIS or Haversine + bounding box) before stats/ranking are added.
 */
interface NearbyWorkerRow {
  id: string;
  firstName: string;
  lastName: string;
  avatarUrl: string | null;
  rating: number;
  distanceMeters: number;
  skills: string[];
  completedJobs: number;
}

/**
 * Nearby-worker discovery constants. Centralised here (they used to be
 * duplicated as literals inside each of the two geographic paths, where they
 * could silently drift apart) — the values themselves are unchanged.
 */
/** Expansion stops as soon as this many unique workers have been found. */
const NEARBY_TARGET_POOL = 4;
/** STANDARD / INSPECTION: direct-assignment lanes, tighter pool. */
const NEARBY_STANDARD_LADDER_KM = [5, 7] as const;
/** BIDDING / everything else: the wider legacy ladder. */
const NEARBY_LEGACY_LADDER_KM = [3, 5, 8, 10, 15, 20] as const;
/**
 * Runaway guard on how many candidates one nearby search may pull back. The
 * query is ordered nearest-first, so this can only ever drop workers FARTHER
 * away than the ones kept, and only in a pool far larger than the client UI
 * (or the 4-worker target) could ever use. Configurable via
 * MATCH_NEARBY_FETCH_LIMIT.
 */
const DEFAULT_NEARBY_FETCH_LIMIT = 200;

/** Haversine great-circle distance in metres between two lat/lng points. */
function haversineMeters(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const R = 6_371_000; // Earth radius in metres
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ---------------------------------------------------------------------------
// Shared include clause — single source of truth for all booking queries.
// ---------------------------------------------------------------------------
export const BOOKING_INCLUDE = {
  category: {
    select: { name: true },
  },
  clientProfile: {
    select: { userId: true },
  },
  workerProfile: {
    select: {
      id: true,
      userId: true,
      firstName: true,
      lastName: true,
      avatarUrl: true,
      rating: true,
      currentLat: true,
      currentLng: true,
      user: { select: { phone: true } },
    },
  },
  bids: {
    where: { status: BidStatus.ACCEPTED },
    select: { amount: true },
    take: 1,
  },
  attachments: {
    select: {
      id: true,
      type: true,
      url: true,
      storageKey: true,
      fileName: true,
      mimeType: true,
      sizeBytes: true,
      durationSeconds: true,
      thumbnailUrl: true,
      createdAt: true,
    },
    orderBy: { createdAt: 'asc' as const },
  },
  review: {
    select: {
      id: true,
      rating: true,
      comment: true,
      createdAt: true,
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
    orderBy: { createdAt: 'asc' as const },
  },
  workerExclusions: {
    select: {
      id: true,
      workerProfileId: true,
      reason: true,
      createdAt: true,
      // Powers the client's "Previous Ustaad: [name]" cancellation strip —
      // BookingWorkerExclusion already has a workerProfile relation, so no
      // migration is needed to surface the name.
      workerProfile: { select: { firstName: true, lastName: true } },
    },
    orderBy: { createdAt: 'desc' as const },
  },
  inspectionReport: {
    select: {
      decisionStatus: true,
      createdAt: true,
      // Permanent record of who inspected — kept even after a different
      // worker is hired for the repair (Booking.workerProfileId changes,
      // this never does), so the client can show "Inspection completed by".
      workerProfile: {
        select: {
          id: true,
          firstName: true,
          lastName: true,
          avatarUrl: true,
          rating: true,
          currentLat: true,
          currentLng: true,
          user: { select: { phone: true } },
        },
      },
    },
  },
  // Linked repair booking spawned by "Find Other Ustaad" (if any) — lets the
  // original completed inspection's DTO point the client at the open repair.
  repairBooking: { select: { id: true } },
  // For a linked repair booking, the completed inspection it came from — the
  // report (and therefore the inspecting worker) always lives there.
  sourceInspectionBooking: {
    select: {
      id: true,
      // Required by deriveInspectionFeePaid: the fee's paid/not-paid status
      // is owned by the ORIGINAL inspection work unit, never by this repair.
      status: true,
      inspectionReport: {
        select: {
          decisionStatus: true,
          createdAt: true,
          workerProfile: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              avatarUrl: true,
              rating: true,
              currentLat: true,
              currentLng: true,
              user: { select: { phone: true } },
            },
          },
        },
      },
    },
  },
} satisfies Prisma.BookingInclude;

// Derive the exact return type from the include so every caller is
// fully typed without manual casting.
export type BookingWithRelations = Prisma.BookingGetPayload<{
  include: typeof BOOKING_INCLUDE;
}>;

/**
 * Outcome of the atomic "Find Other Ustaad" close-and-spawn transaction.
 * Non-CREATED outcomes are returned (not thrown) so the service layer maps
 * each one to the correct HTTP error / idempotent success response.
 */
export type CloseInspectionOutcome =
  | { outcome: 'CREATED'; childBooking: BookingWithRelations }
  /** A prior request already completed the transition — same child returned. */
  | { outcome: 'ALREADY_DONE'; childBooking: BookingWithRelations }
  /** Report was decided differently (ACCEPTED_REPAIR / CLOSED_AFTER_INSPECTION). */
  | { outcome: 'CONFLICTING_DECISION'; decisionStatus: string }
  /** decisionStatus is FIND_OTHER_USTAAD but no linked child exists (pre-fix
   *  historical record) — must never silently create a duplicate. */
  | { outcome: 'LINK_MISSING' }
  /** The original booking was not IN_PROGRESS/assigned-to-inspector/INSPECTION
   *  at commit time (e.g. concurrently cancelled) — everything rolled back. */
  | { outcome: 'BOOKING_STATE_CHANGED' };

/** Internal sentinel — rolls back closeInspectionAndOpenRepairBidding. */
class InspectionCloseStateError extends Error {}

// ---------------------------------------------------------------------------

@Injectable()
export class BookingsRepository {
  private readonly logger = new Logger(BookingsRepository.name);
  private readonly usePostgis: boolean;
  private readonly nearbyWorkerFetchLimit: number;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {
    this.usePostgis = this.config.get<boolean>('usePostgis') ?? false;
    this.nearbyWorkerFetchLimit =
      this.config.get<number>('matching.nearbyWorkerFetchLimit') ??
      DEFAULT_NEARBY_FETCH_LIMIT;
  }

  /** Find a ServiceCategory by its name (case-insensitive). */
  async findCategoryByName(name: string) {
    return this.prisma.serviceCategory.findFirst({
      where: { name: { equals: name, mode: 'insensitive' }, isActive: true },
    });
  }

  /** Find an active standard service, scoped to a category, for snapshotting at booking time. */
  async findStandardServiceById(id: string) {
    return this.prisma.standardService.findUnique({ where: { id } });
  }

  /** Find multiple standard services by id, for multi-select STANDARD bookings. */
  async findStandardServicesByIds(ids: string[]) {
    return this.prisma.standardService.findMany({
      where: { id: { in: ids } },
    });
  }

  /** Find the ClientProfile for a given userId. */
  async findClientProfileByUserId(userId: string) {
    return this.prisma.clientProfile.findUnique({ where: { userId } });
  }

  /**
   * Create a new booking and record the initial PENDING status history entry
   * in a single transaction.  The booking is re-fetched after the transaction
   * using the shared include so the return type is always BookingWithRelations.
   */
  async createBooking(data: {
    clientProfileId: string;
    categoryId: string;
    urgency: BookingUrgency;
    timeSlot?: TimeSlot;
    title?: string;
    description: string;
    addressLine: string;
    city: string;
    latitude: number;
    longitude: number;
    scheduledAt?: Date;
    inspection?: boolean;
    urgentWindow?: UrgentWindow;
    lane?: BookingLane;
    standardServiceId?: string;
    standardServiceNameSnapshot?: string;
    standardServicePriceSnapshot?: number;
    /** Multi-select STANDARD-lane items. First item also populates the
     *  legacy singular standardServiceId/snapshot fields for backward
     *  compatibility with older app builds. */
    standardServiceItems?: Array<{
      standardServiceId: string;
      nameSnapshot: string;
      priceSnapshot: number;
      quantity?: number;
    }>;
    inspectionFeeSnapshot?: number;
    estimatedPrice?: number;
    /** 72h auto-expiry window — set for all lanes on creation. */
    expiresAt?: Date;
    liveStartedAt?: Date;
    /** Client-generated dedup key for this creation attempt. See schema doc. */
    idempotencyKey?: string;
    /**
     * Optional read-only reference to a previously COMPLETED inspection
     * booking whose report the client attached to this new BIDDING job.
     * Purely informational — see the schema doc on
     * Booking.attachedInspectionBookingId for why this is deliberately NOT
     * sourceInspectionBookingId.
     */
    attachedInspectionBookingId?: string;
  }): Promise<BookingWithRelations> {
    let createdId: string;
    try {
      // Step 1 — transactional write (no include needed here).
      const created = await this.prisma.$transaction(async (tx) => {
        const booking = await tx.booking.create({
          data: {
            clientProfileId: data.clientProfileId,
            categoryId: data.categoryId,
            urgency: data.urgency,
            timeSlot: data.timeSlot ?? null,
            title: data.title ?? null,
            description: data.description,
            addressLine: data.addressLine,
            city: data.city,
            latitude: data.latitude,
            longitude: data.longitude,
            scheduledAt: data.scheduledAt ?? null,
            inspection: data.inspection ?? false,
            urgentWindow: data.urgentWindow ?? null,
            status: BookingStatus.PENDING,
            lane: data.lane ?? BookingLane.BIDDING,
            standardServiceId: data.standardServiceId ?? null,
            standardServiceNameSnapshot:
              data.standardServiceNameSnapshot ?? null,
            standardServicePriceSnapshot:
              data.standardServicePriceSnapshot ?? null,
            inspectionFeeSnapshot: data.inspectionFeeSnapshot ?? null,
            estimatedPrice: data.estimatedPrice ?? null,
            expiresAt: data.expiresAt ?? null,
            liveStartedAt: data.liveStartedAt ?? null,
            idempotencyKey: data.idempotencyKey ?? null,
            attachedInspectionBookingId:
              data.attachedInspectionBookingId ?? null,
          },
        });

        if (
          data.standardServiceItems &&
          data.standardServiceItems.length > 0
        ) {
          await tx.bookingStandardServiceItem.createMany({
            data: data.standardServiceItems.map((item) => ({
              bookingId: booking.id,
              standardServiceId: item.standardServiceId,
              nameSnapshot: item.nameSnapshot,
              priceSnapshot: item.priceSnapshot,
              quantity: item.quantity ?? 1,
            })),
          });
        }

        await tx.bookingStatusHistory.create({
          data: {
            bookingId: booking.id,
            status: BookingStatus.PENDING,
            note: 'Booking created',
          },
        });

        return booking;
      });
      createdId = created.id;
    } catch (err) {
      // A retried "Create Booking" submission (same idempotencyKey) racing
      // against itself hits the unique constraint — return the winning row
      // instead of surfacing a raw 500 or creating a duplicate booking.
      if (
        data.idempotencyKey &&
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2002'
      ) {
        const existing = await this.findBookingByIdempotencyKey(
          data.idempotencyKey,
        );
        if (existing) return existing;
      }
      throw err;
    }

    // Step 2 — re-fetch with full relations so the caller gets BookingWithRelations.
    return this.prisma.booking.findUniqueOrThrow({
      where: { id: createdId },
      include: BOOKING_INCLUDE,
    });
  }

  /** Look up a booking by its client-generated creation-attempt dedup key. */
  async findBookingByIdempotencyKey(
    idempotencyKey: string,
  ): Promise<BookingWithRelations | null> {
    return this.prisma.booking.findUnique({
      where: { idempotencyKey },
      include: BOOKING_INCLUDE,
    });
  }

  /** Fetch all bookings for a client, newest first. */
  async findBookingsByClientProfileId(
    clientProfileId: string,
  ): Promise<BookingWithRelations[]> {
    return this.prisma.booking.findMany({
      where: { clientProfileId },
      orderBy: { createdAt: 'desc' },
      include: BOOKING_INCLUDE,
    });
  }

  /**
   * Completed bookings this client still owes a review for — the backend
   * source of truth behind GET /bookings/pending-reviews. A booking leaves
   * this list only once its Review row exists, which is what lets the app
   * keep re-offering a postponed or failed review without ever duplicating
   * one. `workerProfileId: not null` mirrors submitReview's own guard: a
   * booking with no assigned Ustaad has nobody to review.
   */
  async findPendingReviewBookingsByClientProfileId(
    clientProfileId: string,
  ): Promise<BookingWithRelations[]> {
    return this.prisma.booking.findMany({
      where: {
        clientProfileId,
        status: BookingStatus.COMPLETED,
        workerProfileId: { not: null },
        review: { is: null },
      },
      orderBy: { completedAt: 'desc' },
      include: BOOKING_INCLUDE,
    });
  }

  /** Find a single booking by id (returns null when not found). */
  async findBookingById(id: string): Promise<BookingWithRelations | null> {
    return this.prisma.booking.findUnique({
      where: { id },
      include: BOOKING_INCLUDE,
    });
  }

  /**
   * Whether a worker has ever placed a bid on this booking — the eligible-
   * worker signal for BIDDING lane (and reopened "Find Other Ustaad"
   * INSPECTION jobs), where eligibility isn't a nearby-radius match but
   * self-selection via bidding. Any status counts (PENDING/ACCEPTED/
   * REJECTED) since chat eligibility shouldn't disappear just because a bid
   * was later rejected in favour of someone else.
   */
  async hasBidFromWorker(
    bookingId: string,
    workerProfileId: string,
  ): Promise<boolean> {
    const bid = await this.prisma.bid.findUnique({
      where: { bookingId_workerProfileId: { bookingId, workerProfileId } },
      select: { id: true },
    });
    return bid !== null;
  }

  /**
   * Update editable fields on a PENDING booking that has no assigned worker.
   */
  async updateBooking(
    bookingId: string,
    data: {
      categoryId?: string;
      title?: string | null;
      description?: string;
      urgency?: BookingUrgency;
      timeSlot?: TimeSlot | null;
      scheduledAt?: Date | null;
      addressLine?: string;
      city?: string;
      latitude?: number;
      longitude?: number;
      inspection?: boolean;
      urgentWindow?: UrgentWindow | null;
      standardServiceId?: string;
      standardServiceNameSnapshot?: string;
      standardServicePriceSnapshot?: number;
      /** When provided, fully replaces this booking's STANDARD-lane sub-service rows. */
      standardServiceItems?: Array<{
        standardServiceId: string;
        nameSnapshot: string;
        priceSnapshot: number;
        quantity?: number;
      }>;
      estimatedPrice?: number;
    },
  ): Promise<BookingWithRelations> {
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: {
          ...(data.categoryId !== undefined && { categoryId: data.categoryId }),
          ...(data.title !== undefined && { title: data.title }),
          ...(data.description !== undefined && {
            description: data.description,
          }),
          ...(data.urgency !== undefined && { urgency: data.urgency }),
          ...(data.timeSlot !== undefined && { timeSlot: data.timeSlot }),
          ...(data.scheduledAt !== undefined && {
            scheduledAt: data.scheduledAt,
          }),
          ...(data.addressLine !== undefined && {
            addressLine: data.addressLine,
          }),
          ...(data.city !== undefined && { city: data.city }),
          ...(data.latitude !== undefined && { latitude: data.latitude }),
          ...(data.longitude !== undefined && { longitude: data.longitude }),
          ...(data.inspection !== undefined && { inspection: data.inspection }),
          ...(data.urgentWindow !== undefined && {
            urgentWindow: data.urgentWindow,
          }),
          ...(data.standardServiceId !== undefined && {
            standardServiceId: data.standardServiceId,
          }),
          ...(data.standardServiceNameSnapshot !== undefined && {
            standardServiceNameSnapshot: data.standardServiceNameSnapshot,
          }),
          ...(data.standardServicePriceSnapshot !== undefined && {
            standardServicePriceSnapshot: data.standardServicePriceSnapshot,
          }),
          ...(data.estimatedPrice !== undefined && {
            estimatedPrice: data.estimatedPrice,
          }),
        },
      });

      if (data.standardServiceItems) {
        await tx.bookingStandardServiceItem.deleteMany({
          where: { bookingId },
        });
        await tx.bookingStandardServiceItem.createMany({
          data: data.standardServiceItems.map((item) => ({
            bookingId,
            standardServiceId: item.standardServiceId,
            nameSnapshot: item.nameSnapshot,
            priceSnapshot: item.priceSnapshot,
            quantity: item.quantity ?? 1,
          })),
        });
      }
    });

    return this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: BOOKING_INCLUDE,
    });
  }

  // ── Attachment methods ──────────────────────────────────────────────────────

  /** Create an attachment record for a booking. */
  async createAttachment(data: {
    bookingId: string;
    type: AttachmentType;
    url: string;
    storageKey?: string;
    fileName?: string;
    mimeType?: string;
    sizeBytes?: number;
    durationSeconds?: number;
    thumbnailUrl?: string;
  }) {
    return this.prisma.bookingAttachment.create({ data });
  }

  /** Find an attachment by id. */
  async findAttachmentById(id: string) {
    return this.prisma.bookingAttachment.findUnique({ where: { id } });
  }

  /** Delete an attachment record. */
  async deleteAttachment(id: string) {
    return this.prisma.bookingAttachment.delete({ where: { id } });
  }

  // ── Review / cancel ─────────────────────────────────────────────────────────

  /**
   * Create a review for a completed booking and update the worker's running
   * average rating + totalRatings in the same transaction.
   *
   * Running-average formula (no full re-scan needed):
   *   newAvg = round(((oldAvg * oldCount) + newRating) / (oldCount + 1), 1)
   */
  async createReview(
    bookingId: string,
    data: { rating: number; comment?: string; workerProfileId: string },
  ): Promise<BookingWithRelations> {
    try {
      await this.prisma.$transaction(async (tx) => {
        // 1. Persist the review.
        await tx.review.create({
          data: {
            bookingId,
            rating: data.rating,
            comment: data.comment ?? null,
          },
        });

        // 2. Read current worker stats inside the transaction for consistency.
        const worker = await tx.workerProfile.findUniqueOrThrow({
          where: { id: data.workerProfileId },
          select: { rating: true, totalRatings: true },
        });

        const oldCount = worker.totalRatings;
        const oldAvg = worker.rating;
        const newCount = oldCount + 1;
        const newAvg =
          Math.round(((oldAvg * oldCount + data.rating) / newCount) * 10) /
          10;

        // 3. Write updated stats.
        await tx.workerProfile.update({
          where: { id: data.workerProfileId },
          data: {
            rating: newAvg,
            totalRatings: newCount,
          },
        });
      });
    } catch (err) {
      // `Review.bookingId @unique` backs "one review per booking". A
      // genuine concurrent double-submit (the caller's own pre-check raced
      // another request creating the row first) hits that constraint
      // (P2002) — the whole transaction (including the rating recompute)
      // rolls back automatically, so it's safe to just return the winning
      // booking instead of surfacing a raw 500 or double-counting the rating.
      if (
        !(
          err instanceof Prisma.PrismaClientKnownRequestError &&
          err.code === 'P2002'
        )
      ) {
        throw err;
      }
    }

    return this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: BOOKING_INCLUDE,
    });
  }

  /**
   * Transition a booking to CANCELLED and record the history entry.
   * If the booking had an assigned worker, resets their currentlyWorking flag
   * so they become available for new jobs again.
   *
   * The status flip is an atomic `updateMany` guarded by `fromStatuses`, so
   * two concurrent cancel requests (double-tap, a retry racing the original)
   * can never both "win" — only the request that actually flips the status
   * writes the history row and releases the worker. The loser gets
   * `changed: false`; the caller decides whether that's a safe idempotent
   * no-op or a genuine conflict by inspecting the re-fetched booking status.
   */
  async cancelBooking(
    bookingId: string,
    fromStatuses: BookingStatus[],
    reason?: string,
    workerProfileId?: string | null,
    cancelledByRole: 'CLIENT' | 'WORKER' = 'CLIENT',
  ): Promise<{ booking: BookingWithRelations; changed: boolean }> {
    const note = reason ?? 'Cancelled by client';

    const changed = await this.prisma.$transaction(async (tx) => {
      const { count } = await tx.booking.updateMany({
        where: { id: bookingId, status: { in: fromStatuses } },
        data: {
          status: BookingStatus.CANCELLED,
          cancelledAt: new Date(),
          cancellationReason: note,
          cancelledByRole,
        },
      });

      if (count === 0) return false;

      await tx.bookingStatusHistory.create({
        data: {
          bookingId,
          status: BookingStatus.CANCELLED,
          note,
        },
      });

      // Free the worker — they are no longer on an active job.
      if (workerProfileId) {
        await tx.workerProfile.update({
          where: { id: workerProfileId },
          data: { currentlyWorking: false },
        });
      }

      return true;
    });

    const booking = await this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: BOOKING_INCLUDE,
    });
    return { booking, changed };
  }

  // ── Nearby workers ───────────────────────────────────────────────────────────

  /**
   * Find a worker profile by id for availability validation before assignment.
   */
  /**
   * Minimal projection used to validate an `attachedInspectionBookingId`
   * supplied at booking-creation time. Deliberately NOT filtered by client
   * here — BookingsService compares ownership itself so "doesn't exist" and
   * "belongs to someone else" can be answered identically (no id probing).
   *
   * Read-only: nothing in the attach flow ever writes to the historical
   * inspection booking or its report.
   */
  async findInspectionForAttachment(bookingId: string) {
    return this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: {
        id: true,
        lane: true,
        status: true,
        categoryId: true,
        clientProfileId: true,
        inspectionReport: { select: { id: true, decisionStatus: true } },
      },
    });
  }

  async findWorkerProfileById(workerProfileId: string) {
    return this.prisma.workerProfile.findUnique({
      where: { id: workerProfileId },
      select: {
        id: true,
        userId: true,
        availabilityStatus: true,
        profileCompleted: true,
        currentlyWorking: true,
        status: true,
        onboardingStatus: true,
        lastSeenAt: true,
      },
    });
  }

  /** Find a worker profile by userId — used to authorize lifecycle endpoints. */
  async findWorkerProfileByUserId(userId: string) {
    return this.prisma.workerProfile.findUnique({
      where: { userId },
      select: { id: true, userId: true },
    });
  }

  /** Batch-resolve workerProfileId -> userId for notification fan-out. */
  async findUserIdsByWorkerProfileIds(
    workerProfileIds: string[],
  ): Promise<Map<string, string>> {
    if (workerProfileIds.length === 0) return new Map();
    const rows = await this.prisma.workerProfile.findMany({
      where: { id: { in: workerProfileIds } },
      select: { id: true, userId: true },
    });
    return new Map(rows.map((r) => [r.id, r.userId]));
  }

  /**
   * Find nearby available workers for a booking.
   *
   * Routing:
   *   - USE_POSTGIS=true  → PostGIS raw SQL (accurate spherical distance).
   *   - USE_POSTGIS=false → Prisma fetch + Haversine in TypeScript (Railway-safe).
   *
   * Both paths apply the same eligibility filters and return the same shape.
   *
   * Radius ladder:
   *   - STANDARD lane: 5 → 7 km (per product spec — tighter pool for
   *     fixed-price catalog jobs).
   *   - INSPECTION/other: 3 → 5 → 8 → 10 → 15 → 20 km (unchanged legacy ladder).
   *   - A caller-supplied radiusKm searches only that single radius
   *     (frontend-driven expansion), regardless of lane.
   * Expansion stops as soon as TARGET_POOL (4) unique workers are found.
   *
   * excludedWorkerIds (from BookingWorkerExclusion) are always filtered out —
   * workers who previously cancelled this specific booking never reappear in
   * its nearby-worker pool, even across relist.
   */
  async findNearbyWorkers(params: {
    categoryId: string;
    lat: number;
    lng: number;
    /** When provided, only this single radius is searched (frontend-driven expansion).
     *  When omitted the full ladder runs server-side (backward compat). */
    radiusKm?: number;
    /** STANDARD lane uses the tighter 5-7km ladder; other lanes keep the legacy ladder. */
    lane?: BookingLane;
    /** Worker profile ids to exclude (e.g. previously cancelled this booking). */
    excludedWorkerIds?: string[];
  }): Promise<{
    workers: Array<{
      id: string;
      firstName: string;
      lastName: string;
      avatarUrl: string | null;
      rating: number;
      completedJobs: number;
      reviewsCount: number;
      cancellationRate: number;
      distanceMeters: number;
      skills: string[];
      recommended: boolean;
    }>;
    searchedRadiusKm: number;
    searchCompleted: boolean;
  }> {
    const result = await this._searchNearbyWorkers(params);
    const withStats = await this._attachWorkerStats(result.workers);

    // Rank: rating desc, completedJobs desc, cancellationRate asc, distance asc.
    // Top 1-3 (scaled to pool size) get recommended = true.
    const ranked = [...withStats].sort((a, b) => {
      if (b.rating !== a.rating) return b.rating - a.rating;
      if (b.completedJobs !== a.completedJobs)
        return b.completedJobs - a.completedJobs;
      if (a.cancellationRate !== b.cancellationRate)
        return a.cancellationRate - b.cancellationRate;
      return a.distanceMeters - b.distanceMeters;
    });
    const recommendedCount =
      ranked.length >= 6
        ? 3
        : ranked.length >= 3
          ? 2
          : ranked.length >= 1
            ? 1
            : 0;
    const recommendedIds = new Set(
      ranked.slice(0, recommendedCount).map((w) => w.id),
    );

    // Preserve the original distance-first ordering for display; only the
    // recommended flag comes from the separate ranking above.
    const workers = withStats.map((w) => ({
      ...w,
      recommended: recommendedIds.has(w.id),
    }));

    return { ...result, workers };
  }

  /**
   * Membership test only: "is this worker in the nearby pool for this job?"
   *
   * Same search, same eligibility, same ladder - but it skips the per-worker
   * review/cancellation stats and the recommendation ranking, none of which a
   * yes/no permission check (see BookingsService.assertClientCanChatWithWorker)
   * ever looked at.
   */
  async findNearbyWorkerIds(params: {
    categoryId: string;
    lat: number;
    lng: number;
    radiusKm?: number;
    lane?: BookingLane;
    excludedWorkerIds?: string[];
  }): Promise<Set<string>> {
    const { workers } = await this._searchNearbyWorkers(params);
    return new Set(workers.map((w) => w.id));
  }

  // -- The one nearby-worker search -----------------------------------------

  /**
   * The radius ladder, unchanged:
   *   - STANDARD / INSPECTION (direct-assignment lanes): 5 -> 7 km.
   *   - BIDDING / other:                                 3 -> 5 -> 8 -> 10 -> 15 -> 20 km.
   *   - A caller-supplied radiusKm searches only that single radius
   *     (frontend-driven expansion), regardless of lane.
   */
  private _radiusLadderKm(params: {
    radiusKm?: number;
    lane?: BookingLane;
  }): number[] {
    if (params.radiusKm !== undefined) return [params.radiusKm];
    return params.lane === BookingLane.STANDARD ||
      params.lane === BookingLane.INSPECTION
      ? [...NEARBY_STANDARD_LADDER_KM]
      : [...NEARBY_LEGACY_LADDER_KM];
  }

  /**
   * ONE bounded database query, then the ladder is resolved in memory.
   *
   * BEFORE: the ladder ran in the database - up to six sequential queries,
   * each re-scanning the same worker population at a wider radius, and on the
   * PostGIS path each one built its geography inline (ST_MakePoint(...)), an
   * expression no index can serve.
   *
   * AFTER: a single query to the WIDEST rung, ordered nearest-first and
   * capped, then the rungs are applied to that already-sorted set. The result
   * is IDENTICAL by construction - the old loop returned every worker inside
   * the first rung whose cumulative count reached the target pool, which is
   * exactly what picking that rung out of a distance-sorted list produces -
   * and searchedRadiusKm / searchCompleted are derived the same way.
   *
   * Expansion still stops at the first rung that satisfies the target pool,
   * and the maximum radius is still the last rung; nothing about the business
   * behaviour moved.
   */
  private async _searchNearbyWorkers(params: {
    categoryId: string;
    lat: number;
    lng: number;
    radiusKm?: number;
    lane?: BookingLane;
    excludedWorkerIds?: string[];
  }): Promise<{
    workers: NearbyWorkerRow[];
    searchedRadiusKm: number;
    searchCompleted: boolean;
  }> {
    const ladderKm = this._radiusLadderKm(params);
    const maxRadiusKm = ladderKm[ladderKm.length - 1];

    const rows = this.usePostgis
      ? await this._queryNearbyWorkersPostgis({ ...params, maxRadiusKm })
      : await this._queryNearbyWorkersHaversine({ ...params, maxRadiusKm });

    // Nearest first, rating as the tiebreak - the same ordering the ladder
    // loop produced, and the order the ladder resolution below relies on.
    rows.sort((a, b) =>
      a.distanceMeters !== b.distanceMeters
        ? a.distanceMeters - b.distanceMeters
        : b.rating - a.rating,
    );

    let searchedRadiusKm = maxRadiusKm;
    let workers = rows;
    for (const rungKm of ladderKm) {
      const within = rows.filter((w) => w.distanceMeters <= rungKm * 1000);
      searchedRadiusKm = rungKm;
      workers = within;
      if (within.length >= NEARBY_TARGET_POOL) break;
    }

    return {
      workers,
      searchedRadiusKm,
      searchCompleted: workers.length >= NEARBY_TARGET_POOL,
    };
  }

  // -- PostGIS implementation ------------------------------------------------

  /**
   * Radius filtering via the GIST-indexed worker_profiles.location generated
   * column (see the 20260818000100_worker_location_geography migration). The
   * previous query built the geography per row inline, which forced a
   * sequential scan on every rung; ST_DWithin against a real indexed column
   * is the whole point of using PostGIS.
   *
   * If the column is missing (USE_POSTGIS=true but the migration has not been
   * applied yet) this degrades to the Haversine + bounding-box path rather
   * than failing the request.
   */
  private async _queryNearbyWorkersPostgis(params: {
    categoryId: string;
    lat: number;
    lng: number;
    maxRadiusKm: number;
    excludedWorkerIds?: string[];
  }): Promise<NearbyWorkerRow[]> {
    const excludedIds = params.excludedWorkerIds ?? [];
    const presenceCutoff = new Date(Date.now() - WORKER_PRESENCE_STALE_MS);
    const radiusMeters = params.maxRadiusKm * 1000;

    let raw: RawNearbyWorkerRow[];
    try {
      raw = await this.prisma.$queryRaw<RawNearbyWorkerRow[]>`
        SELECT
          wp.id,
          wp."firstName",
          wp."lastName",
          wp."avatarUrl",
          wp.rating,
          ST_Distance(
            wp.location,
            ST_SetSRID(ST_MakePoint(${params.lng}::float8, ${params.lat}::float8), 4326)::geography
          )::float8 AS distance_meters,
          ARRAY(
            SELECT sc.name
            FROM worker_skills ws2
            JOIN service_categories sc ON ws2."categoryId" = sc.id
            WHERE ws2."workerProfileId" = wp.id
          ) AS skills
        FROM worker_profiles wp
        WHERE wp."availabilityStatus" = 'ONLINE'::"AvailabilityStatus"
          AND wp."currentlyWorking" = FALSE
          AND wp."currentLat" IS NOT NULL
          AND wp."currentLng" IS NOT NULL
          AND wp."locationUpdatedAt" > NOW() - INTERVAL '30 minutes'
          AND wp."lastSeenAt" > ${presenceCutoff}::timestamptz
          AND wp.status = 'ACTIVE'::"WorkerStatus"
          AND wp."onboardingStatus" = 'APPROVED'::"WorkerOnboardingStatus"
          AND wp."profileCompleted" = TRUE
          AND wp.id != ALL(${excludedIds}::text[])
          AND EXISTS (
            SELECT 1 FROM worker_skills ws
            WHERE ws."workerProfileId" = wp.id
              AND ws."categoryId" = ${params.categoryId}
          )
          AND ST_DWithin(
            wp.location,
            ST_SetSRID(ST_MakePoint(${params.lng}::float8, ${params.lat}::float8), 4326)::geography,
            ${radiusMeters}::float8
          )
        ORDER BY distance_meters ASC, wp.rating DESC
        LIMIT ${this.nearbyWorkerFetchLimit}
      `;
    } catch (err) {
      this.logger.warn(
        `[nearby-workers] PostGIS query failed (${(err as Error)?.message}); ` +
          'falling back to the Haversine path. If USE_POSTGIS=true, check that ' +
          'migration 20260818000100_worker_location_geography has been applied.',
      );
      return this._queryNearbyWorkersHaversine(params);
    }

    const rows = raw.map((r) => ({
      id: r.id,
      firstName: r.firstName,
      lastName: r.lastName,
      avatarUrl: r.avatarUrl ?? null,
      rating: Number(r.rating),
      distanceMeters: Number(r.distance_meters),
      skills: r.skills,
      completedJobs: 0,
    }));
    return this._attachCompletedJobs(rows);
  }

  // -- Haversine fallback (no PostGIS required) ------------------------------

  /**
   * Same eligibility filters as the PostGIS path, with a lat/lng BOUNDING BOX
   * applied in SQL as the geographic pre-filter. The box is a strict superset
   * of the radius circle, so the precise Haversine pass below removes exactly
   * the workers it always did - the difference is that the database no longer
   * hands Node every online, skilled worker in the country first.
   */
  private async _queryNearbyWorkersHaversine(params: {
    categoryId: string;
    lat: number;
    lng: number;
    maxRadiusKm: number;
    excludedWorkerIds?: string[];
  }): Promise<NearbyWorkerRow[]> {
    // Location freshness threshold - same 30-minute rule as the PostGIS path.
    const freshThreshold = new Date(Date.now() - 30 * 60 * 1000);
    // Presence-lease threshold - same rule as the PostGIS path.
    const presenceThreshold = new Date(Date.now() - WORKER_PRESENCE_STALE_MS);
    const box = boundingBoxWhere(
      boundingBoxKm(params.lat, params.lng, params.maxRadiusKm),
      'currentLat',
      'currentLng',
    );

    const candidates = await this.prisma.workerProfile.findMany({
      where: {
        availabilityStatus: AvailabilityStatus.ONLINE,
        currentlyWorking: false,
        status: WorkerStatus.ACTIVE,
        onboardingStatus: 'APPROVED',
        profileCompleted: true,
        currentLat: { not: null },
        currentLng: { not: null },
        locationUpdatedAt: { gte: freshThreshold },
        lastSeenAt: { gte: presenceThreshold },
        skills: { some: { categoryId: params.categoryId } },
        ...(params.excludedWorkerIds && params.excludedWorkerIds.length > 0
          ? { id: { notIn: params.excludedWorkerIds } }
          : {}),
        // Wrapped in AND so the box's antimeridian OR cannot collide with
        // another OR on this where object.
        AND: [box],
      },
      // Projection only - no CNIC/document/user payload, and the per-row
      // COMPLETED-booking count that used to ride along on every candidate is
      // now one batched groupBy over the surviving pool instead.
      select: {
        id: true,
        firstName: true,
        lastName: true,
        avatarUrl: true,
        rating: true,
        currentLat: true,
        currentLng: true,
        skills: { select: { category: { select: { name: true } } } },
      },
      take: this.nearbyWorkerFetchLimit,
    });

    const radiusMeters = params.maxRadiusKm * 1000;
    const rows: NearbyWorkerRow[] = [];
    for (const w of candidates) {
      const distanceMeters = haversineMeters(
        params.lat,
        params.lng,
        w.currentLat as number,
        w.currentLng as number,
      );
      if (distanceMeters > radiusMeters) continue;
      rows.push({
        id: w.id,
        firstName: w.firstName,
        lastName: w.lastName,
        avatarUrl: w.avatarUrl ?? null,
        rating: Number(w.rating),
        distanceMeters,
        skills: w.skills.map((s) => s.category.name),
        completedJobs: 0,
      });
    }
    return this._attachCompletedJobs(rows);
  }

  /**
   * completedJobs for a whole pool in ONE groupBy, replacing the per-row
   * correlated COUNT(*) subquery (PostGIS) / _count include (Prisma) that ran
   * for every candidate the geographic filter had not yet rejected.
   */
  private async _attachCompletedJobs(
    rows: NearbyWorkerRow[],
  ): Promise<NearbyWorkerRow[]> {
    if (rows.length === 0) return rows;
    const grouped = await this.prisma.booking.groupBy({
      by: ['workerProfileId'],
      where: {
        workerProfileId: { in: rows.map((r) => r.id) },
        status: BookingStatus.COMPLETED,
      },
      _count: { _all: true },
    });
    const counts = new Map(
      grouped.map((g) => [g.workerProfileId as string, g._count._all]),
    );
    return rows.map((r) => ({ ...r, completedJobs: counts.get(r.id) ?? 0 }));
  }

  /**
   * Batch-attach reviewsCount + cancellationRate to the nearby-worker pool.
   *
   * BEFORE: three queries PER WORKER (review count + the two booking counts
   * inside computeCancellationRate), issued in parallel but still 3N round
   * trips. AFTER: a fixed number of grouped queries for the whole pool. The
   * arithmetic is identical to the shared helper (see worker-stats.util.ts):
   * a cancellation counts for the worker when cancelledByRole = WORKER, or -
   * for historical rows predating that column - when it is null and the
   * reason contains 'Cancelled by worker'.
   */
  private async _attachWorkerStats<
    T extends { id: string; completedJobs: number },
  >(
    workers: T[],
  ): Promise<(T & { reviewsCount: number; cancellationRate: number })[]> {
    if (workers.length === 0) return [];
    const ids = workers.map((w) => w.id);

    const [reviewedBookings, cancelledGroups, acceptedGroups] =
      await Promise.all([
        // Review is 1:1 with Booking, so reviews are attributed to a worker
        // through the reviewed booking.
        this.prisma.booking.findMany({
          where: { workerProfileId: { in: ids }, review: { isNot: null } },
          select: { workerProfileId: true },
        }),
        this.prisma.booking.groupBy({
          by: ['workerProfileId'],
          where: {
            workerProfileId: { in: ids },
            status: BookingStatus.CANCELLED,
            OR: [
              { cancelledByRole: 'WORKER' },
              {
                cancelledByRole: null,
                cancellationReason: { contains: 'Cancelled by worker' },
              },
            ],
          },
          _count: { _all: true },
        }),
        this.prisma.booking.groupBy({
          by: ['workerProfileId'],
          where: {
            workerProfileId: { in: ids },
            status: {
              in: [
                BookingStatus.ACCEPTED,
                BookingStatus.EN_ROUTE,
                BookingStatus.ARRIVED,
                BookingStatus.IN_PROGRESS,
                BookingStatus.COMPLETED,
                BookingStatus.CANCELLED,
              ],
            },
          },
          _count: { _all: true },
        }),
      ]);

    const reviewCounts = new Map<string, number>();
    for (const booking of reviewedBookings) {
      if (!booking.workerProfileId) continue;
      reviewCounts.set(
        booking.workerProfileId,
        (reviewCounts.get(booking.workerProfileId) ?? 0) + 1,
      );
    }
    const cancelledCounts = new Map(
      cancelledGroups.map((g) => [g.workerProfileId as string, g._count._all]),
    );
    const acceptedCounts = new Map(
      acceptedGroups.map((g) => [g.workerProfileId as string, g._count._all]),
    );

    return workers.map((w) => {
      const totalAccepted = acceptedCounts.get(w.id) ?? 0;
      const workerCancelled = cancelledCounts.get(w.id) ?? 0;
      return {
        ...w,
        reviewsCount: reviewCounts.get(w.id) ?? 0,
        cancellationRate:
          totalAccepted > 0
            ? Math.round((workerCancelled / totalAccepted) * 100)
            : 0,
      };
    });
  }

  /**
   * Assign a worker to a booking, set status → ACCEPTED, and record history.
   * Also marks the worker as currentlyWorking = true so they are excluded from
   * new nearby-worker searches while on this job.
   * Wrapped in a transaction; booking is re-fetched with full relations.
   *
   * The currentlyWorking flip is conditional (updateMany + count check, not a
   * blind update) so that two concurrent assignments to the same worker
   * (e.g. two clients hiring at once, or an assignWorker/acceptBid race)
   * can't both succeed — whichever transaction loses re-checks the worker's
   * live eligibility (busy/active/verified/online/profile-complete) as the
   * final authoritative gate and throws WorkerUnavailableError, which rolls
   * back every write in this transaction (booking never gets workerProfileId).
   */
  async assignWorkerToBooking(
    bookingId: string,
    workerProfileId: string,
    finalPrice?: number,
    platformFee?: number,
  ): Promise<{ booking: BookingWithRelations; changed: boolean }> {
    const changed = await this.prisma.$transaction(async (tx) => {
      // Guarded by status: PENDING, workerProfileId: null so two different
      // assigns racing on the same booking (assignWorker/assignWorker or
      // assignWorker/acceptBid) can never both win — the loser gets
      // changed: false and never touches the worker's busy flag below.
      const bookingRes = await tx.booking.updateMany({
        where: { id: bookingId, status: BookingStatus.PENDING, workerProfileId: null },
        data: {
          workerProfileId,
          status: BookingStatus.ACCEPTED,
          acceptedAt: new Date(),
          finalPrice: finalPrice ?? undefined,
          platformFee: platformFee ?? undefined,
        },
      });
      if (bookingRes.count === 0) return false;

      await tx.bookingStatusHistory.create({
        data: {
          bookingId,
          status: BookingStatus.ACCEPTED,
          note: 'Worker assigned by client',
        },
      });

      // Mark worker as busy so they don't appear in new nearby-worker pools.
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

      return true;
    });

    const booking = await this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: BOOKING_INCLUDE,
    });
    return { booking, changed };
  }

  /**
   * Customer paid the inspection fee and chose to find a different Ustaad.
   * Fully atomic: marks the report FIND_OTHER_USTAAD, completes the original
   * inspection booking (the inspector keeps it forever — stats/earnings/
   * My-Jobs derivation picks it up like any other completed job), releases
   * the inspector, and spawns a new linked BIDDING-lane child booking for
   * the repair — all in one transaction, so no partial state is possible.
   *
   * Idempotent: the report's conditional decisionStatus transition is the
   * authoritative guard. A retry/double-tap/concurrent duplicate resolves to
   * ALREADY_DONE with the same child booking instead of duplicating writes.
   */
  async closeInspectionAndOpenRepairBidding(params: {
    reportId: string;
    originalBookingId: string;
    inspectingWorkerProfileId: string;
    clientProfileId: string;
    categoryId: string;
    title: string | null;
    description: string;
    addressLine: string;
    city: string;
    latitude: number;
    longitude: number;
    now: Date;
    expiresAt: Date;
  }): Promise<CloseInspectionOutcome> {
    let childBookingId: string | null = null;
    try {
      childBookingId = await this.prisma.$transaction(async (tx) => {
        // Authoritative idempotency guard — only one request can ever move
        // the report out of PENDING_CLIENT_DECISION into FIND_OTHER_USTAAD.
        const guard = await tx.inspectionReport.updateMany({
          where: {
            id: params.reportId,
            decisionStatus: 'PENDING_CLIENT_DECISION',
          },
          data: { decisionStatus: 'FIND_OTHER_USTAAD' },
        });
        if (guard.count === 0) return null; // resolved outside the transaction

        // Guarded close — never blindly COMPLETE a booking that was
        // concurrently cancelled/reassigned/otherwise moved on.
        const closed = await tx.booking.updateMany({
          where: {
            id: params.originalBookingId,
            status: BookingStatus.IN_PROGRESS,
            workerProfileId: params.inspectingWorkerProfileId,
            lane: BookingLane.INSPECTION,
          },
          data: {
            status: BookingStatus.COMPLETED,
            completedAt: params.now,
          },
        });
        if (closed.count !== 1) throw new InspectionCloseStateError();

        await tx.bookingStatusHistory.create({
          data: {
            bookingId: params.originalBookingId,
            status: BookingStatus.COMPLETED,
            note: 'Inspection completed — client chose to find another Ustaad for the repair',
          },
        });

        // Release the inspecting worker so they're matchable/available again.
        await tx.workerProfile.update({
          where: { id: params.inspectingWorkerProfileId },
          data: { currentlyWorking: false },
        });

        // Spawn the linked repair job as a fresh biddable child booking.
        // Deliberately no finalPrice/inspectionFeeSnapshot — those stay on
        // the original so the inspection fee accounting is untouched.
        const child = await tx.booking.create({
          data: {
            clientProfileId: params.clientProfileId,
            categoryId: params.categoryId,
            lane: BookingLane.BIDDING,
            status: BookingStatus.PENDING,
            inspection: false,
            title: params.title,
            description: params.description,
            addressLine: params.addressLine,
            city: params.city,
            latitude: params.latitude,
            longitude: params.longitude,
            sourceInspectionBookingId: params.originalBookingId,
            liveStartedAt: params.now,
            expiresAt: params.expiresAt,
          },
        });
        await tx.bookingStatusHistory.create({
          data: {
            bookingId: child.id,
            status: BookingStatus.PENDING,
            note: 'Repair job opened for bidding after completed inspection',
          },
        });
        return child.id;
      });
    } catch (err) {
      if (err instanceof InspectionCloseStateError) {
        return { outcome: 'BOOKING_STATE_CHANGED' };
      }
      throw err;
    }

    if (childBookingId !== null) {
      const childBooking = await this.prisma.booking.findUniqueOrThrow({
        where: { id: childBookingId },
        include: BOOKING_INCLUDE,
      });
      return { outcome: 'CREATED', childBooking };
    }

    // Guard lost — re-read the actual decision instead of assuming a retry.
    const report = await this.prisma.inspectionReport.findUnique({
      where: { id: params.reportId },
      select: { decisionStatus: true },
    });
    if (!report) return { outcome: 'LINK_MISSING' };
    if (report.decisionStatus !== 'FIND_OTHER_USTAAD') {
      return {
        outcome: 'CONFLICTING_DECISION',
        decisionStatus: report.decisionStatus,
      };
    }
    const existingChild = await this.prisma.booking.findUnique({
      where: { sourceInspectionBookingId: params.originalBookingId },
      include: BOOKING_INCLUDE,
    });
    if (!existingChild) return { outcome: 'LINK_MISSING' };
    return { outcome: 'ALREADY_DONE', childBooking: existingChild };
  }

  /**
   * Customer decided to re-hire the original inspecting worker after all
   * (having pressed "Find Other Ustaad" earlier). Atomically re-assigns the
   * booking back to them and rejects any bids submitted in the meantime —
   * same "only one hire can succeed" shape as assignWorkerToBooking, with an
   * added conditional guard on the Booking row itself (workerProfileId=null
   * AND status=PENDING) so a concurrent bid-accept by another worker can't
   * both succeed.
   */
  async rehireInspectingWorker(
    bookingId: string,
    workerProfileId: string,
    finalPrice: number,
    platformFee: number,
  ): Promise<BookingWithRelations> {
    await this.prisma.$transaction(async (tx) => {
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
      if (bookingRes.count === 0) throw new WorkerUnavailableError();

      await tx.bookingStatusHistory.create({
        data: {
          bookingId,
          status: BookingStatus.ACCEPTED,
          note: 'Client re-hired the original inspecting Ustaad',
        },
      });

      // The job is no longer open — no other worker can be hired for it.
      await tx.bid.updateMany({
        where: { bookingId, status: BidStatus.PENDING },
        data: { status: BidStatus.REJECTED },
      });

      const workerRes = await tx.workerProfile.updateMany({
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
      if (workerRes.count === 0) throw new WorkerUnavailableError();
    });

    return this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: BOOKING_INCLUDE,
    });
  }

  // ── Lifecycle transitions (assigned worker) ─────────────────────────────────

  /**
   * Every lifecycle transition below flips status via an atomic `updateMany`
   * guarded by `fromStatus`, so two concurrent requests for the same
   * transition (double-tap, a retry racing the original) can never both
   * "win" — only the request that actually flips the status writes the
   * history row (and any extra side-effect data). The loser gets
   * `changed: false`; the caller decides whether the re-fetched booking's
   * current status makes that a safe idempotent no-op or a genuine conflict.
   */
  private async _guardedTransition(
    bookingId: string,
    fromStatus: BookingStatus,
    data: Prisma.BookingUpdateInput,
    historyStatus: BookingStatus,
    historyNote: string,
    extra?: (tx: Prisma.TransactionClient) => Promise<void>,
  ): Promise<{ booking: BookingWithRelations; changed: boolean }> {
    const changed = await this.prisma.$transaction(async (tx) => {
      const { count } = await tx.booking.updateMany({
        where: { id: bookingId, status: fromStatus },
        data,
      });
      if (count === 0) return false;

      await tx.bookingStatusHistory.create({
        data: { bookingId, status: historyStatus, note: historyNote },
      });

      if (extra) await extra(tx);

      return true;
    });

    const booking = await this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: BOOKING_INCLUDE,
    });
    return { booking, changed };
  }

  /** Transition ACCEPTED → EN_ROUTE. */
  async markEnRoute(
    bookingId: string,
  ): Promise<{ booking: BookingWithRelations; changed: boolean }> {
    return this._guardedTransition(
      bookingId,
      BookingStatus.ACCEPTED,
      { status: BookingStatus.EN_ROUTE, enRouteAt: new Date() },
      BookingStatus.EN_ROUTE,
      'Worker is on the way',
    );
  }

  /** Transition EN_ROUTE → ARRIVED. */
  async markArrived(
    bookingId: string,
  ): Promise<{ booking: BookingWithRelations; changed: boolean }> {
    return this._guardedTransition(
      bookingId,
      BookingStatus.EN_ROUTE,
      { status: BookingStatus.ARRIVED, arrivedAt: new Date() },
      BookingStatus.ARRIVED,
      'Worker has arrived',
    );
  }

  /** Transition ARRIVED → IN_PROGRESS. Reuses the existing startedAt field. */
  async markInProgress(
    bookingId: string,
  ): Promise<{ booking: BookingWithRelations; changed: boolean }> {
    return this._guardedTransition(
      bookingId,
      BookingStatus.ARRIVED,
      { status: BookingStatus.IN_PROGRESS, startedAt: new Date() },
      BookingStatus.IN_PROGRESS,
      'Job started by worker',
    );
  }

  /**
   * Transition an active booking to COMPLETED and free the worker.
   * Bookings-module equivalent of WorkersRepository.completeBooking — kept
   * separate because the new /bookings/:id/complete endpoint lives in this
   * module per the product spec, while the legacy /workers/jobs/:id/complete
   * endpoint (still supported) uses the workers module's own copy.
   *
   * `fromStatuses` accepts several starting statuses (ACCEPTED, EN_ROUTE,
   * ARRIVED, IN_PROGRESS — see BookingsService.completeJob), so the guard is
   * an `updateMany` on `status IN (...)` rather than a single fromStatus.
   */
  async completeBookingLifecycle(
    bookingId: string,
    workerProfileId: string,
    fromStatuses: BookingStatus[],
  ): Promise<{ booking: BookingWithRelations; changed: boolean }> {
    const changed = await this.prisma.$transaction(async (tx) => {
      const { count } = await tx.booking.updateMany({
        where: { id: bookingId, status: { in: fromStatuses } },
        data: { status: BookingStatus.COMPLETED, completedAt: new Date() },
      });
      if (count === 0) return false;

      await tx.bookingStatusHistory.create({
        data: {
          bookingId,
          status: BookingStatus.COMPLETED,
          note: 'Job marked as completed by worker',
        },
      });
      await tx.workerProfile.update({
        where: { id: workerProfileId },
        data: { currentlyWorking: false },
      });

      return true;
    });

    const booking = await this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: BOOKING_INCLUDE,
    });
    return { booking, changed };
  }

  /**
   * Worker cancels an assigned job (ACCEPTED/EN_ROUTE/ARRIVED): terminally
   * CANCELS the booking — status CANCELLED, cancelledByRole WORKER, reason
   * preserved, workerProfileId left untouched so the cancelling worker still
   * sees it in their own My Jobs → Cancelled/history. Deliberately does NOT
   * return the booking to PENDING/New Jobs by itself — the client
   * separately triggers reopening (see reopenAfterWorkerCancellation) once
   * they're ready to find another worker.
   */
  async workerCancelBooking(
    bookingId: string,
    workerProfileId: string,
    reason: string,
  ): Promise<BookingWithRelations> {
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: {
          status: BookingStatus.CANCELLED,
          cancelledAt: new Date(),
          cancellationReason: reason,
          cancelledByRole: 'WORKER',
        },
      });

      await tx.bookingStatusHistory.create({
        data: {
          bookingId,
          status: BookingStatus.CANCELLED,
          note: `Worker cancelled: ${reason}`,
        },
      });

      await tx.workerProfile.update({
        where: { id: workerProfileId },
        data: { currentlyWorking: false },
      });
    });

    return this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: BOOKING_INCLUDE,
    });
  }

  /**
   * Client reopens a booking after the assigned worker cancelled it — takes
   * it from CANCELLED back to PENDING/unassigned so the client can find/
   * hire another worker via the existing worker-selection/bidding flows.
   * Excludes the cancelling worker (bookingWorkerExclusion — already
   * enforced by findNearbyWorkers, isEligibleForInspectionBidding, and
   * findAvailableJobsForWorker, so this one write covers all three lanes).
   * For BIDDING, previously-submitted bids that were auto-REJECTED when the
   * now-cancelled worker's bid was accepted are reverted to PENDING so they
   * can be considered again (never the cancelling worker's own bid). For
   * INSPECTION with an existing report, flips decisionStatus to
   * FIND_OTHER_USTAAD (idempotent) so the existing eligibility gate/sanitized
   * report view apply — without this, a report left at ACCEPTED_REPAIR would
   * cause getNewJobsForWorker to skip the eligibility gate entirely.
   */
  async reopenAfterWorkerCancellation(
    bookingId: string,
    cancelledWorkerProfileId: string,
    reason: string,
    now: Date,
    expiresAt: Date,
  ): Promise<BookingWithRelations> {
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: {
          workerProfileId: null,
          status: BookingStatus.PENDING,
          liveStartedAt: now,
          expiresAt,
        },
      });

      await tx.bookingWorkerExclusion.upsert({
        where: {
          bookingId_workerProfileId: {
            bookingId,
            workerProfileId: cancelledWorkerProfileId,
          },
        },
        create: { bookingId, workerProfileId: cancelledWorkerProfileId, reason },
        update: { reason },
      });

      await tx.bid.updateMany({
        where: {
          bookingId,
          status: BidStatus.REJECTED,
          workerProfileId: { not: cancelledWorkerProfileId },
        },
        data: { status: BidStatus.PENDING },
      });

      await tx.inspectionReport.updateMany({
        where: { bookingId },
        data: { decisionStatus: 'FIND_OTHER_USTAAD' },
      });

      await tx.bookingStatusHistory.create({
        data: {
          bookingId,
          status: BookingStatus.PENDING,
          note: 'Reopened after worker cancellation',
        },
      });
    });

    return this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: BOOKING_INCLUDE,
    });
  }

  /**
   * Client relists an EXPIRED booking ("Make Live Again"): back to PENDING
   * with a fresh 72h window. Existing BookingWorkerExclusion rows are left
   * untouched (they are keyed by bookingId, not by "live session") so
   * previously-cancelled workers stay excluded across the relist.
   */
  async relistBooking(
    bookingId: string,
    now: Date,
    expiresAt: Date,
  ): Promise<BookingWithRelations> {
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: {
          status: BookingStatus.PENDING,
          liveStartedAt: now,
          expiresAt,
          relistedAt: now,
        },
      });
      await tx.bookingStatusHistory.create({
        data: {
          bookingId,
          status: BookingStatus.PENDING,
          note: 'Client relisted booking ("Make Live Again")',
        },
      });
    });
    return this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: BOOKING_INCLUDE,
    });
  }
}
