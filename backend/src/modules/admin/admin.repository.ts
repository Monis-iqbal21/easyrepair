import { Injectable } from '@nestjs/common';
import {
  Prisma,
  VerificationStatus,
  WorkerOnboardingStatus,
  WorkerStatus,
  FaceMatchStatus,
  TrainingStatus,
  AccountStatus,
  Role,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ListWorkersQueryDto } from './dto/list-workers-query.dto';
import { WorkerListItemDto } from './dto/worker-list-item.dto';

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

  async findVerificationDocumentStorage(workerProfileId: string): Promise<{
    cnicFrontUrl: string | null;
    cnicFrontStorageKey: string | null;
    cnicBackUrl: string | null;
    cnicBackStorageKey: string | null;
    liveSelfieUrl: string | null;
    liveSelfieStorageKey: string | null;
  } | null> {
    return this.prisma.workerProfile.findUnique({
      where: { id: workerProfileId },
      select: {
        cnicFrontUrl: true,
        cnicFrontStorageKey: true,
        cnicBackUrl: true,
        cnicBackStorageKey: true,
        liveSelfieUrl: true,
        liveSelfieStorageKey: true,
      },
    });
  }

  async findWorkerDocumentStorage(
    workerProfileId: string,
    documentId: string,
  ): Promise<{
    fileUrl: string;
    storageKey: string | null;
    fileName: string | null;
    mimeType: string | null;
  } | null> {
    return this.prisma.workerDocument.findFirst({
      where: { id: documentId, workerProfileId },
      select: {
        fileUrl: true,
        storageKey: true,
        fileName: true,
        mimeType: true,
      },
    });
  }

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

  /**
   * Full admin detail view of a single worker, regardless of onboarding
   * stage — used by the detail page even after approve/reject/changes.
   */
  async findWorkerByIdFull(
    workerProfileId: string,
  ): Promise<WorkerProfileAdminView | null> {
    return this.prisma.workerProfile.findUnique({
      where: { id: workerProfileId },
      include: WORKER_PROFILE_ADMIN_INCLUDE,
    });
  }

  /**
   * GET /admin/workers — paginated, searchable, filterable Ustaads List.
   * WorkerProfile only ever exists for Role.WORKER users (1:1 relation), so
   * CLIENT accounts are structurally excluded — there is nothing to filter.
   */
  async findWorkersPaginated(
    query: ListWorkersQueryDto,
  ): Promise<{ items: WorkerListItemDto[]; total: number }> {
    const where: Prisma.WorkerProfileWhereInput = {};

    if (query.status) where.status = query.status;
    if (query.onboardingStatus) where.onboardingStatus = query.onboardingStatus;
    if (query.verificationStatus)
      where.verificationStatus = query.verificationStatus;
    if (query.categoryId) {
      where.skills = { some: { categoryId: query.categoryId } };
    }

    const term = query.search?.trim();
    if (term) {
      where.OR = [
        { firstName: { contains: term, mode: 'insensitive' } },
        { lastName: { contains: term, mode: 'insensitive' } },
        { cnicNumber: { contains: term, mode: 'insensitive' } },
        { user: { phone: { contains: term, mode: 'insensitive' } } },
      ];
    }

    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? 20;

    const [rows, total] = await Promise.all([
      this.prisma.workerProfile.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * pageSize,
        take: pageSize,
        include: {
          user: { select: { phone: true } },
          skills: {
            include: { category: { select: { id: true, name: true } } },
          },
        },
      }),
      this.prisma.workerProfile.count({ where }),
    ]);

    const items: WorkerListItemDto[] = rows.map((w) => ({
      id: w.id,
      firstName: w.firstName,
      lastName: w.lastName,
      phone: w.user.phone,
      avatarUrl: w.avatarUrl,
      primarySkill: w.skills[0]?.category.name ?? null,
      status: w.status,
      onboardingStatus: w.onboardingStatus,
      verificationStatus: w.verificationStatus,
      createdAt: w.createdAt,
    }));

    return { items, total };
  }

  /** PATCH /admin/workers/:id/status — the single mechanism that flips WorkerStatus. */
  async updateStatus(
    workerProfileId: string,
    status: WorkerStatus,
  ): Promise<WorkerProfileAdminView> {
    return this.prisma.workerProfile.update({
      where: { id: workerProfileId },
      data: { status },
      include: WORKER_PROFILE_ADMIN_INCLUDE,
    });
  }

  /** PATCH /admin/workers/:id — operational profile field edits (see UpdateWorkerProfileDto). */
  async updateProfile(
    workerProfileId: string,
    data: Prisma.WorkerProfileUpdateInput,
  ): Promise<WorkerProfileAdminView> {
    return this.prisma.workerProfile.update({
      where: { id: workerProfileId },
      data,
      include: WORKER_PROFILE_ADMIN_INCLUDE,
    });
  }

  async findCategoriesByIds(ids: string[]): Promise<{ id: string }[]> {
    return this.prisma.serviceCategory.findMany({
      where: { id: { in: ids }, isActive: true },
      select: { id: true },
    });
  }

  /**
   * Replace all skills for a worker. Mirrors
   * WorkersRepository.replaceSkills exactly (including the profileCompleted
   * projection, which job-eligibility.util reads) so an admin skill edit can
   * never diverge from what the worker's own app would produce.
   */
  async replaceSkills(
    workerProfileId: string,
    categoryIds: string[],
    yearsExperience?: number,
  ): Promise<WorkerProfileAdminView> {
    return this.prisma.$transaction(async (tx) => {
      await tx.workerSkill.deleteMany({ where: { workerProfileId } });

      await tx.workerSkill.createMany({
        data: categoryIds.map((categoryId) => ({
          workerProfileId,
          categoryId,
          ...(yearsExperience !== undefined ? { yearsExperience } : {}),
        })),
      });

      await tx.workerProfile.update({
        where: { id: workerProfileId },
        data: { profileCompleted: categoryIds.length === 1 },
      });

      return tx.workerProfile.findUniqueOrThrow({
        where: { id: workerProfileId },
        include: WORKER_PROFILE_ADMIN_INCLUDE,
      });
    });
  }

  /** Dashboard counters for the admin panel. */
  async getStats(): Promise<{
    pendingUstaads: number;
    approvedUstaads: number;
    rejectedUstaads: number;
    changesRequiredUstaads: number;
    totalWorkers: number;
    totalUsers: number;
  }> {
    const [
      pendingUstaads,
      approvedUstaads,
      rejectedUstaads,
      changesRequiredUstaads,
      totalWorkers,
      totalUsers,
    ] = await Promise.all([
      this.prisma.workerProfile.count({
        where: {
          onboardingStatus: WorkerOnboardingStatus.SUBMITTED_FOR_REVIEW,
        },
      }),
      this.prisma.workerProfile.count({
        where: { onboardingStatus: WorkerOnboardingStatus.APPROVED },
      }),
      this.prisma.workerProfile.count({
        where: { onboardingStatus: WorkerOnboardingStatus.REJECTED },
      }),
      this.prisma.workerProfile.count({
        where: { onboardingStatus: WorkerOnboardingStatus.CHANGES_REQUIRED },
      }),
      this.prisma.workerProfile.count(),
      this.prisma.user.count(),
    ]);

    return {
      pendingUstaads,
      approvedUstaads,
      rejectedUstaads,
      changesRequiredUstaads,
      totalWorkers,
      totalUsers,
    };
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

  async findUserRoleAndStatusById(userId: string): Promise<{
    id: string;
    role: Role;
    accountStatus: AccountStatus;
    deletedAt: Date | null;
  } | null> {
    return this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true, accountStatus: true, deletedAt: true },
    });
  }

  async updateAccountStatus(
    userId: string,
    status: AccountStatus,
  ): Promise<{ id: string; accountStatus: AccountStatus; updatedAt: Date }> {
    return this.prisma.user.update({
      where: { id: userId },
      data: { accountStatus: status },
      select: { id: true, accountStatus: true, updatedAt: true },
    });
  }
}
