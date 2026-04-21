import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { InjectQueue } from '@nestjs/bull';
import { AvailabilityStatus, BookingStatus } from '@prisma/client';
import { Queue } from 'bull';
import { WorkerJobWithRelations, WorkersRepository } from './workers.repository';
import { NotificationsService } from '../notifications/notifications.service';
import { UpdateAvailabilityDto } from './dto/update-availability.dto';
import {
  AUTO_OFFLINE_JOB,
  AutoOfflineJobData,
  WORKERS_QUEUE,
} from './workers.processor';
import { UpdateSkillsDto } from './dto/update-skills.dto';
import { UpdateLocationDto } from './dto/update-location.dto';
import {
  WorkerJobAttachmentDto,
  WorkerJobResponseDto,
  WorkerJobReviewDto,
  WorkerJobStatusHistoryDto,
} from './dto/worker-job-response.dto';
import {
  WorkerReviewResponseDto,
  WorkerReviewSummaryDto,
} from './dto/worker-review-response.dto';

/** 7 hours in milliseconds — delay before auto-offline job fires. */
const AUTO_OFFLINE_DELAY_MS = 7 * 60 * 60 * 1000;

@Injectable()
export class WorkersService {
  private readonly logger = new Logger(WorkersService.name);

  constructor(
    private readonly workersRepository: WorkersRepository,
    private readonly notificationsService: NotificationsService,
    @InjectQueue(WORKERS_QUEUE) private readonly autoOfflineQueue: Queue,
  ) {}

  // ── Profile & availability ───────────────────────────────────────────────

  /** Get the full worker dashboard profile including skills, stats, and ongoing job. */
  async getProfile(userId: string) {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) {
      throw new NotFoundException('Worker profile not found');
    }

    const [stats, ongoingJob] = await Promise.all([
      this.workersRepository.getJobStats(profile.id),
      this.workersRepository.findOngoingJob(profile.id),
    ]);

