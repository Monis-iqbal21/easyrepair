import { Injectable, NotFoundException } from '@nestjs/common';
import { FaceMatchStatus, TrainingStatus } from '@prisma/client';
import { AdminRepository, WorkerProfileAdminView } from './admin.repository';
import { PendingWorkerResponseDto } from './dto/pending-worker-response.dto';
import { AdminStatsResponseDto } from './dto/admin-stats-response.dto';
import { AgreementsService } from '../agreements/agreements.service';

@Injectable()
export class AdminService {
  constructor(
    private readonly adminRepository: AdminRepository,
    private readonly agreementsService: AgreementsService,
  ) {}

  /** GET /admin/workers/:id/agreements — permanent acceptance records + PDF URLs. */
  async getWorkerAgreements(workerProfileId: string) {
    await this._ensureExists(workerProfileId);
    return this.agreementsService.listAcceptancesForWorker(workerProfileId);
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
  async getWorkerById(workerProfileId: string): Promise<PendingWorkerResponseDto> {
    const worker = await this.adminRepository.findWorkerByIdFull(workerProfileId);
    if (!worker) throw new NotFoundException('Worker profile not found');
    return this._toDto(worker);
  }

  /** GET /admin/stats — dashboard counters for the admin panel. */
  async getStats(): Promise<AdminStatsResponseDto> {
    return this.adminRepository.getStats();
  }

  /** PATCH /admin/workers/:id/approve */
  async approveWorker(workerProfileId: string): Promise<PendingWorkerResponseDto> {
    await this._ensureExists(workerProfileId);
    const updated = await this.adminRepository.approve(workerProfileId);
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
        fileUrl: d.fileUrl,
        fileName: d.fileName,
        mimeType: d.mimeType,
        verifiedAt: d.verifiedAt,
        createdAt: d.createdAt,
      })),
      createdAt: w.createdAt,
      fullLegalName: w.fullLegalName,
      cnicNumber: w.cnicNumber,
      residentialAddress: w.residentialAddress,
      cnicFrontUrl: w.cnicFrontUrl,
      cnicBackUrl: w.cnicBackUrl,
      liveSelfieUrl: w.liveSelfieUrl,
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
}
