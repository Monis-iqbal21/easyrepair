import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  AttachmentType,
  AvailabilityStatus,
  BookingUrgency,
  BookingStatus,
  TimeSlot,
  Prisma,
  VerificationStatus,
  WorkerStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

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
  workerProfile: {
    select: {
      id: true,
      firstName: true,
      lastName: true,
      avatarUrl: true,
      rating: true,
      currentLat: true,
      currentLng: true,
    },
  },
  attachments: {
    select: {
      id: true,
      type: true,
      url: true,
      fileName: true,
      mimeType: true,
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
          status: BookingStatus.PENDING,
        },
      });

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
    },
  ): Promise<BookingWithRelations> {
    await this.prisma.booking.update({
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
      },
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
    fileName?: string;
    mimeType?: string;
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
  ): Promise<BookingWithRelations> {
    const note = reason ?? 'Cancelled by client';

    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: {
          status: BookingStatus.CANCELLED,
          cancelledAt: new Date(),
          cancellationReason: note,
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
      select: { id: true, availabilityStatus: true },
    });
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
   * Radius ladder: 3 → 5 → 8 → 10 → 15 → 20 km (server-side) or a single
   * caller-supplied radius (frontend-driven expansion).
   * Expansion stops as soon as TARGET_POOL (4) unique workers are found.
   */
  async findNearbyWorkers(params: {
    categoryId: string;
    lat: number;
    lng: number;
    /** When provided, only this single radius is searched (frontend-driven expansion).
     *  When omitted the full ladder 3→20 km runs server-side (backward compat). */
    radiusKm?: number;
  }): Promise<{
    workers: Array<{
      id: string;
      firstName: string;
      lastName: string;
      avatarUrl: string | null;
      rating: number;
      completedJobs: number;
      distanceMeters: number;
      skills: string[];
    }>;
    searchedRadiusKm: number;
    searchCompleted: boolean;
  }> {
    return this.usePostgis
      ? this._findNearbyWorkersPostgis(params)
      : this._findNearbyWorkersHaversine(params);
  }

  // ── PostGIS implementation ─────────────────────────────────────────────────

  private async _findNearbyWorkersPostgis(params: {
    categoryId: string;
    lat: number;
    lng: number;
    radiusKm?: number;
  }) {
    const TARGET_POOL = 4;
    const radii =
      params.radiusKm !== undefined
        ? [Math.round(params.radiusKm * 1000)]
        : [3000, 5000, 8000, 10000, 15000, 20000];

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
  }) {
    const TARGET_POOL = 4;
    const radiusLadderKm =
      params.radiusKm !== undefined
        ? [params.radiusKm]
        : [3, 5, 8, 10, 15, 20];

    // Location freshness threshold — same 30-minute rule as the PostGIS path.
    const freshThreshold = new Date(Date.now() - 30 * 60 * 1000);

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
  ): Promise<BookingWithRelations> {
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: {
          workerProfileId,
          status: BookingStatus.ACCEPTED,
          acceptedAt: new Date(),
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
}
