import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { AvailabilityStatus, BookingStatus } from '@prisma/client';
import { WorkerJobWithRelations, WorkersRepository } from './workers.repository';
import { UpdateAvailabilityDto } from './dto/update-availability.dto';
import { UpdateSkillsDto } from './dto/update-skills.dto';
import {
  WorkerJobAttachmentDto,
  WorkerJobResponseDto,
  WorkerJobStatusHistoryDto,
} from './dto/worker-job-response.dto';

@Injectable()
export class WorkersService {
  private readonly logger = new Logger(WorkersService.name);

  constructor(private readonly workersRepository: WorkersRepository) {}

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

    return this.workersRepository.updateAvailability(
      profile.id,
      dto.status,
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
      attachments,
      statusHistory,
    };
  }
}
