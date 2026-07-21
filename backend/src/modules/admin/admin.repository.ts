import { Injectable } from '@nestjs/common';
import {
  Prisma,
  VerificationStatus,
  WorkerOnboardingStatus,
  FaceMatchStatus,
  TrainingStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

const WORKER_PROFILE_ADMIN_INCLUDE = {
  user: { select: { id: true, phone: true } },
  skills: {
    include: {
      category: { select: { id: true, name: true } },
    },
  },
  documents: true,
} satisfies Prisma.WorkerProfileInclude;

export type WorkerProfileAdminView = Prisma.WorkerProfileGetPayload<{
  include: typeof WORKER_PROFILE_ADMIN_INCLUDE;
}>;

@Injectable()
export class AdminRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** Find all worker profiles currently awaiting an admin decision, oldest first. */
  async findPendingWorkers(): Promise<WorkerProfileAdminView[]> {
    return this.prisma.workerProfile.findMany({
      where: { onboardingStatus: WorkerOnboardingStatus.SUBMITTED_FOR_REVIEW },
      include: WORKER_PROFILE_ADMIN_INCLUDE,
      orderBy: { submittedForReviewAt: 'asc' },
    });
  }

  /** Minimal existence check before mutating a worker profile. */
  async findById(workerProfileId: string): Promise<{ id: string } | null> {
    return this.prisma.workerProfile.findUnique({
      where: { id: workerProfileId },
      select: { id: true },
    });
  }

  /** Approve — the only path to hireability. Mirrors verificationStatus for legacy readers (e.g. Flutter's isVerifiedWorker). */
  async approve(workerProfileId: string): Promise<WorkerProfileAdminView> {
    return this.prisma.workerProfile.update({
      where: { id: workerProfileId },
      data: {
        onboardingStatus: WorkerOnboardingStatus.APPROVED,
        verificationStatus: VerificationStatus.VERIFIED,
        rejectionReason: null,
        changesRequiredReason: null,
      },
      include: WORKER_PROFILE_ADMIN_INCLUDE,
    });
  }

  /** Reject with a reason — terminal unless the worker is allowed to resubmit later. */
  async reject(
    workerProfileId: string,
    reason: string,
  ): Promise<WorkerProfileAdminView> {
    return this.prisma.workerProfile.update({
      where: { id: workerProfileId },
      data: {
        onboardingStatus: WorkerOnboardingStatus.REJECTED,
        verificationStatus: VerificationStatus.REJECTED,
        rejectionReason: reason,
      },
      include: WORKER_PROFILE_ADMIN_INCLUDE,
    });
  }

  /** Send back to the worker for edits, with a reason shown in the app. */
  async requestChanges(
    workerProfileId: string,
    reason: string,
  ): Promise<WorkerProfileAdminView> {
    return this.prisma.workerProfile.update({
      where: { id: workerProfileId },
      data: {
        onboardingStatus: WorkerOnboardingStatus.CHANGES_REQUIRED,
        changesRequiredReason: reason,
      },
      include: WORKER_PROFILE_ADMIN_INCLUDE,
    });
  }

  async setFaceMatchStatus(
    workerProfileId: string,
    status: FaceMatchStatus,
  ): Promise<WorkerProfileAdminView> {
    return this.prisma.workerProfile.update({
      where: { id: workerProfileId },
      data: { faceMatchStatus: status },
      include: WORKER_PROFILE_ADMIN_INCLUDE,
    });
  }

  async setTrainingStatus(
    workerProfileId: string,
    status: TrainingStatus,
  ): Promise<WorkerProfileAdminView> {
    return this.prisma.workerProfile.update({
      where: { id: workerProfileId },
      data: { trainingStatus: status },
      include: WORKER_PROFILE_ADMIN_INCLUDE,
    });
  }
}
