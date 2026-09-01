import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  FaceMatchStatus,
  TrainingStatus,
  WorkerStatus,
  AccountStatus,
  Role,
  Prisma,
} from '@prisma/client';
import { AdminRepository, WorkerProfileAdminView } from './admin.repository';
import { PendingWorkerResponseDto } from './dto/pending-worker-response.dto';
import { AdminStatsResponseDto } from './dto/admin-stats-response.dto';
import { ListWorkersQueryDto } from './dto/list-workers-query.dto';
import { PaginatedWorkersDto } from './dto/worker-list-item.dto';
import { UpdateWorkerProfileDto } from './dto/update-worker-profile.dto';
import { UpdateWorkerSkillsDto } from './dto/update-worker-skills.dto';
import { UstaadAgreementAccessService } from '../agreements/ustaad-agreement-access.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StorageService } from '../storage/storage.service';
import { PrivateFilePayload } from '../../common/utils/private-file-response.util';

export type VerificationDocumentKind = 'cnic-front' | 'cnic-back' | 'selfie';

@Injectable()
export class AdminService {
  constructor(
    private readonly adminRepository: AdminRepository,
    private readonly ustaadAgreementAccess: UstaadAgreementAccessService,
    private readonly notificationsService: NotificationsService,
    private readonly storage?: StorageService,
  ) {}

  async downloadVerificationDocument(
    workerProfileId: string,
    kind: VerificationDocumentKind,
  ): Promise<PrivateFilePayload> {
    const row =
      await this.adminRepository.findVerificationDocumentStorage(
        workerProfileId,
      );
    if (!row) throw new NotFoundException('Worker profile not found');

    const source = {
      'cnic-front': {
        key: row.cnicFrontStorageKey,
        url: row.cnicFrontUrl,
        fileName: 'cnic-front',
      },
      'cnic-back': {
        key: row.cnicBackStorageKey,
        url: row.cnicBackUrl,
        fileName: 'cnic-back',
      },
      selfie: {
        key: row.liveSelfieStorageKey,
        url: row.liveSelfieUrl,
        fileName: 'selfie',
      },
    }[kind];
    const key =
      source.key ??
      (source.url && this.storage ? this.storage.keyFromUrl(source.url) : null);
    if (!key) throw new NotFoundException('Worker document not found');

    const object = await this.storage?.getObject(key);
    if (!object) throw new NotFoundException('Worker document not found');
    return {
      ...object,
      fileName: `${source.fileName}${this._extensionFor(object.contentType)}`,
    };
  }

  async downloadWorkerDocument(
    workerProfileId: string,
    documentId: string,
  ): Promise<PrivateFilePayload> {
    const row = await this.adminRepository.findWorkerDocumentStorage(
      workerProfileId,
      documentId,
    );
    if (!row) throw new NotFoundException('Worker document not found');
    const key =
      row.storageKey ??
      (this.storage ? this.storage.keyFromUrl(row.fileUrl) : null);
    if (!key) throw new NotFoundException('Worker document not found');
    const object = await this.storage?.getObject(key);
    if (!object) throw new NotFoundException('Worker document not found');
    return {
      ...object,
      fileName:
        row.fileName ??
        `worker-document${this._extensionFor(object.contentType)}`,
    };
  }

  /**
   * GET /admin/workers/:id/agreements
   * Permanent acceptance records with their full evidence (acceptance id,
   * language, trade, and the source/accepted/PDF hashes). Metadata only — the
   * storage URL is never returned; downloads go through the endpoint below.
   * Customer documents are excluded at the query level.
   */
  async getWorkerAgreements(workerProfileId: string) {
    await this._ensureExists(workerProfileId);
    return this.ustaadAgreementAccess.listForWorker(workerProfileId);
  }

  /**
   * GET /admin/workers/:id/agreements/:acceptanceId/download
   * The accepted PDF bytes. Scoped to the worker in the path, so a mistyped or
   * guessed id belonging to a different Ustaad is rejected rather than served.
   */
  async downloadWorkerAgreement(workerProfileId: string, acceptanceId: string) {
    await this._ensureExists(workerProfileId);
    return this.ustaadAgreementAccess.getPdf(acceptanceId, workerProfileId);
  }

