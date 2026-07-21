import { Injectable } from '@nestjs/common';
import { AgreementType, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

const ACCEPTANCE_INCLUDE = {
  agreementTemplate: {
    select: { id: true, type: true, categoryId: true, title: true, version: true },
  },
} satisfies Prisma.AgreementAcceptanceInclude;

export type AgreementAcceptanceWithTemplate = Prisma.AgreementAcceptanceGetPayload<{
  include: typeof ACCEPTANCE_INCLUDE;
}>;

@Injectable()
export class AgreementsRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** The currently active template for a type (+ category, for TRADE_SPECIFIC). */
  async findActiveTemplate(type: AgreementType, categoryId: string | null) {
    return this.prisma.agreementTemplate.findFirst({
      where: { type, categoryId, isActive: true },
    });
  }

  /**
   * An acceptance already exists for this exact (worker, template) pair.
   * Used to avoid duplicating a permanent record when the worker re-submits
   * against a template version they already accepted.
   */
  async findAcceptance(workerProfileId: string, agreementTemplateId: string) {
    return this.prisma.agreementAcceptance.findUnique({
      where: {
        workerProfileId_agreementTemplateId: { workerProfileId, agreementTemplateId },
      },
    });
  }

  async createAcceptance(data: Prisma.AgreementAcceptanceUncheckedCreateInput) {
    return this.prisma.agreementAcceptance.create({ data });
  }

  async setAcceptancePdf(
    id: string,
    acceptancePdfUrl: string,
    acceptancePdfStorageKey: string,
  ) {
    return this.prisma.agreementAcceptance.update({
      where: { id },
      data: { acceptancePdfUrl, acceptancePdfStorageKey },
    });
  }

  /** All permanent acceptance records for a worker, newest first. Owner/admin only. */
  async findAcceptancesByWorkerProfileId(
    workerProfileId: string,
  ): Promise<AgreementAcceptanceWithTemplate[]> {
    return this.prisma.agreementAcceptance.findMany({
      where: { workerProfileId },
      include: ACCEPTANCE_INCLUDE,
      orderBy: { createdAt: 'desc' },
    });
  }

  /** Single acceptance record, scoped by id — used for owner/admin authorization checks. */
  async findAcceptanceById(id: string) {
    return this.prisma.agreementAcceptance.findUnique({ where: { id } });
  }
}
