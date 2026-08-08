import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AgreementType } from '@prisma/client';
import { AgreementsRepository } from './agreements.repository';
import { StorageService } from '../storage/storage.service';
import { localeFromEnum } from './source/acceptance-identity.util';
import { CustomerDocumentType } from './source/agreement-source.types';

/**
 * Read-side of the Client agreement system: what a Client (their own) or an
 * Admin (any client's) may list and download. Mirrors
 * UstaadAgreementAccessService — see that file for the two rules this keeps:
 * the Worker documents are never listed here, and the stored bucket URL
 * never leaves the server.
 */

const DOCUMENT_TYPE: Partial<Record<AgreementType, CustomerDocumentType>> = {
  [AgreementType.CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE]:
    'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
};

/** One accepted document as shown in the Client Profile / Admin detail. */
export interface AcceptedCustomerAgreementRecordDto {
  id: string;
  acceptanceId: string | null;
  documentType: CustomerDocumentType | null;
  agreementType: AgreementType;
  title: string;
  version: string;
  agreementLocale: string;
  acceptedAt: Date;
  sourceDocumentHash: string | null;
  acceptedDocumentHash: string | null;
  acceptedPdfHash: string | null;
}

export interface AgreementPdfDownload {
  body: Buffer;
  contentType: string;
  /** Contains no phone or name — only the public acceptance id. */
  fileName: string;
}

@Injectable()
export class CustomerAgreementAccessService {
  constructor(
    private readonly repository: AgreementsRepository,
    private readonly storage: StorageService,
  ) {}

  /** Every Customer document this client has accepted, newest first. */
  async listForClient(
    clientProfileId: string,
  ): Promise<AcceptedCustomerAgreementRecordDto[]> {
    const rows = await this.repository.findClientAcceptances(clientProfileId);
    return rows.map((r) => ({
      id: r.id,
      acceptanceId: r.acceptanceId,
      documentType: DOCUMENT_TYPE[r.agreementType] ?? null,
      agreementType: r.agreementType,
      title: r.agreementTitle,
      version: r.agreementVersion,
      agreementLocale: localeFromEnum(r.agreementLocale) ?? 'ur_Latn',
      acceptedAt: r.acceptedAt,
      sourceDocumentHash: r.sourceDocumentHash,
      acceptedDocumentHash: r.acceptedDocumentHash,
      acceptedPdfHash: r.acceptedPdfHash,
    }));
  }

  /**
   * The accepted PDF bytes for one acceptance.
   *
   * [ownerClientProfileId] is passed by the Client-facing endpoint and
   * omitted by the Admin one. When present, a record belonging to a
   * different client is rejected — a Client can never fetch someone else's
   * legal document by id.
   */
  async getPdf(
    acceptanceIdOrRowId: string,
    ownerClientProfileId?: string,
  ): Promise<AgreementPdfDownload> {
    const row = await this.repository.findAcceptanceForDownloadByAcceptanceId(
      acceptanceIdOrRowId,
    );
    if (!row) throw new NotFoundException('Agreement record not found');

    // This endpoint serves Customer documents only — a Worker acceptance id
    // is never reachable here, even by guessing.
    if (!DOCUMENT_TYPE[row.agreementType]) {
      throw new NotFoundException('Agreement record not found');
    }

    if (
      ownerClientProfileId &&
      row.clientProfileId !== ownerClientProfileId
    ) {
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
