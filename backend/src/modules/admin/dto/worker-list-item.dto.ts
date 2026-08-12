import {
  WorkerStatus,
  VerificationStatus,
  WorkerOnboardingStatus,
} from '@prisma/client';

/** One row of GET /admin/workers — summary fields only, not the full detail view. */
export class WorkerListItemDto {
  id: string;
  firstName: string;
  lastName: string;
  phone: string;
  avatarUrl: string | null;
  primarySkill: string | null;
  status: WorkerStatus;
  onboardingStatus: WorkerOnboardingStatus;
  verificationStatus: VerificationStatus;
  createdAt: Date;
}

export class PaginationMetaDto {
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}

export class PaginatedWorkersDto {
  items: WorkerListItemDto[];
  meta: PaginationMetaDto;
}
