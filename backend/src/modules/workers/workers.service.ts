import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { InjectQueue } from '@nestjs/bull';
import { AvailabilityStatus, BookingStatus, Prisma } from '@prisma/client';
import { Queue } from 'bull';
import {
  WorkerJobWithRelations,
  WorkerProfileWithSkills,
  WorkersRepository,
} from './workers.repository';
import { NotificationsService } from '../notifications/notifications.service';
import { StorageService } from '../storage/storage.service';
import {
  UstaadTemplateService,
  UnsupportedTradeError,
} from '../agreements/ustaad-template.service';
import {
  AgreementAcceptanceEvidence,
  AgreementSubmissionError,
  UstaadAcceptanceService,
} from '../agreements/ustaad-acceptance.service';
import { UstaadAgreementAccessService } from '../agreements/ustaad-agreement-access.service';
import { SubmitProfileCompletionDto } from './dto/submit-profile-completion.dto';
import { UpdateAvailabilityDto } from './dto/update-availability.dto';
import {
  AUTO_OFFLINE_JOB,
  AutoOfflineJobData,
  WORKERS_QUEUE,
} from './workers.processor';
import { UpdateSkillsDto } from './dto/update-skills.dto';
import { UpdateLocationDto } from './dto/update-location.dto';
import { UpdateProfileCompletionDto } from './dto/update-profile-completion.dto';
import { haversineKm } from '../../common/utils/geo.util';
import { JobBroadcastService } from '../matching/job-broadcast.service';
import { JobCompletionNotifierService } from '../matching/job-completion-notifier.service';
import { LOCATION_FRESHNESS_MS } from '../../common/utils/job-eligibility.util';
import { deriveInspectionFeePaid } from '../../common/utils/inspection-fee.util';
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
import { WorkerSummaryDto } from '../bookings/dto/booking-response.dto';

/** 7 hours in milliseconds — delay before auto-offline job fires. */
const AUTO_OFFLINE_DELAY_MS = 7 * 60 * 60 * 1000;

@Injectable()
export class WorkersService {
  private readonly logger = new Logger(WorkersService.name);

  constructor(
    private readonly workersRepository: WorkersRepository,
    private readonly notificationsService: NotificationsService,
    private readonly storageService: StorageService,
    // The three-document Ustaad agreement flow: what to read, what to seal,
    // and what the Ustaad may later list/download.
    private readonly ustaadTemplateService: UstaadTemplateService,
    private readonly ustaadAcceptanceService: UstaadAcceptanceService,
    private readonly ustaadAgreementAccess: UstaadAgreementAccessService,
    @InjectQueue(WORKERS_QUEUE) private readonly autoOfflineQueue: Queue,
    // Both live in the leaf MatchingModule — WorkersService and
    // BookingsService share them without importing each other.
    private readonly jobBroadcastService: JobBroadcastService,
    private readonly jobCompletionNotifier: JobCompletionNotifierService,
  ) {}

  // ── Avatar upload ────────────────────────────────────────────────────────

  /** Upload a new profile avatar and persist the URL in the worker profile. */
  async uploadAvatar(
    userId: string,
    buffer: Buffer,
    originalName: string,
    mimeType: string,
  ): Promise<{ avatarUrl: string }> {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');

    const avatarUrl = await this.storageService.upload(
      buffer,
      originalName,
      mimeType,
      'avatars',
    );
    await this.workersRepository.updateAvatarUrl(profile.id, avatarUrl);
    return { avatarUrl };
  }

  // ── Profile completion (Ustaad onboarding) ─────────────────────────────────

  /** Only DRAFT/CHANGES_REQUIRED profiles may be edited — once submitted or
   * approved, the worker can't silently change what an admin already reviewed
   * (or is reviewing). Shared by the text-field update and all 3 uploads. */
  private _assertProfileEditable(onboardingStatus: string): void {
    if (
      onboardingStatus !== 'DRAFT' &&
      onboardingStatus !== 'CHANGES_REQUIRED'
    ) {
      throw new BadRequestException(
        'Profile cannot be edited while it is under review or already approved.',
      );
    }
  }