    return {
      id: profile.id,
      userId: profile.userId,
      firstName: profile.firstName,
      lastName: profile.lastName,
      avatarUrl: profile.avatarUrl,
      bio: profile.bio,
      status: profile.status,
      verificationStatus: profile.verificationStatus,
      availabilityStatus: profile.availabilityStatus,
      currentlyWorking: profile.currentlyWorking,
      currentLat: profile.currentLat,
      currentLng: profile.currentLng,
      locationUpdatedAt: profile.locationUpdatedAt,
      rating: profile.rating,
      totalRatings: profile.totalRatings,
      skills: profile.skills.map((s) => ({
        id: s.id,
        yearsExperience: s.yearsExperience,
        category: s.category,
      })),
      stats,
      ongoingJob: ongoingJob
        ? {
            id: ongoingJob.id,
            title: ongoingJob.title,
            categoryName: ongoingJob.category.name,
            clientArea: ongoingJob.city,
            addressLine: ongoingJob.addressLine,
            status: ongoingJob.status,
          }
        : null,
    };
  }

  /** Update worker availability status and location. */
  async updateAvailability(userId: string, dto: UpdateAvailabilityDto) {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) {
      throw new NotFoundException('Worker profile not found');
    }

    if (
      dto.status === AvailabilityStatus.ONLINE &&
      profile.skills.length === 0
    ) {
      throw new UnprocessableEntityException(
        'You must add at least one skill before going online',
      );
    }

    if (
      dto.status === AvailabilityStatus.ONLINE &&
      (dto.lat == null || dto.lng == null)
    ) {
      throw new BadRequestException('Location is required when going online');
    }

    // Capture the previous status BEFORE the DB update so we can detect a
    // true OFFLINE → ONLINE transition vs. a repeated ONLINE refresh.
    const previousStatus = profile.availabilityStatus;

    const result = await this.workersRepository.updateAvailability(
      profile.id,
      dto.status,
      dto.lat,
      dto.lng,
    );

    await this._syncAutoOfflineJob(
      profile.id,
      userId,
      previousStatus,
      dto.status,
    );

    return result;
  }

  /**
   * Manage the auto-offline delayed job based on a true status transition.
   *
   * Rules:
   *  - previousStatus != ONLINE  AND  newStatus == ONLINE  → start the timer
   *  - previousStatus == ONLINE  AND  newStatus == ONLINE  → do nothing (timer keeps running)
   *  - newStatus != ONLINE (going OFFLINE / BUSY)          → cancel any pending timer
   *
   * This ensures repeated ONLINE location-refresh calls never reset the clock.
   */
  private async _syncAutoOfflineJob(
    workerProfileId: string,
    userId: string,
    previousStatus: AvailabilityStatus,
    newStatus: AvailabilityStatus,
  ): Promise<void> {
    const jobId = `auto-offline-${workerProfileId}`;

    if (newStatus === AvailabilityStatus.ONLINE) {
      if (previousStatus !== AvailabilityStatus.ONLINE) {
        // True transition into ONLINE — remove any stale job and start a fresh timer.
        const existing = await this.autoOfflineQueue.getJob(jobId);
        if (existing) {
          await existing.remove();
          this.logger.log(
            `[auto-offline] removed stale job on ONLINE transition for workerProfileId=${workerProfileId}`,
          );
        }
        const data: AutoOfflineJobData = { workerProfileId, userId };
        await this.autoOfflineQueue.add(AUTO_OFFLINE_JOB, data, {
          jobId,
          delay: AUTO_OFFLINE_DELAY_MS,
          removeOnComplete: true,
          removeOnFail: false,
        });
        this.logger.log(
          `[auto-offline] scheduled in 7 h for workerProfileId=${workerProfileId}`,
        );
      } else {
        // Already ONLINE — leave the existing delayed job untouched.
        this.logger.debug(
          `[auto-offline] already online, timer preserved for workerProfileId=${workerProfileId}`,
        );
      }
    } else {
      // Worker going OFFLINE or BUSY — cancel any pending auto-offline job.
      const existing = await this.autoOfflineQueue.getJob(jobId);
      if (existing) {
        await existing.remove();
        this.logger.log(
          `[auto-offline] cancelled job (worker → ${newStatus}) for workerProfileId=${workerProfileId}`,
        );
      }
    }
  }

  /**
   * Location-only ping — updates lat/lng without touching availabilityStatus.
   * Called by the worker app's periodic location tracker so that it can never
   * re-online a worker who was auto-offlined.  Silently no-ops if offline.
   */
  async updateLocation(userId: string, dto: UpdateLocationDto): Promise<void> {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) {
      throw new NotFoundException('Worker profile not found');
    }
    await this.workersRepository.updateLocationOnly(
      profile.id,
      dto.lat,
      dto.lng,
    );
  }

  /** Replace all skills for a worker. */
  async updateSkills(userId: string, dto: UpdateSkillsDto) {
    this.logger.log(
      `[updateSkills] userId=${userId} categoryIds=${JSON.stringify(dto.categoryIds)}`,
    );

    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) {
      this.logger.warn(
        `[updateSkills] worker profile not found for userId=${userId}`,
      );
      throw new NotFoundException('Worker profile not found');
    }

    const found = await this.workersRepository.findCategoriesByIds(
      dto.categoryIds,
    );
    this.logger.log(
      `[updateSkills] requested=${dto.categoryIds.length} found=${found.length}`,
    );
    if (found.length !== dto.categoryIds.length) {
      const foundIds = found.map((c) => c.id);
      const missing = dto.categoryIds.filter((id) => !foundIds.includes(id));
      this.logger.warn(
        `[updateSkills] invalid categoryIds: ${JSON.stringify(missing)}`,
      );
      throw new BadRequestException('One or more category IDs are invalid');
    }

    const skills = await this.workersRepository.replaceSkills(
      profile.id,
      dto.categoryIds,
    );
    this.logger.log(
      `[updateSkills] saved ${skills.length} skills for workerProfileId=${profile.id}`,
    );
    return skills.map((s) => ({
      id: s.id,
      yearsExperience: s.yearsExperience,
      category: s.category,
    }));
  }

  // ── Worker jobs ──────────────────────────────────────────────────────────

  /** List all jobs assigned to this worker, with optional filter. */
  async getWorkerJobs(
    userId: string,
    statusFilter?: 'active' | 'completed' | 'cancelled',
  ): Promise<WorkerJobResponseDto[]> {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');

    const jobs = await this.workersRepository.findJobsByWorkerProfileId(
      profile.id,
      statusFilter,
    );
    return jobs.map((j) => this._toJobDto(j));
  }

  /** Get a single job by id, scoped to the authenticated worker. */
  async getWorkerJobById(
    userId: string,
    bookingId: string,
  ): Promise<WorkerJobResponseDto> {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');

    const job = await this.workersRepository.findJobByIdAndWorkerProfileId(
      bookingId,
      profile.id,
    );
    if (!job) throw new NotFoundException('Job not found');

    return this._toJobDto(job);
  }

  /**
   * Mark an active job as COMPLETED.
   * Eligible statuses: ACCEPTED, EN_ROUTE, IN_PROGRESS.
   * Also frees the worker (currentlyWorking = false).
   */
  async completeJob(
    userId: string,
    bookingId: string,
  ): Promise<WorkerJobResponseDto> {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');

    const job = await this.workersRepository.findJobByIdAndWorkerProfileId(
      bookingId,
      profile.id,
    );
    if (!job) throw new NotFoundException('Job not found');

    const completable: BookingStatus[] = [
      BookingStatus.ACCEPTED,
      BookingStatus.EN_ROUTE,
      BookingStatus.IN_PROGRESS,
    ];
    if (!completable.includes(job.status)) {
      throw new BadRequestException(
        `Cannot complete a job with status ${job.status}`,
      );
    }

    const updated = await this.workersRepository.completeBooking(
      bookingId,
      profile.id,
    );

    // Notify client that the job is complete
    if (updated.clientProfile?.userId) {
      void this.notificationsService.notify({
        userId: updated.clientProfile.userId,
        eventKey: 'booking.completed',
        title: 'Job Completed',
        body: 'Your worker has completed the job. Please leave a review.',
        bookingId,
        route: `/client/booking/${bookingId}`,
        actorUserId: userId,
        actorRole: 'WORKER',
        entityType: 'booking',
        entityId: bookingId,
      });
    }

    return this._toJobDto(updated);
  }

  /**
   * Transition an active job to EN_ROUTE or IN_PROGRESS.
   * Notifies the client on each transition.
   */
  async updateJobStatus(
    userId: string,
    bookingId: string,
    status: 'EN_ROUTE' | 'IN_PROGRESS',
  ): Promise<WorkerJobResponseDto> {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');

    const job = await this.workersRepository.findJobByIdAndWorkerProfileId(
      bookingId,
      profile.id,
    );
    if (!job) throw new NotFoundException('Job not found');

    const validTransitions: Record<string, BookingStatus[]> = {
      [BookingStatus.EN_ROUTE]: [BookingStatus.ACCEPTED],
      [BookingStatus.IN_PROGRESS]: [
        BookingStatus.ACCEPTED,
        BookingStatus.EN_ROUTE,
      ],
    };

    if (!validTransitions[status]?.includes(job.status)) {
      throw new BadRequestException(
        `Cannot transition job from ${job.status} to ${status}`,
      );
    }

    const updated = await this.workersRepository.updateJobStatus(
      bookingId,
      profile.id,
      status,
    );

    if (updated.clientProfile?.userId) {
      if (status === BookingStatus.EN_ROUTE) {
        void this.notificationsService.notify({
          userId: updated.clientProfile.userId,
          eventKey: 'booking.status.en_route',
          title: 'Worker On the Way',
          body: 'Your worker is on the way to your location.',
          bookingId,
          route: `/client/booking/${bookingId}`,
          actorUserId: userId,
          actorRole: 'WORKER',
          entityType: 'booking',
          entityId: bookingId,
        });
      } else {
        void this.notificationsService.notify({
          userId: updated.clientProfile.userId,
          eventKey: 'booking.status.in_progress',
          title: 'Job Started',
          body: 'Your worker has started working on your request.',
          bookingId,
          route: `/client/booking/${bookingId}`,
          actorUserId: userId,
          actorRole: 'WORKER',
          entityType: 'booking',
          entityId: bookingId,
        });
      }
    }

    return this._toJobDto(updated);
  }

  /**
   * Worker cancels an active job (ACCEPTED or EN_ROUTE).
   * Notifies the client.
   */
  async cancelJob(
    userId: string,
    bookingId: string,
    reason?: string,
  ): Promise<WorkerJobResponseDto> {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');

    const job = await this.workersRepository.findJobByIdAndWorkerProfileId(
      bookingId,
      profile.id,
    );
    if (!job) throw new NotFoundException('Job not found');

    const cancellable: BookingStatus[] = [
      BookingStatus.ACCEPTED,
      BookingStatus.EN_ROUTE,
    ];
    if (!cancellable.includes(job.status)) {
      throw new BadRequestException(
        `Cannot cancel a job with status ${job.status}`,
      );
    }

    const updated = await this.workersRepository.cancelJobByWorker(
      bookingId,
      profile.id,
      reason,
    );

    if (updated.clientProfile?.userId) {
      void this.notificationsService.notify({
        userId: updated.clientProfile.userId,
        eventKey: 'booking.cancelled.by_worker',
        title: 'Job Cancelled',
        body: 'The worker has cancelled the job.',
        bookingId,
        route: `/client/booking/${bookingId}`,
        actorUserId: userId,
        actorRole: 'WORKER',
        entityType: 'booking',
        entityId: bookingId,
      });
    }

    return this._toJobDto(updated);
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  private _toJobDto(job: WorkerJobWithRelations): WorkerJobResponseDto {
    const attachments: WorkerJobAttachmentDto[] = job.attachments.map((a) => ({
      id: a.id,
      type: a.type,
      url: a.url,
      fileName: a.fileName ?? null,
      mimeType: a.mimeType ?? null,
      createdAt: a.createdAt.toISOString(),
    }));

    const statusHistory: WorkerJobStatusHistoryDto[] = job.statusHistory.map(
      (h) => ({
        id: h.id,
        status: h.status,
        note: h.note ?? null,
        createdAt: h.createdAt.toISOString(),
      }),
    );

    const cp = job.clientProfile;
    const clientName = cp
      ? `${cp.firstName} ${cp.lastName}`.trim()
      : null;

    return {
      id: job.id,
      serviceCategory: job.category.name,
      title: job.title ?? null,
      description: job.description,
      status: job.status,
      urgency: job.urgency,
      timeSlot: job.timeSlot ?? null,
      // Use the same key names as BookingResponseDto so the Flutter
      // BookingModel.fromJson can parse worker job responses too.
      scheduledDate: job.scheduledAt?.toISOString() ?? null,
      createdAt: job.createdAt.toISOString(),
      acceptedAt: job.acceptedAt?.toISOString() ?? null,
      startedAt: job.startedAt?.toISOString() ?? null,
      completedAt: job.completedAt?.toISOString() ?? null,
      estimatedPrice: job.estimatedPrice ?? null,
      finalPrice: job.finalPrice ?? null,
      address: job.addressLine,
      city: job.city,
      latitude: job.latitude,
      longitude: job.longitude,
      clientName,
      attachments,
      statusHistory,
      review: job.review
        ? {
            id: job.review.id,
            rating: job.review.rating,
            comment: job.review.comment ?? null,
            createdAt: job.review.createdAt.toISOString(),
          } satisfies WorkerJobReviewDto
        : null,
    };
  }

  // ── Worker reviews ──────────────────────────────────────────────────────

  /**
   * Return reviews for this worker's completed bookings.
   * Pass `limit` to cap results (used for the dashboard preview).
   */
  async getWorkerReviews(
    userId: string,
    limit?: number,
  ): Promise<WorkerReviewResponseDto[]> {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');

    const reviews = await this.workersRepository.findWorkerReviews(
      profile.id,
      limit,
    );

    return reviews.map((r) => ({
      id: r.id,
      bookingId: r.booking.id,
      rating: r.rating,
      comment: r.comment ?? null,
      serviceCategory: r.booking.category.name,
      clientName: r.booking.clientProfile
        ? `${r.booking.clientProfile.firstName} ${r.booking.clientProfile.lastName}`.trim()
        : null,
      createdAt: r.createdAt.toISOString(),
    }));
  }

  /** Return aggregate rating stats for this worker. */
  async getWorkerReviewSummary(userId: string): Promise<WorkerReviewSummaryDto> {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');

    return this.workersRepository.getWorkerReviewSummary(profile.id);
  }
}
