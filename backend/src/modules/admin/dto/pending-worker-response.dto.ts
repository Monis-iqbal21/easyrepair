import { WorkerStatus, VerificationStatus } from '@prisma/client';

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
}