  /** GET /admin/workers/pending — worker profiles submitted and awaiting review. */
  async getPendingWorkers(): Promise<PendingWorkerResponseDto[]> {
    const workers = await this.adminRepository.findPendingWorkers();
    return workers.map((w) => this._toDto(w));
  }

  /**
   * GET /admin/workers/:id — full detail for one worker, regardless of
   * onboarding stage (works before submission and after approve/reject too).
   */
  async getWorkerById(
    workerProfileId: string,
  ): Promise<PendingWorkerResponseDto> {
    const worker =
      await this.adminRepository.findWorkerByIdFull(workerProfileId);
    if (!worker) throw new NotFoundException('Worker profile not found');
    return this._toDto(worker);
  }

  /** GET /admin/stats — dashboard counters for the admin panel. */
  async getStats(): Promise<AdminStatsResponseDto> {
    return this.adminRepository.getStats();
  }

  /** GET /admin/workers — paginated, searchable, filterable Ustaads List. */
  async getWorkers(query: ListWorkersQueryDto): Promise<PaginatedWorkersDto> {
    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? 20;
    const { items, total } =
      await this.adminRepository.findWorkersPaginated(query);
    return {
      items,
      meta: {
        page,
        pageSize,
        total,
        totalPages: Math.max(1, Math.ceil(total / pageSize)),
      },
    };
  }

  /**
   * PATCH /admin/workers/:id/status
   * The only mutation of WorkerProfile.status. No transition is restricted —
   * ACTIVE/INACTIVE/SUSPENDED may all move to one another. The worker app's
   * existing central routing gate reads this field fresh on every
   * login/me/refresh call, so flipping it here is the entire suspension
   * mechanism; nothing else needs to change.
   */
  async updateWorkerStatus(
    workerProfileId: string,
    status: WorkerStatus,
  ): Promise<PendingWorkerResponseDto> {
    await this._ensureExists(workerProfileId);
    const updated = await this.adminRepository.updateStatus(
      workerProfileId,
      status,
    );
    return this._toDto(updated);
  }

