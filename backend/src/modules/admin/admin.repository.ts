import { Injectable } from '@nestjs/common';
import { Prisma, VerificationStatus } from '@prisma/client';
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

  /** Find all worker profiles awaiting verification, oldest first. */
  async findPendingWorkers(): Promise<WorkerProfileAdminView[]> {
    return this.prisma.workerProfile.findMany({
      where: { verificationStatus: VerificationStatus.PENDING },
      include: WORKER_PROFILE_ADMIN_INCLUDE,
      orderBy: { createdAt: 'asc' },
    });
  }

  /** Minimal existence check before mutating a worker profile. */
  async findById(workerProfileId: string): Promise<{ id: string } | null> {
    return this.prisma.workerProfile.findUnique({
      where: { id: workerProfileId },
      select: { id: true },
    });
  }

  /** Set verificationStatus and return the updated profile with relations. */
  async setVerificationStatus(
    workerProfileId: string,
    status: VerificationStatus,
  ): Promise<WorkerProfileAdminView> {
    return this.prisma.workerProfile.update({
      where: { id: workerProfileId },
      data: { verificationStatus: status },
      include: WORKER_PROFILE_ADMIN_INCLUDE,
    });
  }
}
