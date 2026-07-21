import {
  WorkerStatus,
  VerificationStatus,
  WorkerOnboardingStatus,
  FaceMatchStatus,
  TrainingStatus,
} from '@prisma/client';

export class WorkerSkillDto {
  id: string;
  yearsExperience: number;
  category: { id: string; name: string };
}

export class WorkerDocumentDto {
  id: string;
  type: string;
  fileUrl: string;
  fileName: string | null;
  mimeType: string | null;
  verifiedAt: Date | null;
  createdAt: Date;
}

/**
 * Admin-only view of a worker's onboarding submission. This is the one place
 * CNIC/selfie URLs are legitimately exposed — never return these fields from
 * any client- or other-worker-facing endpoint (booking/job/bid DTOs).
 */
export class PendingWorkerResponseDto {
  id: string;
  userId: string;
  phone: string;
  firstName: string;
  lastName: string;
  bio: string | null;
  avatarUrl: string | null;
  status: WorkerStatus;
  verificationStatus: VerificationStatus;
  skills: WorkerSkillDto[];
  documents: WorkerDocumentDto[];
  createdAt: Date;

  // ── Onboarding submission ─────────────────────────────────────────────
  fullLegalName: string | null;
  residentialAddress: string | null;
  cnicFrontUrl: string | null;
  cnicBackUrl: string | null;
  liveSelfieUrl: string | null;
  faceMatchStatus: FaceMatchStatus;
  trainingStatus: TrainingStatus;
  onboardingStatus: WorkerOnboardingStatus;
  legalNameConfirmedAt: Date | null;
  generalAgreementAcceptedAt: Date | null;
  tradeAgreementAcceptedAt: Date | null;
  generalAgreementVersion: string | null;
  tradeAgreementVersion: string | null;
  submittedForReviewAt: Date | null;
  changesRequiredReason: string | null;
  rejectionReason: string | null;
}
