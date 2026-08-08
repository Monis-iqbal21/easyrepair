/**
 * Stable identifiers for the Ustaad agreement system.
 *
 * Every one of these is a backend code, never a translated label. Nothing in
 * this file may be selected by comparing UI text — a schedule is chosen by
 * TradeCode, a language by AgreementLocale.
 */

/** Matches the app's existing locale values exactly (see AppLocale.storageValue). */
export const AGREEMENT_LOCALES = ['en', 'ur', 'ur_Latn'] as const;
export type AgreementLocale = (typeof AGREEMENT_LOCALES)[number];

/**
 * Trades with an approved schedule. Mapped from ServiceCategory by stable
 * code, never by display name, so renaming a category in the admin panel can
 * never silently switch which legal schedule an Ustaad accepts.
 */
export const TRADE_CODES = [
  'ELECTRICIAN',
  'PLUMBER',
  'AC_TECHNICIAN',
  'CARPENTER',
] as const;
export type TradeCode = (typeof TRADE_CODES)[number];

/**
 * The four approved document types.
 *
 * CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE is declared so the type system
 * knows it exists, but it is excluded from USTAAD_DOCUMENT_TYPES and must
 * never enter the Ustaad flow.
 */
export const DOCUMENT_TYPES = [
  'USTAAD_SERVICE_PROVIDER_AGREEMENT',
  'TRADE_SPECIFIC_SERVICE_AGREEMENT',
  'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE',
  'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
] as const;
export type AgreementDocumentType = (typeof DOCUMENT_TYPES)[number];

/**
 * Exactly the three documents an Ustaad accepts during profile completion.
 * The Customer document is deliberately absent and every Ustaad-flow code
 * path derives its list from here rather than from DOCUMENT_TYPES.
 */
export const USTAAD_DOCUMENT_TYPES = [
  'USTAAD_SERVICE_PROVIDER_AGREEMENT',
  'TRADE_SPECIFIC_SERVICE_AGREEMENT',
  'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE',
] as const satisfies readonly AgreementDocumentType[];
export type UstaadDocumentType = (typeof USTAAD_DOCUMENT_TYPES)[number];

export function isUstaadDocumentType(
  value: string,
): value is UstaadDocumentType {
  return (USTAAD_DOCUMENT_TYPES as readonly string[]).includes(value);
}

/**
 * Exactly the one document a Client accepts. Kept as its own list (rather
 * than "everything not Ustaad") so a future fifth document type must be
 * deliberately added here before any Client-flow code can see it.
 */
export const CUSTOMER_DOCUMENT_TYPES = [
  'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
] as const satisfies readonly AgreementDocumentType[];
export type CustomerDocumentType = (typeof CUSTOMER_DOCUMENT_TYPES)[number];

export function isCustomerDocumentType(
  value: string,
): value is CustomerDocumentType {
  return (CUSTOMER_DOCUMENT_TYPES as readonly string[]).includes(value);
}

/**
 * Lifecycle of one document-language version.
 *
 *  - ACTIVE              may be viewed and accepted.
 *  - PENDING_TRANSLATION declared and expected, but its legal text does not
 *                        exist yet. Never viewable, never acceptable. This is
 *                        how en/ur are held until HandyGo's legal team
 *                        supplies certified text: the system knows the
 *                        variant is coming without ever letting an Ustaad be
 *                        bound by unverified wording.
 *  - DRAFT               text exists but has not been legally signed off.
 *  - RETIRED             superseded; still readable for historical evidence.
 */
export const SOURCE_STATUSES = [
  'ACTIVE',
  'PENDING_TRANSLATION',
  'DRAFT',
  'RETIRED',
] as const;
export type AgreementSourceStatus = (typeof SOURCE_STATUSES)[number];

/** Only ACTIVE may be shown to, or accepted by, an Ustaad. */
export function isAcceptable(status: AgreementSourceStatus): boolean {
  return status === 'ACTIVE';
}

/** One declared document-language(-trade) version in the registry. */
export interface AgreementSourceDescriptor {
  documentType: UstaadDocumentType;
  locale: AgreementLocale;
  /** Only set for TRADE_SPECIFIC_SERVICE_AGREEMENT; null otherwise. */
  trade: TradeCode | null;
  title: string;
  version: string;
  /**
   * Bumped only when clause identifiers/ordering change. Language variants
   * of the same legal content share this, which is what clause-parity
   * validation compares across locales.
   */
  clauseStructureVersion: string;
  status: AgreementSourceStatus;
  /** Committed canonical text file; null while PENDING_TRANSLATION. */
  file: string | null;
  /** SHA-256 of the canonical text; null while PENDING_TRANSLATION. */
  sha256: string | null;
  /** The approved PDF this text was ingested from, for provenance. */
  originalFilename: string;
}

/** Stable registry key. */
export function sourceKey(
  documentType: UstaadDocumentType,
  locale: AgreementLocale,
  trade: TradeCode | null,
): string {
  return trade
    ? `${documentType}:${trade}:${locale}`
    : `${documentType}:${locale}`;
}
