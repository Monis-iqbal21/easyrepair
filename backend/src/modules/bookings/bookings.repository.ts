import { Injectable } from '@nestjs/common';
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
  VerificationStatus,
  WorkerStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { computeCancellationRate } from '../../common/utils/worker-stats.util';

// Raw row shape returned by the PostGIS nearby-workers query.
interface RawNearbyWorkerRow {
  id: string;
  firstName: string;
  lastName: string;
  avatarUrl: string | null;
  rating: number;
  distance_meters: number;
  skills: string[];
  completed_jobs: bigint; // COUNT() returns bigint from Prisma $queryRaw
}

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
    },
    orderBy: { createdAt: 'desc' as const },
  },
  inspectionReport: {
    select: {
      decisionStatus: true,
      createdAt: true,
    },
  },
} satisfies Prisma.BookingInclude;

// Derive the exact return type from the include so every caller is
// fully typed without manual casting.
export type BookingWithRelations = Prisma.BookingGetPayload<{
  include: typeof BOOKING_INCLUDE;
}>;

// ---------------------------------------------------------------------------

@Injectable()
export class BookingsRepository {
  private readonly usePostgis: boolean;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {
    this.usePostgis = this.config.get<boolean>('usePostgis') ?? false;
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
  }): Promise<BookingWithRelations> {
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
          standardServiceNameSnapshot: data.standardServiceNameSnapshot ?? null,
          standardServicePriceSnapshot:
            data.standardServicePriceSnapshot ?? null,
          inspectionFeeSnapshot: data.inspectionFeeSnapshot ?? null,
          estimatedPrice: data.estimatedPrice ?? null,
          expiresAt: data.expiresAt ?? null,
          liveStartedAt: data.liveStartedAt ?? null,
        },
      });

      if (data.standardServiceItems && data.standardServiceItems.length > 0) {
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

    // Step 2 — re-fetch with full relations so the caller gets BookingWithRelations.
    return this.prisma.booking.findUniqueOrThrow({
      where: { id: created.id },
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

  /** Find a single booking by id (returns null when not found). */
  async findBookingById(id: string): Promise<BookingWithRelations | null> {
    return this.prisma.booking.findUnique({
      where: { id },
      include: BOOKING_INCLUDE,
    });
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
        Math.round(((oldAvg * oldCount + data.rating) / newCount) * 10) / 10;

      // 3. Write updated stats.
      await tx.workerProfile.update({
        where: { id: data.workerProfileId },
        data: {
          rating: newAvg,
          totalRatings: newCount,
        },
      });
    });

    return this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: BOOKING_INCLUDE,
    });
  }

  /**
   * Transition a booking to CANCELLED and record the history entry.
   * If the booking had an assigned worker, resets their currentlyWorking flag
   * so they become available for new jobs again.
   * Same two-step pattern: write in transaction, re-fetch with include.
   */
  async cancelBooking(
    bookingId: string,
    reason?: string,
    workerProfileId?: string | null,
    cancelledByRole: 'CLIENT' | 'WORKER' = 'CLIENT',
  ): Promise<BookingWithRelations> {
    const note = reason ?? 'Cancelled by client';

    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: {
          status: BookingStatus.CANCELLED,
          cancelledAt: new Date(),
          cancellationReason: note,
          cancelledByRole,
        },
      });

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
    });

    return this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: BOOKING_INCLUDE,
    });
  }

  // ── Nearby workers ───────────────────────────────────────────────────────────

  /**
   * Find a worker profile by id for availability validation before assignment.
   */
  async findWorkerProfileById(workerProfileId: string) {
    return this.prisma.workerProfile.findUnique({
      where: { id: workerProfileId },
      select: {
        id: true,
        userId: true,
        availabilityStatus: true,
        profileCompleted: true,
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
    /** STANDARD lane uses the tighter 5→7km ladder; other lanes keep the legacy ladder. */
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
    const result = this.usePostgis
      ? await this._findNearbyWorkersPostgis(params)
      : await this._findNearbyWorkersHaversine(params);

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
      ranked.length >= 6 ? 3 : ranked.length >= 3 ? 2 : ranked.length >= 1 ? 1 : 0;
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
   * Batch-attach reviewsCount + cancellationRate to a small pool of nearby
   * workers (bounded by TARGET_POOL, so per-worker queries are cheap).
   * cancellationRate uses the shared helper (see worker-stats.util.ts) so it
   * stays consistent with WorkersRepository.getJobStats.
   */
  private async _attachWorkerStats<
    T extends { id: string; completedJobs: number },
  >(
    workers: T[],
  ): Promise<(T & { reviewsCount: number; cancellationRate: number })[]> {
    return Promise.all(
      workers.map(async (w) => {
        const [reviewsCount, cancellationRate] = await Promise.all([
          this.prisma.review.count({
            where: { booking: { workerProfileId: w.id } },
          }),
          computeCancellationRate(this.prisma, w.id),
        ]);

        return { ...w, reviewsCount, cancellationRate };
      }),
    );
  }

  // ── PostGIS implementation ─────────────────────────────────────────────────

  private async _findNearbyWorkersPostgis(params: {
    categoryId: string;
    lat: number;
    lng: number;
    radiusKm?: number;
    lane?: BookingLane;
    excludedWorkerIds?: string[];
  }) {
    const TARGET_POOL = 4;
    const legacyLadder = [3000, 5000, 8000, 10000, 15000, 20000];
    const standardLadder = [5000, 7000];
    // STANDARD and INSPECTION are both direct-assignment lanes (fixed
    // price/fee, no bidding) and share the tighter 5→7km ladder. BIDDING
    // keeps the wider legacy ladder.
    const radii =
      params.radiusKm !== undefined
        ? [Math.round(params.radiusKm * 1000)]
        : params.lane === BookingLane.STANDARD ||
            params.lane === BookingLane.INSPECTION
          ? standardLadder
          : legacyLadder;
    const excludedIds = params.excludedWorkerIds ?? [];
    // STANDARD and INSPECTION only list Ustaads with a completed profile —
    // BIDDING keeps showing all eligible workers for now (see profileCompleted
    // gate rollout notes in bookings.service.ts).
    const requireProfileCompleted =
      params.lane === BookingLane.STANDARD ||
      params.lane === BookingLane.INSPECTION;

    type WorkerEntry = {
      id: string;
      firstName: string;
      lastName: string;
      avatarUrl: string | null;
      rating: number;
      distanceMeters: number;
      skills: string[];
      completedJobs: number;
    };
    const seen = new Map<string, WorkerEntry>();
    let finalRadius = radii[radii.length - 1];

    for (const radius of radii) {
      finalRadius = radius;

      const rows = await this.prisma.$queryRaw<RawNearbyWorkerRow[]>`
        SELECT
          wp.id,
          wp."firstName",
          wp."lastName",
          wp."avatarUrl",
          wp.rating,
          ST_Distance(
            ST_SetSRID(ST_MakePoint(wp."currentLng"::float8, wp."currentLat"::float8), 4326)::geography,
            ST_SetSRID(ST_MakePoint(${params.lng}::float8, ${params.lat}::float8), 4326)::geography
          )::float8 AS distance_meters,
          ARRAY(
            SELECT sc.name
            FROM worker_skills ws2
            JOIN service_categories sc ON ws2."categoryId" = sc.id
            WHERE ws2."workerProfileId" = wp.id
          ) AS skills,
          (
            SELECT COUNT(*)
            FROM bookings b
            WHERE b."workerProfileId" = wp.id
              AND b.status = 'COMPLETED'::"BookingStatus"
          ) AS completed_jobs
        FROM worker_profiles wp
        WHERE wp."availabilityStatus" = 'ONLINE'::"AvailabilityStatus"
          AND wp."currentlyWorking" = FALSE
          AND wp."currentLat" IS NOT NULL
          AND wp."currentLng" IS NOT NULL
          AND wp."locationUpdatedAt" > NOW() - INTERVAL '30 minutes'
          AND wp.status = 'ACTIVE'::"WorkerStatus"
          AND wp."verificationStatus" = 'VERIFIED'::"VerificationStatus"
          AND wp.id != ALL(${excludedIds}::text[])
          AND (${requireProfileCompleted}::boolean = FALSE OR wp."profileCompleted" = TRUE)
          AND EXISTS (
            SELECT 1 FROM worker_skills ws
            WHERE ws."workerProfileId" = wp.id
              AND ws."categoryId" = ${params.categoryId}
          )
          AND ST_DWithin(
            ST_SetSRID(ST_MakePoint(wp."currentLng"::float8, wp."currentLat"::float8), 4326)::geography,
            ST_SetSRID(ST_MakePoint(${params.lng}::float8, ${params.lat}::float8), 4326)::geography,
            ${radius}::float8
          )
        ORDER BY distance_meters ASC, wp.rating DESC
      `;

      for (const r of rows) {
        if (!seen.has(r.id)) {
          seen.set(r.id, {
            id: r.id,
            firstName: r.firstName,
            lastName: r.lastName,
            avatarUrl: r.avatarUrl ?? null,
            rating: Number(r.rating),
            completedJobs: Number(r.completed_jobs),
            distanceMeters: Number(r.distance_meters),
            skills: r.skills,
          });
        }
      }

      if (seen.size >= TARGET_POOL) break;
    }

    const workers = Array.from(seen.values()).sort((a, b) =>
      a.distanceMeters !== b.distanceMeters
        ? a.distanceMeters - b.distanceMeters
        : b.rating - a.rating,
    );

    return {
      workers,
      searchedRadiusKm: finalRadius / 1000,
      searchCompleted: seen.size >= TARGET_POOL,
    };
  }

  // ── Haversine fallback (no PostGIS required) ───────────────────────────────

  private async _findNearbyWorkersHaversine(params: {
    categoryId: string;
    lat: number;
    lng: number;
    radiusKm?: number;
    lane?: BookingLane;
    excludedWorkerIds?: string[];
  }) {
    const TARGET_POOL = 4;
    const legacyLadderKm = [3, 5, 8, 10, 15, 20];
    const standardLadderKm = [5, 7];
    // STANDARD and INSPECTION share the tighter 5→7km ladder — see the
    // matching comment in _findNearbyWorkersPostgis.
    const radiusLadderKm =
      params.radiusKm !== undefined
        ? [params.radiusKm]
        : params.lane === BookingLane.STANDARD ||
            params.lane === BookingLane.INSPECTION
          ? standardLadderKm
          : legacyLadderKm;

    // Location freshness threshold — same 30-minute rule as the PostGIS path.
    const freshThreshold = new Date(Date.now() - 30 * 60 * 1000);
    // STANDARD and INSPECTION only list Ustaads with a completed profile —
    // see the matching comment in _findNearbyWorkersPostgis.
    const requireProfileCompleted =
      params.lane === BookingLane.STANDARD ||
      params.lane === BookingLane.INSPECTION;

    // Fetch all eligible candidate workers once (avoids repeated DB round-trips).
    // The DB filters everything except the spatial radius (applied in TS below).
    const candidates = await this.prisma.workerProfile.findMany({
      where: {
        availabilityStatus: AvailabilityStatus.ONLINE,
        currentlyWorking: false,
        status: WorkerStatus.ACTIVE,
        verificationStatus: VerificationStatus.VERIFIED,
        currentLat: { not: null },
        currentLng: { not: null },
        locationUpdatedAt: { gte: freshThreshold },
        skills: { some: { categoryId: params.categoryId } },
        ...(requireProfileCompleted ? { profileCompleted: true } : {}),
        ...(params.excludedWorkerIds && params.excludedWorkerIds.length > 0
          ? { id: { notIn: params.excludedWorkerIds } }
          : {}),
      },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        avatarUrl: true,
        rating: true,
        currentLat: true,
        currentLng: true,
        skills: {
          include: { category: { select: { name: true } } },
        },
        _count: {
          select: {
            bookings: { where: { status: BookingStatus.COMPLETED } },
          },
        },
      },
    });

    type WorkerEntry = {
      id: string;
      firstName: string;
      lastName: string;
      avatarUrl: string | null;
      rating: number;
      distanceMeters: number;
      skills: string[];
      completedJobs: number;
    };
    const seen = new Map<string, WorkerEntry>();
    let finalRadiusKm = radiusLadderKm[radiusLadderKm.length - 1];

    for (const radiusKm of radiusLadderKm) {
      finalRadiusKm = radiusKm;
      const radiusMeters = radiusKm * 1000;

      for (const w of candidates) {
        if (seen.has(w.id)) continue;

        const distanceMeters = haversineMeters(
          params.lat,
          params.lng,
          w.currentLat as number,
          w.currentLng as number,
        );

        if (distanceMeters <= radiusMeters) {
          seen.set(w.id, {
            id: w.id,
            firstName: w.firstName,
            lastName: w.lastName,
            avatarUrl: w.avatarUrl ?? null,
            rating: Number(w.rating),
            completedJobs: w._count.bookings,
            distanceMeters,
            skills: w.skills.map((s) => s.category.name),
          });
        }
      }

      if (seen.size >= TARGET_POOL) break;
    }

    const workers = Array.from(seen.values()).sort((a, b) =>
      a.distanceMeters !== b.distanceMeters
        ? a.distanceMeters - b.distanceMeters
        : b.rating - a.rating,
    );

    return {
      workers,
      searchedRadiusKm: finalRadiusKm,
      searchCompleted: seen.size >= TARGET_POOL,
    };
  }

  /**
   * Assign a worker to a booking, set status → ACCEPTED, and record history.
   * Also marks the worker as currentlyWorking = true so they are excluded from
   * new nearby-worker searches while on this job.
   * Wrapped in a transaction; booking is re-fetched with full relations.
   */
  async assignWorkerToBooking(
    bookingId: string,
    workerProfileId: string,
    finalPrice?: number,
  ): Promise<BookingWithRelations> {
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: {
          workerProfileId,
          status: BookingStatus.ACCEPTED,
          acceptedAt: new Date(),
          finalPrice: finalPrice ?? undefined,
        },
      });

      await tx.bookingStatusHistory.create({
        data: {
          bookingId,
          status: BookingStatus.ACCEPTED,
          note: 'Worker assigned by client',
        },
      });

      // Mark worker as busy so they don't appear in new nearby-worker pools.
      await tx.workerProfile.update({
        where: { id: workerProfileId },
        data: { currentlyWorking: true },
      });
    });

    return this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: BOOKING_INCLUDE,
    });
  }

  // ── Lifecycle transitions (assigned worker) ─────────────────────────────────

  /** Transition ACCEPTED → EN_ROUTE. */
  async markEnRoute(bookingId: string): Promise<BookingWithRelations> {
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: { status: BookingStatus.EN_ROUTE, enRouteAt: new Date() },
      });
      await tx.bookingStatusHistory.create({
        data: {
          bookingId,
          status: BookingStatus.EN_ROUTE,
          note: 'Worker is on the way',
        },
      });
    });
    return this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: BOOKING_INCLUDE,
    });
  }

  /** Transition EN_ROUTE → ARRIVED. */
  async markArrived(bookingId: string): Promise<BookingWithRelations> {
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: { status: BookingStatus.ARRIVED, arrivedAt: new Date() },
      });
      await tx.bookingStatusHistory.create({
        data: {
          bookingId,
          status: BookingStatus.ARRIVED,
          note: 'Worker has arrived',
        },
      });
    });
    return this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: BOOKING_INCLUDE,
    });
  }

  /** Transition ARRIVED → IN_PROGRESS. Reuses the existing startedAt field. */
  async markInProgress(bookingId: string): Promise<BookingWithRelations> {
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: { status: BookingStatus.IN_PROGRESS, startedAt: new Date() },
      });
      await tx.bookingStatusHistory.create({
        data: {
          bookingId,
          status: BookingStatus.IN_PROGRESS,
          note: 'Job started by worker',
        },
      });
    });
    return this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: BOOKING_INCLUDE,
    });
  }

  /**
   * Transition an active booking to COMPLETED and free the worker.
   * Bookings-module equivalent of WorkersRepository.completeBooking — kept
   * separate because the new /bookings/:id/complete endpoint lives in this
   * module per the product spec, while the legacy /workers/jobs/:id/complete
   * endpoint (still supported) uses the workers module's own copy.
   */
  async completeBookingLifecycle(
    bookingId: string,
    workerProfileId: string,
  ): Promise<BookingWithRelations> {
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: { status: BookingStatus.COMPLETED, completedAt: new Date() },
      });
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
    });
    return this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: BOOKING_INCLUDE,
    });
  }

  /**
   * Worker cancels before arrival: free the worker, record a
   * BookingWorkerExclusion row (so this worker never reappears for this
   * booking, surviving relist), clear the assignment, and return the booking
   * to PENDING so the client can choose a new worker — reusing all existing
   * exclusion/nearby-worker logic with zero extra branching.
   */
  async workerCancelBooking(
    bookingId: string,
    workerProfileId: string,
    reason: string,
    expiresAt: Date,
    liveStartedAt: Date,
  ): Promise<BookingWithRelations> {
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: {
          status: BookingStatus.PENDING,
          workerProfileId: null,
          acceptedAt: null,
          enRouteAt: null,
          cancellationReason: reason,
          cancelledByRole: 'WORKER',
          expiresAt,
          liveStartedAt,
        },
      });

      await tx.bookingWorkerExclusion.upsert({
        where: {
          bookingId_workerProfileId: { bookingId, workerProfileId },
        },
        create: { bookingId, workerProfileId, reason },
        update: { reason },
      });

      await tx.bookingStatusHistory.create({
        data: {
          bookingId,
          status: BookingStatus.PENDING,
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
