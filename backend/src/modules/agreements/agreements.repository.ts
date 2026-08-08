import { Injectable } from '@nestjs/common';
import { AgreementType, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * The only agreement types an Ustaad ever accepts.
 *
 * Every Ustaad-facing and Admin-facing read filters on this list, so the
 * Customer document can never appear in an Ustaad's legal history even if a
 * future flow starts writing CUSTOMER_TERMS_* rows against a User.
 */
export const USTAAD_AGREEMENT_TYPES: AgreementType[] = [
  AgreementType.GENERAL_USTAAD,
  AgreementType.TRADE_SPECIFIC,
  AgreementType.BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE,
];

/**
 * The only agreement type a Client ever accepts. Mirrors
 * USTAAD_AGREEMENT_TYPES — every Client-facing and Admin-facing read filters
 * on this list, so a Worker document can never appear in a Client's history.
 */
export const CLIENT_AGREEMENT_TYPES: AgreementType[] = [
  AgreementType.CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE,
];

/** Postgres unique-violation error code, used for the idempotent-insert race. */
const UNIQUE_VIOLATION = 'P2002';

/**
 * Everything the Worker/Client/Admin agreement screens render — deliberately
 * WITHOUT acceptancePdfUrl, so no code path can leak the bucket URL into a
 * response.
 */
const ACCEPTANCE_METADATA_SELECT = {
  id: true,
  acceptanceId: true,
  workerProfileId: true,
  clientProfileId: true,
  userId: true,
  agreementType: true,
  agreementTitle: true,
  agreementVersion: true,
  agreementLocale: true,
  applicableTrade: true,
  sourceDocumentHash: true,
  acceptedDocumentHash: true,
  acceptedPdfHash: true,
  documentViewedAt: true,
  acceptedAt: true,
  createdAt: true,
} satisfies Prisma.AgreementAcceptanceSelect;

export type AcceptanceMetadataRow = Prisma.AgreementAcceptanceGetPayload<{
  select: typeof ACCEPTANCE_METADATA_SELECT;
}>;

const ACCEPTANCE_INCLUDE = {
  agreementTemplate: {
    select: {
      id: true,
      type: true,
      categoryId: true,
      title: true,
      version: true,
    },
  },
} satisfies Prisma.AgreementAcceptanceInclude;

export type AgreementAcceptanceWithTemplate =
  Prisma.AgreementAcceptanceGetPayload<{
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
        workerProfileId_agreementTemplateId: {
          workerProfileId,
          agreementTemplateId,
        },
      },
    });
  }

  async createAcceptance(data: Prisma.AgreementAcceptanceUncheckedCreateInput) {
    return this.prisma.agreementAcceptance.create({ data });
  }

  /**
   * The record produced by a specific submission attempt, if it already ran.
   *
   * This is what makes a double tap or a network retry idempotent: the same
   * (worker, document, version, locale, trade, attempt) hashes to the same key,
   * so the caller returns the existing immutable record instead of creating a
   * second legal document.
   */
  async findAcceptanceByIdempotencyKey(idempotencyKey: string) {
    return this.prisma.agreementAcceptance.findUnique({
      where: { idempotencyKey },
    });
  }

  /**
   * Creates all three acceptance rows AND marks the profile complete in ONE
   * transaction, so a failure on the third document cannot leave the first two
   * committed or the profile falsely marked complete.
   *
   * Rows already produced by this submission attempt (same idempotency key)
   * are reused rather than re-created, which is what makes a retry safe.
   */
  async createAcceptancesAndCompleteProfile(
    rows: Prisma.AgreementAcceptanceUncheckedCreateInput[],
    workerProfileId: string,
    profileUpdate: Prisma.WorkerProfileUncheckedUpdateInput,
  ) {
    return this.prisma.$transaction(async (tx) => {
      const created: Prisma.AgreementAcceptanceGetPayload<object>[] = [];
      for (const data of rows) {
        const existing = data.idempotencyKey
          ? await tx.agreementAcceptance.findUnique({
              where: { idempotencyKey: data.idempotencyKey },
            })
          : null;
        created.push(existing ?? (await tx.agreementAcceptance.create({ data })));
      }

      // Guard inside the transaction: if this ever produced fewer than the
      // required three, the whole thing rolls back rather than completing a
      // profile with missing legal evidence.
      if (created.length !== rows.length) {
        throw new Error('Acceptance count mismatch — rolling back');
      }

      await tx.workerProfile.update({
        where: { id: workerProfileId },
        data: profileUpdate,
      });

      return created;
    });
  }

  /** Owner/admin-scoped single record, including its storage key for download. */
  async findAcceptanceForDownload(id: string) {
    return this.prisma.agreementAcceptance.findUnique({
      where: { id },
      select: {
        id: true,
        acceptanceId: true,
        workerProfileId: true,
        clientProfileId: true,
        userId: true,
        agreementType: true,
        agreementTitle: true,
        agreementVersion: true,
        agreementLocale: true,
        applicableTrade: true,
        acceptancePdfStorageKey: true,
        acceptancePdfUrl: true,
        acceptedPdfHash: true,
      },
    });
  }

  /**
   * The same record addressed by its PUBLIC acceptance id (HG-ACC-…), which is
   * what the app and the PDF both show. Falls back to the row id so an older
   * record without a public id is still reachable by its own identifier.
   */
  async findAcceptanceForDownloadByAcceptanceId(acceptanceId: string) {
    const byPublicId = await this.prisma.agreementAcceptance.findUnique({
      where: { acceptanceId },
      select: {
        id: true,
        acceptanceId: true,
        workerProfileId: true,
        clientProfileId: true,
        userId: true,
        agreementType: true,
        agreementTitle: true,
        agreementVersion: true,
        agreementLocale: true,
        applicableTrade: true,
        acceptancePdfStorageKey: true,
        acceptancePdfUrl: true,
        acceptedPdfHash: true,
      },
    });
    return byPublicId ?? this.findAcceptanceForDownload(acceptanceId);
  }

  /**
   * Ustaad-only acceptance metadata for one worker, newest first.
   *
   * Customer documents are excluded at the query level rather than filtered
   * afterwards, and acceptancePdfUrl is not selected at all.
   */
  async findUstaadAcceptances(
    workerProfileId: string,
  ): Promise<AcceptanceMetadataRow[]> {
    return this.prisma.agreementAcceptance.findMany({
      where: {
        workerProfileId,
        agreementType: { in: USTAAD_AGREEMENT_TYPES },
      },
      select: ACCEPTANCE_METADATA_SELECT,
      orderBy: { acceptedAt: 'desc' },
    });
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

  /** Resolves the authenticated Client's own profile — never trusts a client-supplied id. */
  async findClientProfileByUserId(userId: string) {
    return this.prisma.clientProfile.findUnique({ where: { userId } });
  }

  /** Admin-only existence check for a client profile id from the URL path. */
  async findClientProfileById(clientProfileId: string) {
    return this.prisma.clientProfile.findUnique({
      where: { id: clientProfileId },
    });
  }

  /**
   * Client-only acceptance metadata for one client, newest first.
   *
   * Worker documents are excluded at the query level rather than filtered
   * afterwards, and acceptancePdfUrl is not selected at all.
   */
  async findClientAcceptances(
    clientProfileId: string,
  ): Promise<AcceptanceMetadataRow[]> {
    return this.prisma.agreementAcceptance.findMany({
      where: {
        clientProfileId,
        agreementType: { in: CLIENT_AGREEMENT_TYPES },
      },
      select: ACCEPTANCE_METADATA_SELECT,
      orderBy: { acceptedAt: 'desc' },
    });
  }

  /**
   * The already-sealed acceptance for this exact (client, type, version,
   * hash), if one exists — the read-side half of the idempotency guard.
   */
  async findClientAcceptanceByUniqueKey(
    clientProfileId: string,
    agreementType: AgreementType,
    agreementVersion: string,
    agreementHash: string,
  ) {
    return this.prisma.agreementAcceptance.findUnique({
      where: {
        clientProfileId_agreementType_agreementVersion_agreementHash: {
          clientProfileId,
          agreementType,
          agreementVersion,
          agreementHash,
        },
      },
    });
  }

  /**
   * Creates one Client acceptance row. Relies on the DB unique constraint
   * `(clientProfileId, agreementType, agreementVersion, agreementHash)` as the
   * authoritative idempotency guard: if a concurrent request already inserted
   * the same row between the caller's read-check and this write, Postgres
   * rejects the duplicate insert and the existing row is returned instead of
   * a second immutable legal document being created.
   */
  async createClientAcceptance(
    data: Prisma.AgreementAcceptanceUncheckedCreateInput,
  ) {
    try {
      return await this.prisma.agreementAcceptance.create({ data });
    } catch (err) {
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === UNIQUE_VIOLATION &&
        data.clientProfileId &&
        data.agreementType &&
        data.agreementVersion &&
        data.agreementHash
      ) {
        const existing = await this.findClientAcceptanceByUniqueKey(
          data.clientProfileId,
          data.agreementType,
          data.agreementVersion,
          data.agreementHash,
        );
        if (existing) return existing;
      }
      throw err;
    }
  }
}
