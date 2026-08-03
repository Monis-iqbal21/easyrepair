import { createHash, randomUUID } from 'node:crypto';
import {
  AgreementLocale,
  TradeCode,
  UstaadDocumentType,
} from './agreement-source.types';

/**
 * Server-side generation of every value a client must never be trusted to
 * supply: acceptance identifiers, timestamps, hashes and idempotency keys.
 */

/** SHA-256 over UTF-8 text — the one hashing function for agreements. */
export function sha256Text(text: string): string {
  return createHash('sha256').update(text, 'utf8').digest('hex');
}

/** SHA-256 over raw bytes, for generated PDF buffers. */
export function sha256Bytes(bytes: Buffer): string {
  return createHash('sha256').update(bytes).digest('hex');
}

/**
 * Public acceptance identifier printed on the PDF and quoted in support.
 *
 * Deliberately not a raw UUID: it is read aloud and typed by humans. Contains
 * no personal data — never derive it from CNIC, phone or name.
 */
export function generateAcceptanceId(now: Date = new Date()): string {
  const year = now.getUTCFullYear();
  const random = randomUUID().replace(/-/g, '').slice(0, 12).toUpperCase();
  return `HG-ACC-${year}-${random}`;
}

export interface IdempotencyScope {
  workerProfileId: string;
  documentType: UstaadDocumentType;
  documentVersion: string;
  locale: AgreementLocale;
  trade: TradeCode | null;
  /**
   * Distinguishes a deliberate NEW acceptance from a retry of the same one.
   * A retried network request reuses the same value and must return the
   * existing record; a genuinely new acceptance (new version, or re-accepting
   * after a language change) uses a new one.
   */
  submissionAttemptId: string;
}

/**
 * Stable key for "this exact acceptance attempt".
 *
 * Hashed rather than concatenated so the stored value has a fixed length and
 * leaks no identifiers, while still being deterministic for a genuine retry.
 */
export function buildIdempotencyKey(scope: IdempotencyScope): string {
  const parts = [
    scope.workerProfileId,
    scope.documentType,
    scope.documentVersion,
    scope.locale,
    scope.trade ?? 'NO_TRADE',
    scope.submissionAttemptId,
  ];
  return sha256Text(parts.join('|'));
}

/**
 * Maps the app's locale string to the Prisma enum value, and back.
 *
 * The app's `ur_Latn` and Prisma's `UR_LATN` are the same language; keeping
 * the conversion in one place stops a stray `.toUpperCase()` from inventing
 * a third spelling.
 */
const LOCALE_TO_ENUM = {
  en: 'EN',
  ur: 'UR',
  ur_Latn: 'UR_LATN',
} as const satisfies Record<AgreementLocale, string>;

const ENUM_TO_LOCALE = {
  EN: 'en',
  UR: 'ur',
  UR_LATN: 'ur_Latn',
} as const;

export type AgreementLocaleEnum = (typeof LOCALE_TO_ENUM)[AgreementLocale];

export function localeToEnum(locale: AgreementLocale): AgreementLocaleEnum {
  return LOCALE_TO_ENUM[locale];
}

export function localeFromEnum(value: string): AgreementLocale | null {
  return (ENUM_TO_LOCALE as Record<string, AgreementLocale>)[value] ?? null;
}

/**
 * Parses a client-supplied locale string, rejecting anything unknown.
 * The caller decides the acceptance locale from the app language, but the
 * server still validates it rather than trusting the wire value.
 */
export function parseAgreementLocale(value: unknown): AgreementLocale | null {
  if (typeof value !== 'string') return null;
  return value in LOCALE_TO_ENUM ? (value as AgreementLocale) : null;
}
