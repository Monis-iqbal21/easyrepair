import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { AgreementType } from '@prisma/client';
import { AgreementsRepository } from './agreements.repository';
import { StorageService } from '../storage/storage.service';
import { generateAgreementAcceptancePdf } from '../../common/utils/agreement-pdf.util';
import {
  loadCustomerSourceText,
  CustomerAgreementSourceUnavailableError,
} from './source/customer-agreement-source.registry';
import {
  MissingAgreementDataError,
  personalizeAgreement,
} from './source/agreement-personalization.util';
import {
  generateAcceptanceId,
  localeToEnum,
  sha256Bytes,
  sha256Text,
} from './source/acceptance-identity.util';
import { CustomerDocumentType } from './source/agreement-source.types';

/**
 * Creates the ONE immutable Client agreement acceptance — the Customer Terms,
 * Booking Rules aur Privacy Notice.
 *
 * Deliberately a single-document sibling of UstaadAcceptanceService rather
 * than a widening of it: the Ustaad flow's three-document/trade-schedule
 * machinery does not apply here, and the Customer document must never be
 * reachable through the Worker flow. Every value that ends up in the
 * immutable record is resolved server-side from the authenticated account —
 * the caller supplies only checkboxAccepted and an optional device
 * descriptor.
 */

const DOCUMENT_TYPE: CustomerDocumentType =
  'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE';
const PRISMA_TYPE = AgreementType.CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE;

export interface CustomerAcceptanceInput {
  clientProfileId: string;
  userId: string;

  // Identity resolved from the authenticated profile — never re-typed.
  fullLegalName: string;
  registeredMobile: string;

  // Request context.
  ipAddress: string | null;
  deviceInfo: string | null;
  checkboxAccepted: boolean;
}

export interface AcceptedCustomerAgreementSummary {
  id: string;
  acceptanceId: string;
  documentType: CustomerDocumentType;
  agreementType: AgreementType;
  title: string;
  version: string;
  agreementLocale: string;
  sourceHash: string;
  acceptedDocumentHash: string;
  acceptedPdfHash: string;
  acceptedAt: Date;
  reused: boolean;
}

/** Structured rejection the client can act on, rather than a bare message. */
export class CustomerAgreementSubmissionError extends BadRequestException {
  constructor(
    readonly code:
      | 'NOT_ACCEPTED'
      | 'MISSING_PROFILE_DATA'
      | 'SOURCE_UNAVAILABLE',
    message: string,
    readonly details: Record<string, unknown> = {},
  ) {
    super({ error: code, code, message, details });
  }
}

@Injectable()
export class CustomerAcceptanceService {
  private readonly logger = new Logger(CustomerAcceptanceService.name);

  constructor(
    private readonly repository: AgreementsRepository,
    private readonly storage: StorageService,
  ) {}

  /**
   * Derives the Client's account id from their profile id. Stable, contains
   * no personal data, and needs no extra column.
   */
  static accountIdFor(clientProfileId: string): string {
    return `HG-CUSTOMER-${clientProfileId.replace(/-/g, '').slice(0, 10).toUpperCase()}`;
  }

