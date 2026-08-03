import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AgreementType } from '@prisma/client';
import { AgreementsRepository } from './agreements.repository';
import { StorageService } from '../storage/storage.service';
import { localeFromEnum } from './source/acceptance-identity.util';
import { UstaadDocumentType } from './source/agreement-source.types';

/**
 * Read-side of the Ustaad agreement system: what an Ustaad (their own) or an
 * Admin (any worker's) may list and download.
 *
 * Two rules this file exists to keep:
 *   1. The Customer document is never listed — the repository query filters on
 *      the Ustaad types, so it cannot be reached even by guessing an id.
 *   2. The stored bucket URL never leaves the server. Downloads are streamed
 *      through an authenticated endpoint after an explicit ownership check.
 */

/** Prisma type → the stable document code the app switches on. */
const DOCUMENT_TYPE: Partial<Record<AgreementType, UstaadDocumentType>> = {
  [AgreementType.GENERAL_USTAAD]: 'USTAAD_SERVICE_PROVIDER_AGREEMENT',
  [AgreementType.TRADE_SPECIFIC]: 'TRADE_SPECIFIC_SERVICE_AGREEMENT',
  [AgreementType.BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE]:
    'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE',
};

/** One accepted document as shown in the Worker Legal section / Admin detail. */
export interface AcceptedAgreementRecordDto {
  id: string;
  acceptanceId: string | null;
  documentType: UstaadDocumentType | null;
  agreementType: AgreementType;
  title: string;
  version: string;
  agreementLocale: string;
  applicableTrade: string | null;
  acceptedAt: Date;
  viewedAt: Date | null;
  sourceDocumentHash: string | null;
  acceptedDocumentHash: string | null;
  acceptedPdfHash: string | null;
}

export interface AgreementPdfDownload {
  body: Buffer;
  contentType: string;
  /** Contains no CNIC, phone or name — only the public acceptance id. */
  fileName: string;
}

@Injectable()
export class UstaadAgreementAccessService {
  constructor(
    private readonly repository: AgreementsRepository,
    private readonly storage: StorageService,
  ) {}

  /** Every Ustaad document this worker has accepted, newest first. */
  async listForWorker(
    workerProfileId: string,
  ): Promise<AcceptedAgreementRecordDto[]> {
    const rows = await this.repository.findUstaadAcceptances(workerProfileId);
    return rows.map((r) => ({
      id: r.id,
      acceptanceId: r.acceptanceId,
      documentType: DOCUMENT_TYPE[r.agreementType] ?? null,
      agreementType: r.agreementType,
      title: r.agreementTitle,
      version: r.agreementVersion,
      // Stored as the Prisma enum; the app speaks the ur_Latn/en/ur spelling.
      agreementLocale: localeFromEnum(r.agreementLocale) ?? 'ur_Latn',
      applicableTrade: r.applicableTrade,
      acceptedAt: r.acceptedAt,
      viewedAt: r.documentViewedAt,
      sourceDocumentHash: r.sourceDocumentHash,
      acceptedDocumentHash: r.acceptedDocumentHash,
      acceptedPdfHash: r.acceptedPdfHash,
    }));
  }

  /**
   * The accepted PDF bytes for one acceptance.
   *
   * [ownerWorkerProfileId] is passed by the Ustaad-facing endpoint and omitted
   * by the Admin one. When present, a record belonging to a different worker is
   * rejected — an Ustaad can never fetch someone else's legal document by id.
   */
  async getPdf(
    acceptanceIdOrRowId: string,
    ownerWorkerProfileId?: string,
  ): Promise<AgreementPdfDownload> {
    const row = await this.repository.findAcceptanceForDownloadByAcceptanceId(
      acceptanceIdOrRowId,
    );
    if (!row) throw new NotFoundException('Agreement record not found');

    // Structurally unreachable today (nothing writes Customer rows against a
    // worker profile) but asserted anyway: this endpoint serves Ustaad
    // documents only.
    if (!DOCUMENT_TYPE[row.agreementType]) {
      throw new NotFoundException('Agreement record not found');
    }

    if (ownerWorkerProfileId && row.workerProfileId !== ownerWorkerProfileId) {
      throw new ForbiddenException('This agreement belongs to another account');
    }

    const key =
      row.acceptancePdfStorageKey ??
      (row.acceptancePdfUrl ? this.storage.keyFromUrl(row.acceptancePdfUrl) : null);
    if (!key) {
      throw new NotFoundException('Agreement PDF is not available');
    }

    const object = await this.storage.getObject(key);
    if (!object) throw new NotFoundException('Agreement PDF is not available');

    return {
      body: object.body,
      contentType: 'application/pdf',
      fileName: `handygo-agreement-${row.acceptanceId ?? row.id}.pdf`,
    };
  }
}
