import {
  BadRequestException,
  Injectable,
  Logger,
} from '@nestjs/common';
import { AgreementType } from '@prisma/client';
import { AgreementsRepository } from './agreements.repository';
import { StorageService } from '../storage/storage.service';
import { generateAgreementAcceptancePdf } from '../../common/utils/agreement-pdf.util';
import {
  loadSourceText,
  AgreementSourceUnavailableError,
} from './source/agreement-source.registry';
import {
  MissingAgreementDataError,
  PersonalizationData,
  personalizeAgreement,
} from './source/agreement-personalization.util';
import {
  buildIdempotencyKey,
  generateAcceptanceId,
  localeToEnum,
  sha256Bytes,
  sha256Text,
} from './source/acceptance-identity.util';
import { tradeCodeForCategoryName } from './source/trade-mapping.util';
import {
  TradeCode,
  USTAAD_DOCUMENT_TYPES,
  UstaadDocumentType,
} from './source/agreement-source.types';

/**
 * Creates the THREE immutable Ustaad agreement acceptances for one profile
 * completion.
 *
 * Deliberately separate from the legacy two-document AgreementsService so the
 * old path keeps working while this one owns the complete flow: exactly three
 * documents, Roman Urdu source, correct trade schedule, full personalization,
 * server-generated identity, idempotency, and storage cleanup on failure.
 *
 * The Customer document is structurally unreachable here: the plan is derived
 * from USTAAD_DOCUMENT_TYPES.
 */

/** The Prisma AgreementType each source document type maps to. */
const PRISMA_TYPE: Record<UstaadDocumentType, AgreementType> = {
  USTAAD_SERVICE_PROVIDER_AGREEMENT: AgreementType.GENERAL_USTAAD,
  TRADE_SPECIFIC_SERVICE_AGREEMENT: AgreementType.TRADE_SPECIFIC,
  BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE:
    AgreementType.BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE,
};

/** Per-document evidence the client must submit for each of the three rows. */
export interface AgreementAcceptanceEvidence {
  documentType: UstaadDocumentType;
  version: string;
  sourceHash: string;
  agreementLocale: string;
  applicableTrade: string | null;
  /** Null/absent when the Ustaad accepted without opening the document. */
  viewedAt?: string | null;
  checkboxAccepted: boolean;
}

export interface UstaadAcceptanceInput {
  workerProfileId: string;
  userId: string;

  // Identity resolved from the authenticated profile — never re-typed.
  fullLegalName: string | null;
  fatherName: string | null;
  cnicNumber: string | null;
  dateOfBirth: string | null;
  residentialAddress: string | null;
  registeredMobile: string | null;
  mainSkillCategoryName: string | null;
  approvedServiceTags: string[];
  emergencyContact: string | null;
  verificationProvider: string | null;
  verificationRequestDate: string | null;
  verificationRequestReference: string | null;
  cnicFrontUrl: string | null;
  cnicBackUrl: string | null;
  liveSelfieUrl: string | null;

  // Request context.
  ipAddress: string | null;
  deviceInfo: string | null;
  /** One id per submission attempt, so a retry is idempotent. */
  submissionAttemptId: string;
  evidence: AgreementAcceptanceEvidence[];
  /**
   * Applied to the WorkerProfile inside the SAME transaction as the three
   * inserts, so the profile can never be marked complete without all three
   * acceptance records existing.
   */
  profileCompletionUpdate?: Record<string, unknown>;
}

export interface AcceptedAgreementSummary {
  id: string;
  acceptanceId: string;
  documentType: UstaadDocumentType;
  agreementType: AgreementType;
  title: string;
  version: string;
  agreementLocale: string;
  applicableTrade: string | null;
  sourceHash: string;
  acceptedDocumentHash: string;
  acceptedPdfHash: string;
  acceptedAt: Date;
  reused: boolean;
}

