import { Injectable } from '@nestjs/common';
import {
  AvailabilityStatus,
  BookingLane,
  BookingStatus,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  computeCancellationRate,
  computeCompletedJobs,
} from '../../common/utils/worker-stats.util';
import { calculateGrossWorkerEarning } from '../../common/utils/commission.util';

// ---------------------------------------------------------------------------
// Worker profile include
// ---------------------------------------------------------------------------

const WORKER_PROFILE_INCLUDE = {
  skills: {
    include: {
      category: {
        select: { id: true, name: true, iconUrl: true },
      },
    },
  },
} satisfies Prisma.WorkerProfileInclude;

export type WorkerProfileWithSkills = Prisma.WorkerProfileGetPayload<{
  include: typeof WORKER_PROFILE_INCLUDE;
}>;

// ---------------------------------------------------------------------------
// Worker job include — used for the jobs list + detail + complete endpoints.
// ---------------------------------------------------------------------------

const WORKER_JOB_INCLUDE = {
  category: { select: { name: true } },
  clientProfile: {
    select: {
      firstName: true,
      lastName: true,
      userId: true,
      user: { select: { phone: true } },
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
  statusHistory: {
    select: {
      id: true,
      status: true,
      note: true,
      createdAt: true,
    },
    orderBy: { createdAt: 'asc' as const },
  },
  review: {
    select: { id: true, rating: true, comment: true, createdAt: true },
  },
  inspectionReport: {
    select: { decisionStatus: true, createdAt: true, workerProfileId: true },
  },
} satisfies Prisma.BookingInclude;

export type WorkerJobWithRelations = Prisma.BookingGetPayload<{
  include: typeof WORKER_JOB_INCLUDE;
}>;

// ---------------------------------------------------------------------------
// Review include — used by worker review endpoints.
// ---------------------------------------------------------------------------

const WORKER_REVIEW_INCLUDE = {
  booking: {
    select: {
      id: true,
      category: { select: { name: true } },
      clientProfile: { select: { firstName: true, lastName: true } },
    },
  },
} satisfies Prisma.ReviewInclude;

export type WorkerReviewWithBooking = Prisma.ReviewGetPayload<{
  include: typeof WORKER_REVIEW_INCLUDE;
}>;

// ---------------------------------------------------------------------------

@Injectable()
export class WorkersRepository {
  constructor(private readonly prisma: PrismaService) {}

  // ── Profile ──────────────────────────────────────────────────────────────

  /** Update the avatarUrl for a worker profile. */
  async updateAvatarUrl(
    workerProfileId: string,
    avatarUrl: string,
  ): Promise<void> {
    await this.prisma.workerProfile.update({
      where: { id: workerProfileId },
      data: { avatarUrl },
    });
  }

  /** Find a WorkerProfile by userId (includes skills). */
  async findByUserId(userId: string): Promise<WorkerProfileWithSkills | null> {
    return this.prisma.workerProfile.findUnique({
      where: { userId },
      include: WORKER_PROFILE_INCLUDE,
    });
  }

  /** Update availability status and optionally location. */
  async updateAvailability(
    workerProfileId: string,
    status: AvailabilityStatus,
    lat?: number,
    lng?: number,
  ) {
    const goingOnline = status === AvailabilityStatus.ONLINE;
    const goingOffline = status === AvailabilityStatus.OFFLINE;
    return this.prisma.workerProfile.update({
      where: { id: workerProfileId },
      data: {
        availabilityStatus: status,
        isOnline: goingOnline || status === AvailabilityStatus.BUSY,
        // Record session start when going online; clear it when going offline.
        // BUSY transitions (set by booking flow) leave onlineAt untouched.
        ...(goingOnline ? { onlineAt: new Date() } : {}),
        ...(goingOffline ? { onlineAt: null } : {}),
        ...(lat !== undefined && lng !== undefined
          ? {
              currentLat: lat,
              currentLng: lng,
              locationUpdatedAt: new Date(),
            }
          : {}),
      },
      select: {
        availabilityStatus: true,
        currentLat: true,
        currentLng: true,
        locationUpdatedAt: true,
      },
    });
  }

  /** Fetch minimal worker profile fields needed by the auto-offline processor. */
  async findById(id: string): Promise<{
    id: string;
    userId: string;
    availabilityStatus: AvailabilityStatus;
  } | null> {
    return this.prisma.workerProfile.findUnique({
      where: { id },
      select: { id: true, userId: true, availabilityStatus: true },
    });
  }

  /**
   * Update lat/lng only — never changes availabilityStatus.
   * Used by periodic location pings so they cannot re-online a worker that was
   * auto-offlined. Silently no-ops if the worker is not currently ONLINE.
   */
  async updateLocationOnly(
    workerProfileId: string,
    lat: number,
    lng: number,
  ): Promise<void> {
    await this.prisma.workerProfile.updateMany({
      where: {
        id: workerProfileId,
        availabilityStatus: AvailabilityStatus.ONLINE,
      },
      data: {
        currentLat: lat,
        currentLng: lng,
        locationUpdatedAt: new Date(),
      },
    });
  }

  /** Unconditionally set a worker offline and clear onlineAt. Used by auto-offline processor. */
  async setOfflineById(workerProfileId: string): Promise<void> {
    await this.prisma.workerProfile.update({
      where: { id: workerProfileId },
      data: {
        availabilityStatus: AvailabilityStatus.OFFLINE,
        isOnline: false,
        onlineAt: null,
      },
    });
  }

  /**
   * Replace all worker skills atomically.
   * Deletes existing skills then creates the new set inside an interactive
   * transaction so that the final findMany is guaranteed to see the new rows.
   * Callers (WorkersService.updateSkills) already enforce at most one
   * categoryId, but this method itself only trusts what it's given.
   *
   * Also flips WorkerProfile.profileCompleted — having exactly one skill is
   * the only mandatory setup step gating hireability today (STANDARD/
   * INSPECTION direct-hire and BIDDING's createBid/editBid all require
   * profileCompleted=true). Clearing the skill correctly re-locks hireability.
   */
  async replaceSkills(
    workerProfileId: string,
    categoryIds: string[],
    yearsExperience?: number,
  ) {
    return this.prisma.$transaction(async (tx) => {
      await tx.workerSkill.deleteMany({ where: { workerProfileId } });

      await tx.workerSkill.createMany({
        data: categoryIds.map((categoryId) => ({
          workerProfileId,
          categoryId,
          ...(yearsExperience !== undefined ? { yearsExperience } : {}),
        })),
      });

      await tx.workerProfile.update({
        where: { id: workerProfileId },
        data: { profileCompleted: categoryIds.length === 1 },
      });

      return tx.workerSkill.findMany({
        where: { workerProfileId },
        include: {
          category: {
            select: { id: true, name: true, iconUrl: true },
          },
        },
      });
    });
  }

  /**
   * Update years of experience on the worker's existing (single) skill row,
   * without touching which category is selected. Used by the
   * profile-completion form's "Experience in Years" field. No-op if the
   * worker has no skill yet.
   */
  async updateSkillExperience(
    workerProfileId: string,
    yearsExperience: number,
  ): Promise<void> {
    await this.prisma.workerSkill.updateMany({
      where: { workerProfileId },
      data: { yearsExperience },
    });
  }

  // ── Profile completion (Ustaad onboarding) ────────────────────────────────

  /** Partial update of the profile-completion text/checkbox fields. */
  async updateProfileCompletion(
    workerProfileId: string,
    data: Prisma.WorkerProfileUpdateInput,
  ): Promise<WorkerProfileWithSkills> {
    return this.prisma.workerProfile.update({
      where: { id: workerProfileId },
      data,
      include: WORKER_PROFILE_INCLUDE,
    });
  }

  async updateCnicFront(
    workerProfileId: string,
    url: string,
    storageKey: string,
  ): Promise<void> {
    await this.prisma.workerProfile.update({
      where: { id: workerProfileId },
      data: { cnicFrontUrl: url, cnicFrontStorageKey: storageKey },
    });
  }

  async updateCnicBack(
    workerProfileId: string,
    url: string,
    storageKey: string,
  ): Promise<void> {
    await this.prisma.workerProfile.update({
      where: { id: workerProfileId },
      data: { cnicBackUrl: url, cnicBackStorageKey: storageKey },
    });
  }

  async updateLiveSelfie(
    workerProfileId: string,
    url: string,
    storageKey: string,
  ): Promise<void> {
    await this.prisma.workerProfile.update({
      where: { id: workerProfileId },
      data: { liveSelfieUrl: url, liveSelfieStorageKey: storageKey },
    });
  }

  /** Move a DRAFT/CHANGES_REQUIRED profile into the admin review queue. */
  async submitForReview(
    workerProfileId: string,
  ): Promise<WorkerProfileWithSkills> {
    return this.prisma.workerProfile.update({
      where: { id: workerProfileId },
      data: {
        onboardingStatus: 'SUBMITTED_FOR_REVIEW',
        submittedForReviewAt: new Date(),
        // Clear stale reasons from a previous review cycle.
        changesRequiredReason: null,
        rejectionReason: null,
      },
      include: WORKER_PROFILE_INCLUDE,
    });
  }

  /** Count completed and active jobs, plus earnings, cancel rate, and response label. */
  async getJobStats(workerProfileId: string): Promise<{
    completedJobs: number;
    activeJobs: number;
    todayEarnings: number;
    cancellationRate: number;
    avgResponseMinutes: number | null;
    responseLabel: 'Fast' | 'Normal' | 'Slow' | null;
  }> {
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const [
      completedJobsAssigned,
      inspectionOnlyCompletedCount,
      activeJobs,
      todayCompleted,
      todayInspectedForOtherUstaad,
      cancellationRate,
      responseData,
    ] = await Promise.all([
      // Shared helper — single source of truth, see worker-stats.util.ts
      computeCompletedJobs(this.prisma, workerProfileId),
      // Lifetime count of jobs this worker only inspected where a
      // different Ustaad ended up hired for the repair — without this,
      // completedJobs would silently undercount the inspector's real
      // track record once Booking.workerProfileId moves away from them.
      this.prisma.inspectionReport.count({
        where: {
          workerProfileId,
          decisionStatus: 'FIND_OTHER_USTAAD',
          booking: { status: BookingStatus.COMPLETED },
        },
      }),
      this.prisma.booking.count({
        where: {
          workerProfileId,
          status: {
            in: [
              BookingStatus.ACCEPTED,
              BookingStatus.EN_ROUTE,
              BookingStatus.ARRIVED,
              BookingStatus.IN_PROGRESS,
            ],
          },
        },
      }),
      // Today's completed bookings CURRENTLY assigned to this worker, with
      // pricing for earnings. For INSPECTION-lane jobs, finalPrice is
      // labour+parts merged — the related InspectionReport.labourCost/
      // decisionStatus are what calculateCommissionBase uses to exclude
      // parts correctly. If this worker inspected the job but a DIFFERENT
      // Ustaad ended up hired for the repair (the "Find Other Ustaad"
      // outcome), it won't be workerProfileId-matched here anymore — that
      // case is covered separately by todayInspectedForOtherUstaad below.
      this.prisma.booking.findMany({
        where: {
          workerProfileId,
          status: BookingStatus.COMPLETED,
          completedAt: { gte: todayStart },
        },
        select: {
          lane: true,
          finalPrice: true,
          platformFee: true,
          inspectionReport: {
            select: { labourCost: true, decisionStatus: true },
          },
        },
      }),
      // Bookings this worker inspected where the customer chose "Find
      // Other Ustaad" and a DIFFERENT worker ended up hired for the repair
      // (decisionStatus stays FIND_OTHER_USTAAD forever in that case — it
      // only reverts to ACCEPTED_REPAIR if this same worker is re-hired,
      // which is already covered by the query above). This worker still
      // earns the inspection-fee portion regardless of who did the repair.
      this.prisma.inspectionReport.findMany({
        where: {
          workerProfileId,
          decisionStatus: 'FIND_OTHER_USTAAD',
          booking: {
            status: BookingStatus.COMPLETED,
            completedAt: { gte: todayStart },
          },
        },
        select: { booking: { select: { inspectionFeeSnapshot: true } } },
      }),
      // Shared helper — single source of truth, see worker-stats.util.ts
      computeCancellationRate(this.prisma, workerProfileId),
      // Jobs with acceptedAt for response time calculation
      this.prisma.booking.findMany({
        where: { workerProfileId, acceptedAt: { not: null } },
        select: { createdAt: true, acceptedAt: true },
      }),
    ]);

    // Earnings shown to the worker are GROSS — the full pre-commission
    // amount, using the same calculateGrossWorkerEarning helper as the rest
    // of the earnings-facing code (see commission.util.ts for exactly how
    // parts are excluded per lane/decision). HandyGo's 18% commission is a
    // company-accounting concern (Booking.platformFee) and must never be
    // subtracted from what the Ustaad sees as their own earning.
    const workEarnings = todayCompleted.reduce((sum, b) => {
      return (
        sum +
        calculateGrossWorkerEarning({
          lane: b.lane,
          finalPrice: b.finalPrice,
          inspectionReport: b.inspectionReport,
        })
      );
    }, 0);

    // Inspection-fee-only earnings for jobs this worker inspected but a
    // different Ustaad performed the repair on — gross, same as above.
    const inspectionOnlyEarnings = todayInspectedForOtherUstaad.reduce(
      (sum, r) => {
        const fee = r.booking.inspectionFeeSnapshot;
        if (fee == null) return sum;
        return sum + fee;
      },
      0,
    );

    const todayEarnings = workEarnings + inspectionOnlyEarnings;

    // Average response time in minutes; null when no acceptedAt data exists
    let avgResponseMinutes: number | null = null;
    if (responseData.length > 0) {
      const totalMs = responseData.reduce((sum, b) => {
        return sum + (b.acceptedAt!.getTime() - b.createdAt.getTime());
      }, 0);
      avgResponseMinutes = Math.round(totalMs / responseData.length / 60000);
    }

    let responseLabel: 'Fast' | 'Normal' | 'Slow' | null = null;
    if (avgResponseMinutes !== null) {
      if (avgResponseMinutes <= 5) responseLabel = 'Fast';
      else if (avgResponseMinutes <= 15) responseLabel = 'Normal';
      else responseLabel = 'Slow';
    }

    const completedJobs = completedJobsAssigned + inspectionOnlyCompletedCount;

    return {
      completedJobs,
      activeJobs,
      todayEarnings,
      cancellationRate,
      avgResponseMinutes,
      responseLabel,
    };
  }

  /**
   * All-time completed-job earnings for this worker, grouped by calendar
   * date (newest first). Gross amounts via calculateGrossWorkerEarning —
   * the same source getJobStats' todayEarnings uses, so the home dashboard
   * tile and this history never disagree on what a job actually earned.
   */
  async getEarningsHistory(workerProfileId: string): Promise<
    {
      date: string;
      grossTotal: number;
      jobsCount: number;
      jobs: {
        bookingId: string;
        lane: BookingLane;
        serviceCategory: string;
        grossEarning: number;
        completedAt: Date;
        isInspectionOnly: boolean;
      }[];
    }[]
  > {
    const [assignedCompleted, inspectedForOtherUstaad] = await Promise.all([
      this.prisma.booking.findMany({
        where: {
          workerProfileId,
          status: BookingStatus.COMPLETED,
          completedAt: { not: null },
        },
        select: {
          id: true,
          lane: true,
          finalPrice: true,
          completedAt: true,
          category: { select: { name: true } },
          inspectionReport: { select: { labourCost: true, decisionStatus: true } },
        },
      }),
      // Same "inspected but a different Ustaad did the repair" case as
      // getJobStats — decisionStatus stays FIND_OTHER_USTAAD forever then,
      // so this worker's inspection-fee earning never surfaces via the
      // query above (workerProfileId has moved to the other worker).
      this.prisma.inspectionReport.findMany({
        where: {
          workerProfileId,
          decisionStatus: 'FIND_OTHER_USTAAD',
          booking: { status: BookingStatus.COMPLETED, completedAt: { not: null } },
        },
        select: {
          booking: {
            select: {
              id: true,
              completedAt: true,
              inspectionFeeSnapshot: true,
              category: { select: { name: true } },
            },
          },
        },
      }),
    ]);

    type Job = {
      bookingId: string;
      lane: BookingLane;
      serviceCategory: string;
      grossEarning: number;
      completedAt: Date;
      isInspectionOnly: boolean;
    };

    const jobs: Job[] = assignedCompleted.map((b) => ({
      bookingId: b.id,
      lane: b.lane,
      serviceCategory: b.category.name,
      grossEarning: calculateGrossWorkerEarning({
        lane: b.lane,
        finalPrice: b.finalPrice,
        inspectionReport: b.inspectionReport,
      }),
      completedAt: b.completedAt!,
      isInspectionOnly: false,
    }));

    for (const r of inspectedForOtherUstaad) {
      const fee = r.booking.inspectionFeeSnapshot;
      if (fee == null) continue;
      jobs.push({
        bookingId: r.booking.id,
        lane: BookingLane.INSPECTION,
        serviceCategory: r.booking.category.name,
        grossEarning: fee,
        completedAt: r.booking.completedAt!,
        isInspectionOnly: true,
      });
    }

    const byDate = new Map<string, Job[]>();
    for (const job of jobs) {
      const dateKey = job.completedAt.toISOString().slice(0, 10);
      const list = byDate.get(dateKey);
      if (list) list.push(job);
      else byDate.set(dateKey, [job]);
    }

    return Array.from(byDate.entries())
      .sort((a, b) => (a[0] < b[0] ? 1 : -1))
      .map(([date, dayJobs]) => ({
        date,
        grossTotal:
          Math.round(
            dayJobs.reduce((sum, j) => sum + j.grossEarning, 0) * 100,
          ) / 100,
        jobsCount: dayJobs.length,
        jobs: dayJobs.sort(
          (a, b) => b.completedAt.getTime() - a.completedAt.getTime(),
        ),
      }));
  }

  /** Find the single ongoing job for this worker (if any). */
  async findOngoingJob(workerProfileId: string) {
    return this.prisma.booking.findFirst({
      where: {
        workerProfileId,
        status: {
          in: [
            BookingStatus.ACCEPTED,
            BookingStatus.EN_ROUTE,
            BookingStatus.IN_PROGRESS,
          ],
        },
      },
      orderBy: { updatedAt: 'desc' },
      select: {
        id: true,
        title: true,
        status: true,
        city: true,
        addressLine: true,
        category: { select: { name: true } },
      },
    });
  }

  /** Check that all provided categoryIds exist and are active. */
  async findCategoriesByIds(ids: string[]) {
    return this.prisma.serviceCategory.findMany({
      where: { id: { in: ids }, isActive: true },
      select: { id: true },
    });
  }

  // ── Worker jobs (own bookings) ───────────────────────────────────────────

  /**
   * Fetch all bookings assigned to this worker, newest first.
   * Optional statusFilter: 'active' | 'completed' | 'cancelled'
   */
  async findJobsByWorkerProfileId(
    workerProfileId: string,
    statusFilter?: 'active' | 'completed' | 'cancelled',
  ): Promise<WorkerJobWithRelations[]> {
    const statusIn = (() => {
      if (statusFilter === 'active') {
        return [
          BookingStatus.ACCEPTED,
          BookingStatus.EN_ROUTE,
          BookingStatus.IN_PROGRESS,
        ];
      }
      if (statusFilter === 'completed') return [BookingStatus.COMPLETED];
      if (statusFilter === 'cancelled')
        return [BookingStatus.REJECTED, BookingStatus.CANCELLED];
      return undefined;
    })();

    return this.prisma.booking.findMany({
      where: {
        workerProfileId,
        ...(statusIn ? { status: { in: statusIn } } : {}),
      },
      include: WORKER_JOB_INCLUDE,
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Completed bookings where this worker was the ORIGINAL inspector but a
   * DIFFERENT Ustaad ended up performing the work (Booking.workerProfileId
   * no longer points to them) — without this, their inspection-fee earning
   * would silently vanish from their own completed-jobs history once
   * reassigned. Mirrors the same query shape used by getJobStats' earnings
   * split. Only meaningful for the 'completed' filter — an inspector has no
   * further action to take, so this is intentionally excluded from
   * active/cancelled views.
   */
  async findInspectionOnlyCompletedJobsByWorkerProfileId(
    workerProfileId: string,
  ): Promise<WorkerJobWithRelations[]> {
    return this.prisma.booking.findMany({
      where: {
        status: BookingStatus.COMPLETED,
        inspectionReport: {
          workerProfileId,
          decisionStatus: 'FIND_OTHER_USTAAD',
        },
      },
      include: WORKER_JOB_INCLUDE,
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Fetch a single booking by id, scoped to the given workerProfileId so
   * workers can never access bookings that don't belong to them.
   */
  async findJobByIdAndWorkerProfileId(
    bookingId: string,
    workerProfileId: string,
  ): Promise<WorkerJobWithRelations | null> {
    return this.prisma.booking.findFirst({
      where: { id: bookingId, workerProfileId },
      include: WORKER_JOB_INCLUDE,
    });
  }

  /**
   * Fetch a PENDING available booking by id, applying the same visibility
   * rules as findAvailableJobsForWorker:
   *   1. status = PENDING
   *   2. workerProfileId is null (not yet assigned)
   *   3. categoryId matches one of the worker's skill categories
   */
  async findAvailablePendingJobById(
    bookingId: string,
    workerProfileId: string,
    categoryIds: string[],
  ): Promise<WorkerJobWithRelations | null> {
    return this.prisma.booking.findFirst({
      where: {
        id: bookingId,
        status: BookingStatus.PENDING,
        workerProfileId: null,
        categoryId: { in: categoryIds },
      },
      include: WORKER_JOB_INCLUDE,
    });
  }

  /**
   * Single-booking counterpart to findInspectionOnlyCompletedJobsByWorkerProfileId
   * — lets the original inspector open a completed job's detail page (e.g.
   * tapping it from their own history list) even though a different Ustaad
   * ended up performing the work and Booking.workerProfileId no longer
   * points to them.
   */
  async findInspectionOnlyCompletedJobById(
    bookingId: string,
    workerProfileId: string,
  ): Promise<WorkerJobWithRelations | null> {
    return this.prisma.booking.findFirst({
      where: {
        id: bookingId,
        status: BookingStatus.COMPLETED,
        inspectionReport: {
          workerProfileId,
          decisionStatus: 'FIND_OTHER_USTAAD',
        },
      },
      include: WORKER_JOB_INCLUDE,
    });
  }

  // ── Worker reviews ───────────────────────────────────────────────────────

  /**
   * Fetch reviews left on bookings that were assigned to this worker.
   * Sorted latest first.  Pass `limit` to cap the result set.
   */
  async findWorkerReviews(
    workerProfileId: string,
    limit?: number,
  ): Promise<WorkerReviewWithBooking[]> {
    return this.prisma.review.findMany({
      where: { booking: { workerProfileId } },
      include: WORKER_REVIEW_INCLUDE,
      orderBy: { createdAt: 'desc' },
      ...(limit !== undefined ? { take: limit } : {}),
    });
  }

  /** Aggregate average rating and total review count for a worker. */
  async getWorkerReviewSummary(
    workerProfileId: string,
  ): Promise<{ totalReviews: number; averageRating: number }> {
    const agg = await this.prisma.review.aggregate({
      where: { booking: { workerProfileId } },
      _count: { id: true },
      _avg: { rating: true },
    });
    return {
      totalReviews: agg._count.id,
      averageRating: Math.round((agg._avg.rating ?? 0) * 10) / 10,
    };
  }

  /**
   * Transition a job to EN_ROUTE or IN_PROGRESS.
   * Re-fetches with full relations after commit.
   */
  async updateJobStatus(
    bookingId: string,
    workerProfileId: string,
    status: 'EN_ROUTE' | 'IN_PROGRESS',
  ): Promise<WorkerJobWithRelations> {
    const noteMap: Record<string, string> = {
      [BookingStatus.EN_ROUTE]: 'Worker is en route',
      [BookingStatus.IN_PROGRESS]: 'Job started by worker',
    };

    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: {
          status,
          ...(status === BookingStatus.IN_PROGRESS
            ? { startedAt: new Date() }
            : {}),
        },
      });
      await tx.bookingStatusHistory.create({
        data: { bookingId, status, note: noteMap[status] },
      });
    });

    return this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: WORKER_JOB_INCLUDE,
    });
  }

  /**
   * Cancel a job by the worker. Frees the worker and records history.
   * Re-fetches with full relations after commit.
   */
  async cancelJobByWorker(
    bookingId: string,
    workerProfileId: string,
    reason?: string,
  ): Promise<WorkerJobWithRelations> {
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: {
          status: BookingStatus.CANCELLED,
          cancelledAt: new Date(),
          cancellationReason: reason ?? 'Cancelled by worker',
          cancelledByRole: 'WORKER',
        },
      });
      await tx.bookingStatusHistory.create({
        data: {
          bookingId,
          status: BookingStatus.CANCELLED,
          note: reason ?? 'Cancelled by worker',
        },
      });
      await tx.workerProfile.update({
        where: { id: workerProfileId },
        data: { currentlyWorking: false },
      });
    });

    return this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: WORKER_JOB_INCLUDE,
    });
  }

  /**
   * Transition an active booking to COMPLETED and free the worker.
   * Wrapped in a transaction; re-fetches with full relations after commit.
   */
  async completeBooking(
    bookingId: string,
    workerProfileId: string,
  ): Promise<WorkerJobWithRelations> {
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: {
          status: BookingStatus.COMPLETED,
          completedAt: new Date(),
        },
      });

      await tx.bookingStatusHistory.create({
        data: {
          bookingId,
          status: BookingStatus.COMPLETED,
          note: 'Job marked as completed by worker',
        },
      });

      // Free the worker so they appear in new nearby-worker searches again.
      await tx.workerProfile.update({
        where: { id: workerProfileId },
        data: { currentlyWorking: false },
      });
    });

    return this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: WORKER_JOB_INCLUDE,
    });
  }
}