  /**
   * PATCH /admin/workers/:id — operational profile fields only (see
   * UpdateWorkerProfileDto for exactly what's excluded and why). Unlike the
   * worker's own profile-completion PATCH, this is NOT restricted to
   * DRAFT/CHANGES_REQUIRED — an admin may correct data at any onboarding
   * stage, including after approval.
   */
  async updateWorkerProfile(
    workerProfileId: string,
    dto: UpdateWorkerProfileDto,
  ): Promise<PendingWorkerResponseDto> {
    await this._ensureExists(workerProfileId);

    const data: Prisma.WorkerProfileUpdateInput = {};
    if (dto.firstName !== undefined) data.firstName = dto.firstName;
    if (dto.lastName !== undefined) data.lastName = dto.lastName;
    if (dto.fullLegalName !== undefined) data.fullLegalName = dto.fullLegalName;
    if (dto.cnicNumber !== undefined) data.cnicNumber = dto.cnicNumber;
    if (dto.residentialAddress !== undefined) {
      data.residentialAddress = dto.residentialAddress;
    }
    if (dto.fatherName !== undefined) data.fatherName = dto.fatherName;
    if (dto.dateOfBirth !== undefined) {
      const parsed = new Date(`${dto.dateOfBirth}T00:00:00.000Z`);
      if (Number.isNaN(parsed.getTime()) || parsed.getTime() > Date.now()) {
        throw new BadRequestException(
          'Date of birth must be a valid past date.',
        );
      }
      data.dateOfBirth = dto.dateOfBirth;
    }
    if (dto.emergencyContact !== undefined) {
      data.emergencyContact = dto.emergencyContact.trim() || null;
    }

    let updated: WorkerProfileAdminView;
    try {
      updated = await this.adminRepository.updateProfile(workerProfileId, data);
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
    return this._toDto(updated);
  }

  /**
   * PATCH /admin/workers/:id/skills
   * Mirrors WorkersService.updateSkills' validation exactly (one main skill,
   * real category ids) so an admin edit can never create a state the
   * worker's own app doesn't already support.
   */
  async updateWorkerSkills(
    workerProfileId: string,
    dto: UpdateWorkerSkillsDto,
  ): Promise<PendingWorkerResponseDto> {
    await this._ensureExists(workerProfileId);

    if (dto.categoryIds.length > 1) {
      throw new BadRequestException('Only one main skill is allowed.');
    }

    const found = await this.adminRepository.findCategoriesByIds(
      dto.categoryIds,
    );
    if (found.length !== dto.categoryIds.length) {
      throw new BadRequestException('One or more category IDs are invalid');
    }

    const updated = await this.adminRepository.replaceSkills(
      workerProfileId,
      dto.categoryIds,
      dto.yearsExperience,
    );
    return this._toDto(updated);
  }

  /** PATCH /admin/workers/:id/approve */
  async approveWorker(
    workerProfileId: string,
  ): Promise<PendingWorkerResponseDto> {
    await this._ensureExists(workerProfileId);
    const updated = await this.adminRepository.approve(workerProfileId);

    // Fire-and-forget push to the worker — must never block/fail the admin
    // response. Guarded against a retried/double-clicked admin approval
    // (10s window) the same way requestChanges is, without permanently
    // blocking a genuinely new approval cycle for this worker.
    void (async () => {
      const eventKey = 'worker.onboarding.approved';
      const alreadySent =
        await this.notificationsService.wasRecentlyNotifiedForEntity(
          updated.user.id,
          'worker_profile',
          workerProfileId,
          eventKey,
          10_000,
        );
      if (alreadySent) return;

      void this.notificationsService.notify({
        userId: updated.user.id,
        eventKey,
        title: 'Apki Profile Approve hogai hy',
        body: 'Apki Profile Approve hogai hy. App khol kar dekhein.',
        route: '/worker/home',
        entityType: 'worker_profile',
        entityId: workerProfileId,
      });
    })();

    return this._toDto(updated);
  }

  /** PATCH /admin/workers/:id/reject */
  async rejectWorker(
    workerProfileId: string,
    reason: string,
  ): Promise<PendingWorkerResponseDto> {
    await this._ensureExists(workerProfileId);
    const updated = await this.adminRepository.reject(workerProfileId, reason);
    return this._toDto(updated);
  }

  /** PATCH /admin/workers/:id/request-changes */
  async requestChanges(
    workerProfileId: string,
    reason: string,
  ): Promise<PendingWorkerResponseDto> {
    await this._ensureExists(workerProfileId);
    const updated = await this.adminRepository.requestChanges(
      workerProfileId,
      reason,
    );

    // Fire-and-forget push to the worker — must never block/fail the admin
    // response. Guarded against an accidental rapid double-click on the
    // admin "Request Changes" button (10s window) without permanently
    // blocking a legitimate future changes-required cycle for this worker.
    void (async () => {
      const eventKey = 'worker.onboarding.changes_required';
      const alreadySent =
        await this.notificationsService.wasRecentlyNotifiedForEntity(
          updated.user.id,
          'worker_profile',
          workerProfileId,
          eventKey,
          10_000,
        );
      if (alreadySent) return;

      const trimmedReason = reason?.trim();
      const body = trimmedReason
        ? `Admin ne aapki profile mein kuch tabdeeliyan mangi hain. Profile khol kar details check karein.\n\nWajah: ${trimmedReason}`
        : 'Admin ne aapki profile mein kuch tabdeeliyan mangi hain. Profile khol kar details check karein.';
      void this.notificationsService.notify({
        userId: updated.user.id,
        eventKey,
        title: 'Profile mein tabdeeli darkaar hai',
        body,
        templateParams: trimmedReason ? { reason: trimmedReason } : undefined,
        route: '/worker/profile-completion',
        entityType: 'worker_profile',
        entityId: workerProfileId,
        payload: trimmedReason ? { reason: trimmedReason } : undefined,
      });
    })();

    return this._toDto(updated);
  }

  /** PATCH /admin/workers/:id/face-match */
  async updateFaceMatchStatus(
    workerProfileId: string,
    status: FaceMatchStatus,
  ): Promise<PendingWorkerResponseDto> {
    await this._ensureExists(workerProfileId);
    const updated = await this.adminRepository.setFaceMatchStatus(
      workerProfileId,
      status,
    );
    return this._toDto(updated);
  }

  /** PATCH /admin/workers/:id/training-status */
  async updateTrainingStatus(
    workerProfileId: string,
    status: TrainingStatus,
  ): Promise<PendingWorkerResponseDto> {
    await this._ensureExists(workerProfileId);
    const updated = await this.adminRepository.setTrainingStatus(
      workerProfileId,
      status,
    );
    return this._toDto(updated);
  }

  /**
   * PATCH /admin/users/:userId/account-status
   * Client-only account-level restriction — completely separate from
   * WorkerStatus (Worker job-eligibility gate). Deliberately rejects any
   * non-CLIENT target so this can never be used to accidentally suspend a
   * Worker or Admin account through the wrong endpoint; Worker suspension
   * has its own dedicated mechanism and is untouched by this one.
   */
  async updateClientAccountStatus(userId: string, status: AccountStatus) {
    const user = await this.adminRepository.findUserRoleAndStatusById(userId);
    if (!user || user.deletedAt !== null) {
      throw new NotFoundException('User not found');
    }
    if (user.role !== Role.CLIENT) {
      throw new BadRequestException(
        'Account-status restriction only applies to CLIENT accounts.',
      );
    }
    return this.adminRepository.updateAccountStatus(userId, status);
  }

  private async _ensureExists(workerProfileId: string): Promise<void> {
    const profile = await this.adminRepository.findById(workerProfileId);
    if (!profile) throw new NotFoundException('Worker profile not found');
  }

  private _toDto(w: WorkerProfileAdminView): PendingWorkerResponseDto {
    return {
      id: w.id,
      userId: w.user.id,
      phone: w.user.phone,
      firstName: w.firstName,
      lastName: w.lastName,
      bio: w.bio,
      avatarUrl: w.avatarUrl,
      status: w.status,
      verificationStatus: w.verificationStatus,
      skills: w.skills.map((s) => ({
        id: s.id,
        yearsExperience: s.yearsExperience,
        category: s.category,
      })),
      documents: w.documents.map((d) => ({
        id: d.id,
        type: d.type,
        fileUrl: `/api/v1/admin/workers/${w.id}/documents/${d.id}/download`,
        fileName: d.fileName,
        mimeType: d.mimeType,
        verifiedAt: d.verifiedAt,
        createdAt: d.createdAt,
      })),
      createdAt: w.createdAt,
      updatedAt: w.updatedAt,
      fullLegalName: w.fullLegalName,
      cnicNumber: w.cnicNumber,
      residentialAddress: w.residentialAddress,
      cnicFrontUrl: w.cnicFrontUrl
        ? `/api/v1/admin/workers/${w.id}/verification-documents/cnic-front/download`
        : null,
      cnicBackUrl: w.cnicBackUrl
        ? `/api/v1/admin/workers/${w.id}/verification-documents/cnic-back/download`
        : null,
      liveSelfieUrl: w.liveSelfieUrl
        ? `/api/v1/admin/workers/${w.id}/verification-documents/selfie/download`
        : null,
      faceMatchStatus: w.faceMatchStatus,
      trainingStatus: w.trainingStatus,
      onboardingStatus: w.onboardingStatus,
      legalNameConfirmedAt: w.legalNameConfirmedAt,
      generalAgreementAcceptedAt: w.generalAgreementAcceptedAt,
      tradeAgreementAcceptedAt: w.tradeAgreementAcceptedAt,
      generalAgreementVersion: w.generalAgreementVersion,
      tradeAgreementVersion: w.tradeAgreementVersion,
      submittedForReviewAt: w.submittedForReviewAt,
      changesRequiredReason: w.changesRequiredReason,
      rejectionReason: w.rejectionReason,
    };
  }

  private _extensionFor(contentType: string): string {
    return (
      {
        'image/jpeg': '.jpg',
        'image/png': '.png',
        'image/webp': '.webp',
        'image/heic': '.heic',
        'application/pdf': '.pdf',
      }[contentType] ?? ''
    );
  }
}