  async accept(
    input: CustomerAcceptanceInput,
  ): Promise<AcceptedCustomerAgreementSummary> {
    if (input.checkboxAccepted !== true) {
      throw new CustomerAgreementSubmissionError(
        'NOT_ACCEPTED',
        'You must tick the checkbox to accept.',
      );
    }
    if (!input.fullLegalName || !input.registeredMobile) {
      throw new CustomerAgreementSubmissionError(
        'MISSING_PROFILE_DATA',
        'Your account is missing required profile information.',
        {
          missingFields: [
            !input.fullLegalName ? 'fullLegalName' : null,
            !input.registeredMobile ? 'registeredMobile' : null,
          ].filter(Boolean),
        },
      );
    }

    const source = this._loadSource();

    // Already accepted this exact version + hash — return the SAME record
    // rather than creating a second immutable legal document.
    const existing = await this.repository.findClientAcceptanceByUniqueKey(
      input.clientProfileId,
      PRISMA_TYPE,
      source.descriptor.version,
      source.sha256,
    );
    if (existing) {
      return this._toSummary(existing, true);
    }

    let uploadedUrl: string | null = null;
    try {
      const acceptedAt = new Date();
      const acceptanceId = generateAcceptanceId(acceptedAt);
      const customerAccountId = CustomerAcceptanceService.accountIdFor(
        input.clientProfileId,
      );
      const deviceSessionIpReference =
        [input.deviceInfo, input.ipAddress].filter(Boolean).join(' / ') ||
        'Not applicable';

      const personalized = personalizeAgreement(source.text, {
        fullLegalName: input.fullLegalName,
        fatherName: null,
        cnicNumber: '',
        dateOfBirth: null,
        residentialAddress: null,
        registeredMobile: input.registeredMobile,
        ustaadAccountId: '',
        mainTrade: '',
        approvedServiceTags: null,
        emergencyContact: null,
        verificationProvider: null,
        verificationRequestDate: null,
        verificationRequestReference: null,
        customerAccountId,
        acceptanceId,
        acceptedAtIso: acceptedAt.toISOString(),
        sourceDocumentHash: source.sha256,
        deviceSessionIpReference,
      });

      const acceptedDocumentHash = sha256Text(personalized.text);

      const pdf = await generateAgreementAcceptancePdf({
        acceptanceId,
        fullLegalName: input.fullLegalName,
        mobile: input.registeredMobile,
        agreementType: PRISMA_TYPE,
        agreementTitle: source.descriptor.title,
        agreementVersion: source.descriptor.version,
        agreementContent: personalized.text,
        agreementHash: source.sha256,
        acceptedAt,
        agreementLocale: 'ur_Latn',
        acceptedDocumentHash,
        ipAddress: input.ipAddress,
        deviceInfo: input.deviceInfo,
      });
      const acceptedPdfHash = sha256Bytes(pdf);

      const upload = await this.storage.uploadFile(
        pdf,
        `${DOCUMENT_TYPE.toLowerCase()}-${acceptanceId}.pdf`,
        'application/pdf',
        `uploads/client-documents/${input.clientProfileId}/agreements`,
      );
      uploadedUrl = upload.url;

      const row = await this.repository.createClientAcceptance({
        clientProfileId: input.clientProfileId,
        userId: input.userId,
        agreementTemplateId: null,
        agreementType: PRISMA_TYPE,
        agreementTitle: source.descriptor.title,
        agreementVersion: source.descriptor.version,
        agreementContentSnapshot: source.text,
        agreementHash: source.sha256,
        acceptanceId,
        agreementLocale: localeToEnum('ur_Latn'),
        sourceDocumentHash: source.sha256,
        acceptedDocumentHash,
        acceptedPdfHash,
        acceptedDocumentSnapshot: personalized.text,
        effectiveAt: acceptedAt,
        pdfMadeAvailableAt: acceptedAt,
        acceptancePdfUrl: upload.url,
        acceptancePdfStorageKey: upload.key,
        fullLegalNameSnapshot: input.fullLegalName,
        mobileSnapshot: input.registeredMobile,
        clientAccountIdSnapshot: customerAccountId,
        acceptedAt,
        ipAddress: input.ipAddress,
        deviceInfo: input.deviceInfo,
        checkboxAccepted: true,
      } as never);

      // A concurrent duplicate request may have raced us to the unique
      // constraint — createClientAcceptance returns the winner's row rather
      // than throwing, so `row` here is always the one true record either way.
      return this._toSummary(row as never, false);
    } catch (err) {
      if (uploadedUrl) {
        try {
          await this.storage.deleteByUrl(uploadedUrl);
        } catch {
          // deleteByUrl already swallows and logs; never mask the real error.
        }
        this.logger.warn(
          '[customer-acceptance] rolled back an uploaded agreement PDF after a failed acceptance',
        );
      }
      throw this._toStructuredError(err);
    }
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  private _loadSource() {
    try {
      // Roman Urdu is the only ACTIVE legal source today.
      return loadCustomerSourceText(DOCUMENT_TYPE, 'ur_Latn');
    } catch (err) {
      if (err instanceof CustomerAgreementSourceUnavailableError) {
        throw new CustomerAgreementSubmissionError(
          'SOURCE_UNAVAILABLE',
          'The approved agreement source is unavailable.',
          { documentType: DOCUMENT_TYPE, reason: err.reason },
        );
      }
      throw err;
    }
  }

  private _toSummary(
    row: {
      id: string;
      acceptanceId: string | null;
      agreementType: AgreementType;
      agreementTitle: string;
      agreementVersion: string;
      sourceDocumentHash: string | null;
      acceptedDocumentHash: string | null;
      acceptedPdfHash: string | null;
      acceptedAt: Date;
    },
    reused: boolean,
  ): AcceptedCustomerAgreementSummary {
    return {
      id: row.id,
      acceptanceId: row.acceptanceId ?? '',
      documentType: DOCUMENT_TYPE,
      agreementType: row.agreementType,
      title: row.agreementTitle,
      version: row.agreementVersion,
      agreementLocale: 'ur_Latn',
      sourceHash: row.sourceDocumentHash ?? '',
      acceptedDocumentHash: row.acceptedDocumentHash ?? '',
      acceptedPdfHash: row.acceptedPdfHash ?? '',
      acceptedAt: row.acceptedAt,
      reused,
    };
  }

  private _toStructuredError(err: unknown): unknown {
    if (err instanceof MissingAgreementDataError) {
      return new CustomerAgreementSubmissionError(
        'MISSING_PROFILE_DATA',
        'Some required profile information is missing.',
        { missingFields: err.missingFields.map((f) => f.profileField) },
      );
    }
    return err;
  }
}
