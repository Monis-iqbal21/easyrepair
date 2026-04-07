import { Injectable } from '@nestjs/common';
import { AvailabilityStatus, BookingStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

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
} satisfies Prisma.BookingInclude;

export type WorkerJobWithRelations = Prisma.BookingGetPayload<{
  include: typeof WORKER_JOB_INCLUDE;
}>;

// ---------------------------------------------------------------------------

@Injectable()
export class WorkersRepository {
  constructor(private readonly prisma: PrismaService) {}

  // ── Profile ──────────────────────────────────────────────────────────────

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
    return this.prisma.workerProfile.update({
      where: { id: workerProfileId },
      data: {
        availabilityStatus: status,
        isOnline:
          status === AvailabilityStatus.ONLINE ||
          status === AvailabilityStatus.BUSY,
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

  /**
   * Replace all worker skills atomically.
   * Deletes existing skills then creates the new set inside an interactive
   * transaction so that the final findMany is guaranteed to see the new rows.
   */
  async replaceSkills(workerProfileId: string, categoryIds: string[]) {
    return this.prisma.$transaction(async (tx) => {
      await tx.workerSkill.deleteMany({ where: { workerProfileId } });

      await tx.workerSkill.createMany({
        data: categoryIds.map((categoryId) => ({
          workerProfileId,
          categoryId,
        })),
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

  /** Count completed and active jobs for this worker. */
  async getJobStats(
    workerProfileId: string,
  ): Promise<{ completedJobs: number; activeJobs: number }> {
    const [completedJobs, activeJobs] = await Promise.all([
      this.prisma.booking.count({
        where: { workerProfileId, status: BookingStatus.COMPLETED },
      }),
      this.prisma.booking.count({
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
      }),
    ]);

    return { completedJobs, activeJobs };
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
        return [BookingStatus.ACCEPTED, BookingStatus.EN_ROUTE, BookingStatus.IN_PROGRESS];
      }
      if (statusFilter === 'completed') return [BookingStatus.COMPLETED];
      if (statusFilter === 'cancelled') return [BookingStatus.REJECTED, BookingStatus.CANCELLED];
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