/** Structured rejection the client can act on, rather than a bare message. */
export class AgreementSubmissionError extends BadRequestException {
  constructor(
    readonly code:
      | 'MISSING_PROFILE_DATA'
      | 'UNSUPPORTED_TRADE'
      | 'STALE_DOCUMENT'
      | 'NOT_ACCEPTED'
      | 'MISSING_EVIDENCE'
      | 'SOURCE_UNAVAILABLE',
    message: string,
    readonly details: Record<string, unknown> = {},
  ) {
    // `error` carries the machine code on the wire — GlobalExceptionFilter
    // passes it through verbatim, and the app switches UI on it rather than
    // on a sentence it must never parse.
    super({ error: code, code, message, details });
  }
}

@Injectable()
export class UstaadAcceptanceService {
  private readonly logger = new Logger(UstaadAcceptanceService.name);

  constructor(
    private readonly repository: AgreementsRepository,
    private readonly storage: StorageService,
  ) {}

  /**
   * Derives the Ustaad's account id from their profile id. Stable, contains no
   * personal data, and needs no extra column.
   */
  static accountIdFor(workerProfileId: string): string {
    return `HG-USTAAD-${workerProfileId.replace(/-/g, '').slice(0, 10).toUpperCase()}`;
  }

  async acceptAll(
    input: UstaadAcceptanceInput,
  ): Promise<AcceptedAgreementSummary[]> {
    const trade = this._resolveTrade(input.mainSkillCategoryName);
    const acceptedAt = new Date();

    // Everything uploaded during this attempt, so a later failure can undo it
    // rather than leaving orphaned sensitive PDFs in storage.
    const uploaded: string[] = [];
    const results: AcceptedAgreementSummary[] = [];

    try {
      // ── Phase 1: validate and build EVERYTHING before any side effect ────
      //
      // Personalization is where a missing profile field surfaces, and it only
      // surfaces on the document that actually needs it (father's name and DOB
      // appear solely in the EVS consent). Doing all three up front means a
      // late failure cannot leave the first two already written — the whole
      // submission fails with nothing created.
      const prepared: {
        documentType: UstaadDocumentType;
        docTrade: TradeCode | null;
        source: ReturnType<typeof loadSourceText>;
        idempotencyKey: string;
        existing: Awaited<
          ReturnType<AgreementsRepository['findAcceptanceByIdempotencyKey']>
        >;
        acceptanceId: string;
        personalizedText: string;
        acceptedDocumentHash: string;
        pdf: Buffer;
        acceptedPdfHash: string;
      }[] = [];

      for (const documentType of USTAAD_DOCUMENT_TYPES) {
        const isTradeDoc = documentType === 'TRADE_SPECIFIC_SERVICE_AGREEMENT';
        const docTrade = isTradeDoc ? trade : null;

        const source = this._loadSource(documentType, docTrade);
        this._assertEvidence(input.evidence, documentType, source, docTrade);

        const idempotencyKey = buildIdempotencyKey({
          workerProfileId: input.workerProfileId,
          documentType,
          documentVersion: source.descriptor.version,
          locale: 'ur_Latn',
          trade: docTrade,
          submissionAttemptId: input.submissionAttemptId,
        });

        // A retried or double-tapped submission returns the SAME record.
        const existing =
          await this.repository.findAcceptanceByIdempotencyKey(idempotencyKey);
        if (existing) {
          prepared.push({
            documentType,
            docTrade,
            source,
            idempotencyKey,
            existing,
            acceptanceId: existing.acceptanceId ?? '',
            personalizedText: '',
            acceptedDocumentHash: '',
            pdf: Buffer.alloc(0),
            acceptedPdfHash: '',
          });
          continue;
        }

        const acceptanceId = generateAcceptanceId(acceptedAt);
        const personalized = personalizeAgreement(source.text, {
          ...this._personalizationData(input, trade),
          acceptanceId,
          acceptedAtIso: acceptedAt.toISOString(),
          sourceDocumentHash: source.sha256,
        });

        const acceptedDocumentHash = sha256Text(personalized.text);

        const pdf = await generateAgreementAcceptancePdf({
          acceptanceId,
          fullLegalName: input.fullLegalName!,
          cnicNumber: input.cnicNumber!,
          mobile: input.registeredMobile!,
          agreementType: PRISMA_TYPE[documentType],
          agreementTitle: source.descriptor.title,
          agreementVersion: source.descriptor.version,
          agreementContent: personalized.text,
          agreementHash: source.sha256,
          acceptedAt,
          agreementLocale: 'ur_Latn',
          applicableTrade: docTrade,
          acceptedDocumentHash,
          ipAddress: input.ipAddress,
          deviceInfo: input.deviceInfo,
          cnicFrontUrl: input.cnicFrontUrl,
          cnicBackUrl: input.cnicBackUrl,
          liveSelfieUrl: input.liveSelfieUrl,
        });

        prepared.push({
          documentType,
          docTrade,
          source,
          idempotencyKey,
          existing: null,
          acceptanceId,
          personalizedText: personalized.text,
          acceptedDocumentHash,
          pdf,
          acceptedPdfHash: sha256Bytes(pdf),
        });
      }

      // ── Phase 2: upload every PDF (outside the transaction — S3 cannot
      // participate in it), remembering each URL so a rollback can delete it.
      const uploads = new Map<string, { url: string; key: string }>();
      for (const p of prepared) {
        if (p.existing) continue;
        const upload = await this.storage.uploadFile(
          p.pdf,
          `${p.documentType.toLowerCase()}-${p.acceptanceId}.pdf`,
          'application/pdf',
          `uploads/worker-documents/${input.workerProfileId}/agreements`,
        );
        uploaded.push(upload.url);
        uploads.set(p.documentType, upload);
      }

      // ── Phase 3: ONE transaction for all three inserts + profile completion.
      const rows = prepared
        .filter((p) => !p.existing)
        .map((p) => {
          const { documentType, docTrade, source } = p;
          const acceptanceId = p.acceptanceId;
          const acceptedDocumentHash = p.acceptedDocumentHash;
          const acceptedPdfHash = p.acceptedPdfHash;
          const upload = uploads.get(documentType)!;
          return {
          workerProfileId: input.workerProfileId,
          userId: input.userId,
          agreementTemplateId: null as never,
          agreementType: PRISMA_TYPE[documentType],
          agreementTitle: source.descriptor.title,
          agreementVersion: source.descriptor.version,
          agreementContentSnapshot: source.text,
          agreementHash: source.sha256,
          acceptanceId,
          agreementLocale: localeToEnum('ur_Latn'),
          applicableTrade: docTrade ?? undefined,
          sourceDocumentHash: source.sha256,
          acceptedDocumentHash,
          acceptedPdfHash,
          acceptedDocumentSnapshot: p.personalizedText,
          documentViewedAt: this._viewedAt(input.evidence, documentType),
          effectiveAt: acceptedAt,
          pdfMadeAvailableAt: acceptedAt,
          idempotencyKey: p.idempotencyKey,
          acceptancePdfUrl: upload.url,
          acceptancePdfStorageKey: upload.key,
          fullLegalNameSnapshot: input.fullLegalName!,
          cnicNumberSnapshot: input.cnicNumber!,
          mobileSnapshot: input.registeredMobile!,
          mainSkillSnapshot: input.mainSkillCategoryName!,
          fatherNameSnapshot: input.fatherName,
          dateOfBirthSnapshot: input.dateOfBirth,
          addressSnapshot: input.residentialAddress,
          ustaadAccountIdSnapshot: UstaadAcceptanceService.accountIdFor(
            input.workerProfileId,
          ),
          emergencyContactSnapshot: input.emergencyContact,
          approvedTradeSnapshot: trade,
          approvedServiceTagsSnapshot:
            input.approvedServiceTags.join(', ') || null,
          verificationProviderSnapshot: input.verificationProvider,
          verificationRequestRefSnapshot: input.verificationRequestReference,
          cnicFrontUrlSnapshot: input.cnicFrontUrl,
          cnicBackUrlSnapshot: input.cnicBackUrl,
          liveSelfieUrlSnapshot: input.liveSelfieUrl,
          acceptedAt,
          ipAddress: input.ipAddress,
          deviceInfo: input.deviceInfo,
          checkboxAccepted: true,
        } as never;
        });

      // Reused rows need no insert, but the profile must still complete.
      const createdRows = await this.repository.createAcceptancesAndCompleteProfile(
        rows,
        input.workerProfileId,
        input.profileCompletionUpdate ?? {},
      );

      let createdIndex = 0;
      for (const p of prepared) {
        results.push(
          p.existing
            ? this._toSummary(p.existing, p.documentType, true)
            : this._toSummary(createdRows[createdIndex++] as never, p.documentType, false),
        );
      }

      if (results.length !== USTAAD_DOCUMENT_TYPES.length) {
        throw new Error(
          `Expected ${USTAAD_DOCUMENT_TYPES.length} acceptances, produced ${results.length}`,
        );
      }

      return results;
    } catch (err) {
      // Storage and Postgres cannot share a transaction, so anything already
      // uploaded during THIS attempt is deleted. Never leave an orphaned
      // sensitive PDF behind, and never report partial success as complete.
      await this._cleanupUploads(uploaded);
      throw this._toStructuredError(err);
    }
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  private _resolveTrade(categoryName: string | null): TradeCode {
    const trade = tradeCodeForCategoryName(categoryName);
    if (!trade) {
      throw new AgreementSubmissionError(
        'UNSUPPORTED_TRADE',
        'No approved trade agreement exists for this trade.',
        { mainTrade: categoryName },
      );
    }
    return trade;
  }

  private _loadSource(documentType: UstaadDocumentType, trade: TradeCode | null) {
    try {
      // Roman Urdu is the only ACTIVE legal source today.
      return loadSourceText(documentType, 'ur_Latn', trade);
    } catch (err) {
      if (err instanceof AgreementSourceUnavailableError) {
        throw new AgreementSubmissionError(
          'SOURCE_UNAVAILABLE',
          'The approved agreement source is unavailable.',
          { documentType, reason: err.reason },
        );
      }
      throw err;
    }
  }

  /**
   * The client's checkbox is not trusted. The submitted evidence must still
   * describe the exact document the server just loaded.
   */
  private _assertEvidence(
    evidence: AgreementAcceptanceEvidence[],
    documentType: UstaadDocumentType,
    source: ReturnType<typeof loadSourceText>,
    trade: TradeCode | null,
  ): void {
    const item = evidence.find((e) => e.documentType === documentType);
    if (!item) {
      throw new AgreementSubmissionError(
        'MISSING_EVIDENCE',
        'Agreement acceptance evidence is missing.',
        { documentType },
      );
    }
    // Deliberately NOT checked: whether the document was opened. Reading is
    // offered, never required, so a missing viewedAt is a fact to record —
    // "accepted, not viewed" — not a reason to reject. The checkbox below is
    // still mandatory, and is what makes the acceptance binding.
    if (item.checkboxAccepted !== true) {
      throw new AgreementSubmissionError(
        'NOT_ACCEPTED',
        'Every agreement must be explicitly accepted.',
        { documentType },
      );
    }
    // Version / hash / locale / trade must all still match, otherwise the
    // Ustaad accepted a document that is no longer the active one.
    if (
      item.version !== source.descriptor.version ||
      item.sourceHash !== source.sha256 ||
      item.agreementLocale !== 'ur_Latn' ||
      (item.applicableTrade ?? null) !== trade
    ) {
      throw new AgreementSubmissionError(
        'STALE_DOCUMENT',
        'This agreement changed since you opened it. Please open and accept it again.',
        {
          documentType,
          expectedVersion: source.descriptor.version,
          expectedLocale: 'ur_Latn',
          expectedTrade: trade,
        },
      );
    }
  }

  /**
   * The real moment this document was opened, or null when it never was.
   *
   * Never invents a timestamp. `documentViewedAt` is the audit's answer to
   * "did this Ustaad actually read it?", so a row accepted unopened must store
   * null — a fabricated now() would make the record claim a reading that did
   * not happen. An unparseable value is treated the same way rather than
   * sealed as an Invalid Date.
   */
  private _viewedAt(
    evidence: AgreementAcceptanceEvidence[],
    documentType: UstaadDocumentType,
  ): Date | null {
    const item = evidence.find((e) => e.documentType === documentType)!;
    if (!item.viewedAt) return null;
    const parsed = new Date(item.viewedAt);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  private _personalizationData(
    input: UstaadAcceptanceInput,
    trade: TradeCode,
  ): Omit<
    PersonalizationData,
    'acceptanceId' | 'acceptedAtIso' | 'sourceDocumentHash'
  > {
    return {
      fullLegalName: input.fullLegalName ?? '',
      fatherName: input.fatherName,
      cnicNumber: input.cnicNumber ?? '',
      dateOfBirth: input.dateOfBirth,
      residentialAddress: input.residentialAddress,
      registeredMobile: input.registeredMobile ?? '',
      ustaadAccountId: UstaadAcceptanceService.accountIdFor(
        input.workerProfileId,
      ),
      mainTrade: input.mainSkillCategoryName ?? '',
      approvedServiceTags: input.approvedServiceTags.join(', ') || null,
      emergencyContact: input.emergencyContact,
      verificationProvider: input.verificationProvider,
      verificationRequestDate: input.verificationRequestDate,
      verificationRequestReference: input.verificationRequestReference,
      deviceSessionIpReference:
        [input.deviceInfo, input.ipAddress].filter(Boolean).join(' / ') ||
        'Not applicable',
      // Trade is carried through the schedule itself.
      ...(trade ? {} : {}),
    };
  }

  private _toSummary(
    row: {
      id: string;
      acceptanceId: string | null;
      agreementType: AgreementType;
      agreementTitle: string;
      agreementVersion: string;
      agreementLocale: string;
      applicableTrade: string | null;
      sourceDocumentHash: string | null;
      acceptedDocumentHash: string | null;
      acceptedPdfHash: string | null;
      acceptedAt: Date;
    },
    documentType: UstaadDocumentType,
    reused: boolean,
  ): AcceptedAgreementSummary {
    return {
      id: row.id,
      acceptanceId: row.acceptanceId ?? '',
      documentType,
      agreementType: row.agreementType,
      title: row.agreementTitle,
      version: row.agreementVersion,
      agreementLocale: 'ur_Latn',
      applicableTrade: row.applicableTrade,
      sourceHash: row.sourceDocumentHash ?? '',
      acceptedDocumentHash: row.acceptedDocumentHash ?? '',
      acceptedPdfHash: row.acceptedPdfHash ?? '',
      acceptedAt: row.acceptedAt,
      reused,
    };
  }

  private async _cleanupUploads(urls: string[]): Promise<void> {
    for (const url of urls) {
      try {
        await this.storage.deleteByUrl(url);
      } catch {
        // deleteByUrl already swallows and logs; never mask the real error.
      }
    }
    if (urls.length) {
      this.logger.warn(
        `[acceptance] rolled back ${urls.length} uploaded agreement PDF(s)`,
      );
    }
  }

  private _toStructuredError(err: unknown): unknown {
    if (err instanceof MissingAgreementDataError) {
      return new AgreementSubmissionError(
        'MISSING_PROFILE_DATA',
        'Some required profile information is missing.',
        { missingFields: err.missingFields.map((f) => f.profileField) },
      );
    }
    return err;
  }
}