  async updateProfileCompletion(
    userId: string,
    dto: UpdateProfileCompletionDto,
  ) {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');
    this._assertProfileEditable(profile.onboardingStatus);

    const data: Prisma.WorkerProfileUpdateInput = {};
    if (dto.fullLegalName !== undefined) data.fullLegalName = dto.fullLegalName;
    if (dto.residentialAddress !== undefined) {
      data.residentialAddress = dto.residentialAddress;
    }
    if (dto.cnicNumber !== undefined) data.cnicNumber = dto.cnicNumber;
    if (dto.fatherName !== undefined) data.fatherName = dto.fatherName;
    if (dto.dateOfBirth !== undefined) {
      // A future date of birth is never a typo worth persisting onto a legal
      // document, so it is rejected here as well as in the app.
      const parsed = new Date(`${dto.dateOfBirth}T00:00:00.000Z`);
      if (Number.isNaN(parsed.getTime()) || parsed.getTime() > Date.now()) {
        throw new BadRequestException(
          'Date of birth must be a valid past date.',
        );
      }
      data.dateOfBirth = dto.dateOfBirth;
    }
    if (dto.emergencyContact !== undefined) {
      // Blank means "cleared", which the EVS document prints as the controlled
      // "Not applicable" rather than leaving a hole.
      data.emergencyContact = dto.emergencyContact.trim() || null;
    }
    if (dto.legalNameConfirmed !== undefined) {
      data.legalNameConfirmedAt = dto.legalNameConfirmed ? new Date() : null;
    }
    // Agreement acceptance is deliberately NOT patchable here. It is created
    // only by submitProfileForReview, from per-document evidence validated
    // against the exact version/hash/locale/trade the server loaded.

    if (dto.experienceYears !== undefined) {
      await this.workersRepository.updateSkillExperience(
        profile.id,
        dto.experienceYears,
      );
    }

    let updated: WorkerProfileWithSkills;
    try {
      updated = await this.workersRepository.updateProfileCompletion(
        profile.id,
        data,
      );
    } catch (err) {
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2002' &&
        (err.meta?.target as string[] | undefined)?.includes('cnicNumber')
      ) {
        throw new BadRequestException(
          'This CNIC number is already registered with another worker account.',
        );
      }
      throw err;
    }
    return this._toProfileCompletionDto(updated);
  }

  /**
   * GET /workers/profile-completion/agreement-templates
   *
   * The exact text/version/hash of ALL THREE documents this Ustaad must read
   * before any checkbox can be ticked. [appLocale] is the language the app is
   * currently showing; the approved legal body is returned in the language it
   * genuinely exists in, with `legalLanguageNoticeRequired` telling the app to
   * explain the difference rather than translating the contract.
   *
   * The Customer document is structurally unreachable here.
   */
  async getAgreementTemplates(userId: string, appLocale: string) {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');
    const mainSkillName = profile.skills[0]?.category.name ?? null;
    try {
      return this.ustaadTemplateService.getTemplatesForWorker(
        mainSkillName,
        appLocale,
      );
    } catch (err) {
      if (err instanceof UnsupportedTradeError) {
        // Never substitute another trade's schedule — block instead.
        throw new AgreementSubmissionError(
          'UNSUPPORTED_TRADE',
          'No approved trade agreement exists for this trade yet.',
          { mainTrade: err.mainTrade },
        );
      }
      throw err;
    }
  }

  /**
   * GET /workers/profile-completion/agreements
   * Owner-only list of this worker's own permanent acceptance records. Metadata
   * only — the stored PDF URL is never part of the response; downloads go
   * through the authenticated endpoint below.
   */
  async getMyAgreementAcceptances(userId: string) {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');
    return this.ustaadAgreementAccess.listForWorker(profile.id);
  }

  /**
   * GET /workers/profile-completion/agreements/:acceptanceId/download
   * The accepted PDF bytes, scoped to the caller's own profile. Another
   * worker's acceptance id is rejected rather than served.
   */
  async downloadMyAgreement(userId: string, acceptanceId: string) {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');
    return this.ustaadAgreementAccess.getPdf(acceptanceId, profile.id);
  }

  async uploadCnicFront(
    userId: string,
    buffer: Buffer,
    originalName: string,
    mimeType: string,
  ) {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');
    this._assertProfileEditable(profile.onboardingStatus);

    const uploaded = await this.storageService.uploadFile(
      buffer,
      originalName,
      mimeType,
      `uploads/worker-documents/${profile.id}/cnic-front`,
    );
    await this.workersRepository.updateCnicFront(
      profile.id,
      uploaded.url,
      uploaded.key,
    );
    return { cnicFrontUrl: uploaded.url };
  }

  async uploadCnicBack(
    userId: string,
    buffer: Buffer,
    originalName: string,
    mimeType: string,
  ) {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');
    this._assertProfileEditable(profile.onboardingStatus);

    const uploaded = await this.storageService.uploadFile(
      buffer,
      originalName,
      mimeType,
      `uploads/worker-documents/${profile.id}/cnic-back`,
    );
    await this.workersRepository.updateCnicBack(
      profile.id,
      uploaded.url,
      uploaded.key,
    );
    return { cnicBackUrl: uploaded.url };
  }

  async uploadLiveSelfie(
    userId: string,
    buffer: Buffer,
    originalName: string,
    mimeType: string,
  ) {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');
    this._assertProfileEditable(profile.onboardingStatus);

    const uploaded = await this.storageService.uploadFile(
      buffer,
      originalName,
      mimeType,
      `uploads/worker-documents/${profile.id}/profile-photo`,
    );
    // The one capture becomes both the verification image and the avatar.
    await this.workersRepository.updateProfilePhoto(
      profile.id,
      uploaded.url,
      uploaded.key,
    );
    // `liveSelfieUrl` stays in the response so already-shipped app builds keep
    // working; `avatarUrl` is additive.
    return { liveSelfieUrl: uploaded.url, avatarUrl: uploaded.url };
  }

  /**
   * The profile fields that must exist before the three legal documents can be
   * generated. Keys are the exact names the Flutter form highlights on, so a
   * structured rejection can point at the right input rather than a sentence.
   */
  private _missingProfileFields(profile: WorkerProfileWithSkills): string[] {
    const missing: string[] = [];
    if (!profile.fullLegalName) missing.push('fullLegalName');
    if (!profile.fatherName) missing.push('fatherName');
    if (!profile.dateOfBirth) missing.push('dateOfBirth');
    if (!profile.residentialAddress) missing.push('residentialAddress');
    if (!profile.cnicNumber) missing.push('cnicNumber');
    if (profile.skills.length !== 1) missing.push('mainSkill');
    if (!profile.cnicFrontUrl) missing.push('cnicFront');
    if (!profile.cnicBackUrl) missing.push('cnicBack');
    if (!profile.liveSelfieUrl) missing.push('liveSelfie');
    if (!profile.legalNameConfirmedAt) missing.push('legalNameConfirmed');
    // emergencyContact is deliberately absent: the EVS document prints a
    // controlled "Not applicable" for it, so it is genuinely optional.
    return missing;
  }

  /**
   * The active version of the general and trade documents for a main skill,
   * used only to keep the two legacy admin-facing version columns meaningful.
   * Returns nulls for an unsupported trade — acceptAll rejects that case
   * properly, so this never has to decide the outcome.
   */
  private getTemplateVersions(mainSkillName: string): {
    general: string | null;
    trade: string | null;
  } {
    try {
      const templates = this.ustaadTemplateService.getTemplatesForWorker(
        mainSkillName,
        'ur_Latn',
      );
      return {
        general:
          templates.find(
            (t) => t.documentType === 'USTAAD_SERVICE_PROVIDER_AGREEMENT',
          )?.version ?? null,
        trade:
          templates.find(
            (t) => t.documentType === 'TRADE_SPECIFIC_SERVICE_AGREEMENT',
          )?.version ?? null,
      };
    } catch {
      return { general: null, trade: null };
    }
  }

  /**
   * Validate every required field, seal the THREE immutable Ustaad agreement
   * acceptances, and move the profile to SUBMITTED_FOR_REVIEW — all three
   * inserts and the profile update in ONE Prisma transaction, so a profile can
   * never be marked submitted without complete legal evidence behind it.
   *
   * Nothing about the Ustaad's identity is taken from [dto]. Legal name, CNIC,
   * father's name, date of birth, phone, trade, acceptance ids, timestamps and
   * hashes are all resolved from the authenticated profile and the server.
   * The app only says which document it showed, and that the box was ticked.
   */
  async submitProfileForReview(
    userId: string,
    userPhone: string,
    ipAddress: string | null,
    deviceInfo: string | null,
    dto: SubmitProfileCompletionDto,
  ) {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');
    this._assertProfileEditable(profile.onboardingStatus);

    const missing = this._missingProfileFields(profile);
    if (missing.length > 0) {
      throw new AgreementSubmissionError(
        'MISSING_PROFILE_DATA',
        'Some required profile information is missing.',
        { missingFields: missing },
      );
    }

    const acceptedAt = new Date();

    // Versions for the two legacy admin-facing columns, resolved from the
    // server's own registry — never from the request body.
    const templates = this.getTemplateVersions(profile.skills[0].category.name);

    const summaries = await this.ustaadAcceptanceService.acceptAll({
      workerProfileId: profile.id,
      userId,
      fullLegalName: profile.fullLegalName,
      fatherName: profile.fatherName,
      cnicNumber: profile.cnicNumber,
      dateOfBirth: profile.dateOfBirth,
      residentialAddress: profile.residentialAddress,
      registeredMobile: userPhone,
      mainSkillCategoryName: profile.skills[0].category.name,
      // The Ustaad's approved tags are their single main skill today; the
      // schedule prints the list, so it stays a list here.
      approvedServiceTags: profile.skills.map((s) => s.category.name),
      emergencyContact: profile.emergencyContact,
      // Set once a background check is actually raised with a provider.
      verificationProvider: null,
      verificationRequestDate: null,
      verificationRequestReference: null,
      cnicFrontUrl: profile.cnicFrontUrl,
      cnicBackUrl: profile.cnicBackUrl,
      liveSelfieUrl: profile.liveSelfieUrl,
      ipAddress,
      deviceInfo,
      submissionAttemptId: dto.submissionAttemptId,
      evidence: dto.agreements as unknown as AgreementAcceptanceEvidence[],
      // Applied inside the same transaction as the three inserts.
      profileCompletionUpdate: {
        onboardingStatus: 'SUBMITTED_FOR_REVIEW',
        submittedForReviewAt: acceptedAt,
        // Kept in sync for the admin list, which still reads these two dates.
        // They are now a projection of the acceptance records, never the
        // source of truth for whether the agreements were accepted.
        generalAgreementAcceptedAt: acceptedAt,
        tradeAgreementAcceptedAt: acceptedAt,
        generalAgreementVersion: templates.general,
        tradeAgreementVersion: templates.trade,
        // Clear stale reasons from a previous review cycle.
        changesRequiredReason: null,
        rejectionReason: null,
      },
    });

    const updated = await this.workersRepository.findByUserId(userId);
    return {
      ...this._toProfileCompletionDto(updated!),
      acceptedAgreements: summaries.map((s) => ({
        id: s.id,
        acceptanceId: s.acceptanceId,
        documentType: s.documentType,
        title: s.title,
        version: s.version,
        agreementLocale: s.agreementLocale,
        applicableTrade: s.applicableTrade,
        acceptedAt: s.acceptedAt,
      })),
    };
  }

  private _toProfileCompletionDto(profile: WorkerProfileWithSkills) {
    return {
      id: profile.id,
      fullLegalName: profile.fullLegalName,
      residentialAddress: profile.residentialAddress,
      cnicNumber: profile.cnicNumber,
      fatherName: profile.fatherName,
      dateOfBirth: profile.dateOfBirth,
      emergencyContact: profile.emergencyContact,
      cnicFrontUrl: profile.cnicFrontUrl,
      cnicBackUrl: profile.cnicBackUrl,
      liveSelfieUrl: profile.liveSelfieUrl,
      faceMatchStatus: profile.faceMatchStatus,
      trainingStatus: profile.trainingStatus,
      onboardingStatus: profile.onboardingStatus,
      legalNameConfirmedAt: profile.legalNameConfirmedAt,
      generalAgreementAcceptedAt: profile.generalAgreementAcceptedAt,
      tradeAgreementAcceptedAt: profile.tradeAgreementAcceptedAt,
      generalAgreementVersion: profile.generalAgreementVersion,
      tradeAgreementVersion: profile.tradeAgreementVersion,
      submittedForReviewAt: profile.submittedForReviewAt,
      changesRequiredReason: profile.changesRequiredReason,
      rejectionReason: profile.rejectionReason,
      skills: profile.skills.map((s) => ({
        id: s.id,
        yearsExperience: s.yearsExperience,
        category: s.category,
      })),
    };
  }

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
      // ── Ustaad onboarding / profile completion ─────────────────────────
      // Owner-only endpoint (JwtAuthGuard + CurrentUser scoping) — CNIC and
      // selfie URLs must never appear in any client-facing or other-worker-
      // facing DTO (booking/job responses, bid responses, etc.).
      fullLegalName: profile.fullLegalName,
      residentialAddress: profile.residentialAddress,
      cnicNumber: profile.cnicNumber,
      fatherName: profile.fatherName,
      dateOfBirth: profile.dateOfBirth,
      emergencyContact: profile.emergencyContact,
      cnicFrontUrl: profile.cnicFrontUrl,
      cnicBackUrl: profile.cnicBackUrl,
      liveSelfieUrl: profile.liveSelfieUrl,
      faceMatchStatus: profile.faceMatchStatus,
      trainingStatus: profile.trainingStatus,
      onboardingStatus: profile.onboardingStatus,
      legalNameConfirmedAt: profile.legalNameConfirmedAt,
      generalAgreementAcceptedAt: profile.generalAgreementAcceptedAt,
      tradeAgreementAcceptedAt: profile.tradeAgreementAcceptedAt,
      generalAgreementVersion: profile.generalAgreementVersion,
      tradeAgreementVersion: profile.tradeAgreementVersion,
      submittedForReviewAt: profile.submittedForReviewAt,
      changesRequiredReason: profile.changesRequiredReason,
      rejectionReason: profile.rejectionReason,
      stats,
      ongoingJob: ongoingJob
        ? {
            id: ongoingJob.id,
            title: ongoingJob.title,
            categoryName: ongoingJob.category.name,
            clientArea: ongoingJob.city,
            addressLine: ongoingJob.addressLine,
            status: ongoingJob.status,
            lane: ongoingJob.lane,
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
        'Please select your main skill first.',
      );
    }

    if (
      dto.status === AvailabilityStatus.ONLINE &&
      (profile.onboardingStatus !== 'APPROVED' || !profile.profileCompleted)
    ) {
      throw new UnprocessableEntityException(
        'Profile approval required before receiving jobs.',
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

    // Fire-and-forget: this talks to Redis/Bull and must never block or
    // time out the Go Online response — the availability flip above has
    // already committed by this point. Errors are caught inside the method
    // and logged, never thrown, so this can't fail the request either way.
    void this._syncAutoOfflineJob(
      profile.id,
      userId,
      previousStatus,
      dto.status,
    );

    // A genuine transition into ONLINE is late discovery: surface every
    // still-open nearby job to this Ustaad now. Bypasses the location
    // cooldown because this is a real state change, not a heartbeat.
    if (
      dto.status === AvailabilityStatus.ONLINE &&
      previousStatus !== AvailabilityStatus.ONLINE
    ) {
      void this.jobBroadcastService.matchOpenJobsForWorker(profile.id, {
        bypassCooldown: true,
      });
    }

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

    try {
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
    } catch (err) {
      // Never let a slow/unreachable Redis break Go Online — the
      // availabilityStatus DB write already succeeded regardless of this.
      this.logger.warn(
        `[auto-offline] sync failed for workerProfileId=${workerProfileId}: ${(err as Error)?.message}`,
      );
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

    // Captured BEFORE the write: a worker whose GPS had gone stale was
    // invisible to matching, so this ping makes them newly eligible — that is
    // a real state change and skips the cooldown, unlike a routine heartbeat.
    const wasStale =
      !profile.locationUpdatedAt ||
      Date.now() - profile.locationUpdatedAt.getTime() > LOCATION_FRESHNESS_MS;

    await this.workersRepository.updateLocationOnly(
      profile.id,
      dto.lat,
      dto.lng,
    );

    // Only ONLINE workers are matchable, and updateLocationOnly no-ops for
    // everyone else, so there is nothing to re-match for them either.
    if (profile.availabilityStatus !== AvailabilityStatus.ONLINE) return;

    // Fire-and-forget; throttled by a per-worker Redis cooldown so a frequent
    // heartbeat cannot trigger a re-scan on every ping.
    void this.jobBroadcastService.matchOpenJobsForWorker(profile.id, {
      bypassCooldown: wasStale,
    });
  }

  /**
   * Replace all skills for a worker.
   * Product rule: exactly one main skill for now — reject more than one with
   * a clear message rather than relying solely on the DTO's ArrayMaxSize(1),
   * so the error text is guaranteed regardless of pipe configuration.
   */
  async updateSkills(userId: string, dto: UpdateSkillsDto) {
    this.logger.log(
      `[updateSkills] userId=${userId} categoryIds=${JSON.stringify(dto.categoryIds)}`,
    );

    if (dto.categoryIds.length > 1) {
      throw new BadRequestException('Only one main skill is allowed.');
    }

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
      dto.yearsExperience,
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

    // A worker who only inspected a job that was later reassigned to a
    // different Ustaad (via "Find Other Ustaad") no longer matches
    // Booking.workerProfileId once it's completed — merge their inspection-
    // fee-earning entries back in so this contribution never disappears
    // from their own history. Scoped to 'completed' only: there's nothing
    // left for them to do, so it has no place in active/cancelled.
    let merged = jobs;
    if (statusFilter === 'completed') {
      const inspectionOnlyJobs =
        await this.workersRepository.findInspectionOnlyCompletedJobsByWorkerProfileId(
          profile.id,
        );
      const seenIds = new Set(jobs.map((j) => j.id));
      merged = [
        ...jobs,
        ...inspectionOnlyJobs.filter((j) => !seenIds.has(j.id)),
      ];
    }

    return merged.map((j) => this._toJobDto(j, profile.id));
  }

  /** Get a single job by id, scoped to the authenticated worker. */
  async getWorkerJobById(
    userId: string,
    bookingId: string,
  ): Promise<WorkerJobResponseDto> {
    this.logger.debug(
      `[getWorkerJobById] userId=${userId} bookingId=${bookingId}`,
    );

    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');

    // Try assigned job first (accepted, en-route, in-progress, completed).
    let job = await this.workersRepository.findJobByIdAndWorkerProfileId(
      bookingId,
      profile.id,
    );

    // Fall back to an eligible PENDING available job (same visibility rules as new-jobs feed).
    if (!job) {
      const categoryIds = profile.skills.map((s) => s.categoryId);
      this.logger.debug(
        `[getWorkerJobById] not an assigned job — checking eligible pending job bookingId=${bookingId} categories=${categoryIds.join(',')}`,
      );
      if (categoryIds.length > 0) {
        job = await this.workersRepository.findAvailablePendingJobById(
          bookingId,
          profile.id,
          categoryIds,
        );
      }
    }

    // Second fallback: a completed job this worker only inspected, later
    // reassigned to a different Ustaad — lets them open it from their own
    // history even though they're no longer Booking.workerProfileId.
    if (!job) {
      job = await this.workersRepository.findInspectionOnlyCompletedJobById(
        bookingId,
        profile.id,
      );
    }

    if (!job) {
      this.logger.warn(
        `[getWorkerJobById] job not found bookingId=${bookingId} workerProfileId=${profile.id}`,
      );
      throw new NotFoundException('Job not found');
    }

    this.logger.debug(
      `[getWorkerJobById] found job bookingId=${bookingId} status=${job.status}`,
    );
    return this._toJobDto(job, profile.id, {
      lat: profile.currentLat,
      lng: profile.currentLng,
    });
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

    // Single shared, deduplicated completion notice (Roman Urdu) — the same
    // helper BookingsService.completeJob uses, so the two overlapping
    // completion endpoints can only ever produce one `booking.completed`.
    // Lives in the leaf MatchingModule, so neither service imports the other.
    void this.jobCompletionNotifier.notifyClientJobCompleted(
      bookingId,
      'NORMAL',
      { userId, role: 'WORKER' },
    );

    // This worker just became free — surface any still-open nearby job to
    // them right away rather than waiting for their next poll.
    void this.jobBroadcastService.matchOpenJobsForWorker(profile.id, {
      bypassCooldown: true,
    });

    return this._toJobDto(updated, profile.id);
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

    return this._toJobDto(updated, profile.id);
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

    // Must match BookingEntity.canWorkerCancel in the Flutter app exactly —
    // ACCEPTED, EN_ROUTE, or ARRIVED. Once IN_PROGRESS, cancelling is no
    // longer allowed for any lane.
    const cancellable: BookingStatus[] = [
      BookingStatus.ACCEPTED,
      BookingStatus.EN_ROUTE,
      BookingStatus.ARRIVED,
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

    return this._toJobDto(updated, profile.id);
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /**
   * Maps a booking to the worker-facing DTO.
   * Privacy gate: `isAssignedToCaller` (job.workerProfileId === workerProfileId)
   * decides whether exact address/coordinates/client phone are included.
   * Not-yet-assigned workers (the New Job detail fallback path in
   * getWorkerJobById) only ever get city + a server-computed distanceKm —
   * never the exact location or the client's phone number.
   */
  private _toJobDto(
    job: WorkerJobWithRelations,
    workerProfileId: string,
    workerCoords?: { lat: number | null; lng: number | null },
  ): WorkerJobResponseDto {
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
    const clientName = cp ? `${cp.firstName} ${cp.lastName}`.trim() : null;

    const standardServiceItems = job.standardServiceItems.map((item) => ({
      id: item.id,
      standardServiceId: item.standardServiceId ?? null,
      nameSnapshot: item.nameSnapshot,
      priceSnapshot: item.priceSnapshot,
      quantity: item.quantity,
    }));

    const isAssignedToCaller = job.workerProfileId === workerProfileId;
    // The caller's work on this job was the inspection only — the client
    // chose "Find Other Ustaad" for the repair. Covers both shapes: the
    // pre-fix same-row reassignment (caller no longer assigned) and the
    // new-style completed inspection booking (caller still assigned, repair
    // living on a separate linked booking). Either way, only the inspection
    // fee this caller actually earned is shown — never the repair price.
    const isInspectionOnlyForCaller =
      job.inspectionReport?.workerProfileId === workerProfileId &&
      job.inspectionReport?.decisionStatus === 'FIND_OTHER_USTAAD';
    const distanceKm = isAssignedToCaller
      ? null
      : haversineKm(
          job.latitude,
          job.longitude,
          workerCoords?.lat,
          workerCoords?.lng,
        );

    // Privacy: only the currently assigned/hired worker gets to see who
    // inspected (needed so BookingEntity.isDifferentWorkerPerformingWork can
    // tell them apart from the original inspector) — a not-yet-hired
    // bidder browsing this job via the New Job detail fallback must never
    // receive the inspector's phone number or other details.
    const iwp = isAssignedToCaller ? job.inspectionReport?.workerProfile : null;
    const inspectingWorker: WorkerSummaryDto | null = iwp
      ? {
          id: iwp.id,
          firstName: iwp.firstName,
          lastName: iwp.lastName,
          rating: iwp.rating,
          avatarUrl: iwp.avatarUrl,
          currentLat: iwp.currentLat ?? null,
          currentLng: iwp.currentLng ?? null,
          phone: iwp.user.phone,
        }
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
      inspection: job.inspection,
      lane: job.lane,
      standardServiceItems,
      urgentWindow: job.urgentWindow ?? null,
      acceptedAt: job.acceptedAt?.toISOString() ?? null,
      enRouteAt: job.enRouteAt?.toISOString() ?? null,
      arrivedAt: job.arrivedAt?.toISOString() ?? null,
      startedAt: job.startedAt?.toISOString() ?? null,
      completedAt: job.completedAt?.toISOString() ?? null,
      cancellationReason: job.cancellationReason ?? null,
      cancelledByRole:
        (job.cancelledByRole as 'CLIENT' | 'WORKER' | null) ?? null,
      estimatedPrice: isInspectionOnlyForCaller
        ? null
        : (job.estimatedPrice ?? null),
      finalPrice: isInspectionOnlyForCaller
        ? (job.inspectionFeeSnapshot ?? null)
        : (job.finalPrice ?? null),
      // Privacy: exact address/coordinates/phone are only ever included once
      // this worker is actually assigned. Not-yet-assigned callers (New Job
      // detail) only get city + distanceKm.
      address: isAssignedToCaller ? job.addressLine : null,
      city: job.city,
      latitude: isAssignedToCaller ? job.latitude : null,
      longitude: isAssignedToCaller ? job.longitude : null,
      distanceKm,
      clientName,
      clientPhone: isAssignedToCaller ? (cp?.user?.phone ?? null) : null,
      attachments,
      statusHistory,
      review: job.review
        ? ({
            id: job.review.id,
            rating: job.review.rating,
            comment: job.review.comment ?? null,
            createdAt: job.review.createdAt.toISOString(),
          } satisfies WorkerJobReviewDto)
        : null,
      inspectionReportSubmitted: job.inspectionReport != null,
      inspectionDecisionStatus: job.inspectionReport?.decisionStatus ?? null,
      inspectionReportSubmittedAt:
        job.inspectionReport?.createdAt.toISOString() ?? null,
      isInspectionOnlyForCaller,
      inspectingWorker,
      // Linked repair booking spawned by "Find Other Ustaad" — lets the
      // worker app resolve the source inspection's (price-sanitized) report.
      sourceInspectionBookingId: job.sourceInspectionBookingId ?? null,
      // Same single rule the client sees — owned by the original inspection
      // work unit, never by this repair booking. See inspection-fee.util.ts.
      inspectionFeePaid: deriveInspectionFeePaid(job),
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
  async getWorkerReviewSummary(
    userId: string,
  ): Promise<WorkerReviewSummaryDto> {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');

    return this.workersRepository.getWorkerReviewSummary(profile.id);
  }

  /**
   * GET /workers/earnings/history — all-time completed-job earnings grouped
   * by date, gross (pre-commission), newest first.
   */
  async getEarningsHistory(userId: string) {
    const profile = await this.workersRepository.findByUserId(userId);
    if (!profile) throw new NotFoundException('Worker profile not found');

    return this.workersRepository.getEarningsHistory(profile.id);
  }
}
