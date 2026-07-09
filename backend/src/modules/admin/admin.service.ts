import { Injectable, NotFoundException } from '@nestjs/common';
import { VerificationStatus } from '@prisma/client';
import { AdminRepository, WorkerProfileAdminView } from './admin.repository';
import { PendingWorkerResponseDto } from './dto/pending-worker-response.dto';

@Injectable()
export class AdminService {
  constructor(private readonly adminRepository: AdminRepository) {}

  /** GET /admin/workers/pending — all worker profiles awaiting verification. */
  async getPendingWorkers(): Promise<PendingWorkerResponseDto[]> {
    const workers = await this.adminRepository.findPendingWorkers();
    return workers.map((w) => this._toDto(w));
  }

  /** PATCH /admin/workers/:id/approve */
  async approveWorker(workerProfileId: string): Promise<PendingWorkerResponseDto> {
    await this._ensureExists(workerProfileId);
    const updated = await this.adminRepository.setVerificationStatus(
      workerProfileId,
      VerificationStatus.VERIFIED,
    );
    return this._toDto(updated);
  }

  /** PATCH /admin/workers/:id/reject */
  async rejectWorker(workerProfileId: string): Promise<PendingWorkerResponseDto> {
    await this._ensureExists(workerProfileId);
    const updated = await this.adminRepository.setVerificationStatus(
      workerProfileId,
      VerificationStatus.REJECTED,
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
    };
  }
}
