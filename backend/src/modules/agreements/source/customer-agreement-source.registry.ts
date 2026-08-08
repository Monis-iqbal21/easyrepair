import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import {
  AGREEMENT_LOCALES,
  AgreementLocale,
  AgreementSourceStatus,
  CUSTOMER_DOCUMENT_TYPES,
  CustomerDocumentType,
  isAcceptable,
} from './agreement-source.types';

/**
 * THE registry of the approved Customer agreement source document.
 *
 * Deliberately a separate, much smaller sibling of agreement-source.registry.ts
 * (the Ustaad registry) rather than a widening of it: the Ustaad registry's
 * typing, trade-schedule handling and extensive test suite are Ustaad-only by
 * design, and the Customer document has no trade schedules to split. This
 * file reuses the same canonicalisation/hash-pinning approach so the
 * guarantee is identical — production reads only the committed canonical
 * .txt file next to this file, verified against a pinned SHA-256 on every
 * read, never the original PDF.
 *
 * Regenerate the text with `node scripts/ingest-customer-agreement-source.mjs`.
 *
 * en and ur are PENDING_TRANSLATION for the same reason as the Ustaad
 * documents — see that registry's file header. The approved source exists in
 * Roman Urdu only until HandyGo's legal team supplies certified text.
 */
const DOCUMENTS_DIR = path.join(__dirname, 'customer-documents');

const VERSION = '1.0';

const TITLE = 'HandyGo Customer Terms, Booking Rules aur Privacy Notice';
const ORIGINAL_PDF =
  'HANDYGO CUSTOMER TERMS, BOOKING RULES AUR PRIVACY NOTICE.pdf';

/** SHA-256 of the committed canonical file, pinned at ingestion time. */
const ROMAN_URDU_HASHES: Record<string, string> = {
  'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE.ur_Latn.txt':
    '53788a7dc6834c4cb8bcb413a753941ae02a32773fda001a9325056a3e189b09',
};

export interface CustomerAgreementSourceDescriptor {
  documentType: CustomerDocumentType;
  locale: AgreementLocale;
  title: string;
  version: string;
  status: AgreementSourceStatus;
  /** Committed canonical text file; null while PENDING_TRANSLATION. */
  file: string | null;
  /** SHA-256 of the canonical text; null while PENDING_TRANSLATION. */
  sha256: string | null;
  /** The approved PDF this text was ingested from, for provenance. */
  originalFilename: string;
}

function describe(
  documentType: CustomerDocumentType,
  locale: AgreementLocale,
): CustomerAgreementSourceDescriptor {
  const file = `${documentType}.${locale}.txt`;
  const hash = ROMAN_URDU_HASHES[file];
  const available = locale === 'ur_Latn' && hash != null;

  return {
    documentType,
    locale,
    title: TITLE,
    version: VERSION,
    status: available ? 'ACTIVE' : 'PENDING_TRANSLATION',
    file: available ? file : null,
    sha256: available ? hash : null,
    originalFilename: ORIGINAL_PDF,
  };
}

function buildRegistry(): CustomerAgreementSourceDescriptor[] {
  const out: CustomerAgreementSourceDescriptor[] = [];
  for (const locale of AGREEMENT_LOCALES) {
    for (const documentType of CUSTOMER_DOCUMENT_TYPES) {
      out.push(describe(documentType, locale));
    }
  }
  return out;
}

/** All declared variants: 1 document × 3 languages. */
export const CUSTOMER_AGREEMENT_SOURCES: readonly CustomerAgreementSourceDescriptor[] =
  Object.freeze(buildRegistry());

const BY_KEY = new Map(
  CUSTOMER_AGREEMENT_SOURCES.map((d) => [`${d.documentType}:${d.locale}`, d]),
);

export function findCustomerSource(
  documentType: CustomerDocumentType,
  locale: AgreementLocale,
): CustomerAgreementSourceDescriptor | null {
  return BY_KEY.get(`${documentType}:${locale}`) ?? null;
}

/** Every variant that may currently be viewed or accepted. */
export function activeCustomerSources(): CustomerAgreementSourceDescriptor[] {
  return CUSTOMER_AGREEMENT_SOURCES.filter((d) => isAcceptable(d.status));
}

export class CustomerAgreementSourceUnavailableError extends Error {
  constructor(
    readonly documentType: CustomerDocumentType,
    readonly locale: AgreementLocale,
    readonly reason: 'NOT_REGISTERED' | 'NOT_ACTIVE' | 'HASH_MISMATCH',
  ) {
    super(
      `Customer agreement source unavailable (${reason}): ${documentType}:${locale}`,
    );
    this.name = 'CustomerAgreementSourceUnavailableError';
  }
}

const TEXT_CACHE = new Map<string, string>();

/** Same canonical form the ingest script normalises to — see that script. */
function canonicalise(text: string): string {
  return text.replace(/^﻿/, '').replace(/\r\n/g, '\n');
}

/**
 * The exact approved text for the Customer document in one language.
 *
 * Verifies the file still hashes to what the registry pinned at ingestion,
 * so an edited or corrupted canonical file fails loudly instead of being
 * shown to a Client and sealed into an acceptance record.
 */
export function loadCustomerSourceText(
  documentType: CustomerDocumentType,
  locale: AgreementLocale,
): {
  descriptor: CustomerAgreementSourceDescriptor;
  text: string;
  sha256: string;
} {
  const descriptor = findCustomerSource(documentType, locale);
  if (!descriptor) {
    throw new CustomerAgreementSourceUnavailableError(
      documentType,
      locale,
      'NOT_REGISTERED',
    );
  }
  if (!isAcceptable(descriptor.status) || !descriptor.file) {
    throw new CustomerAgreementSourceUnavailableError(
      documentType,
      locale,
      'NOT_ACTIVE',
    );
  }

  const key = `${documentType}:${locale}`;
  let text = TEXT_CACHE.get(key);
  if (text == null) {
    text = canonicalise(
      readFileSync(path.join(DOCUMENTS_DIR, descriptor.file), 'utf8'),
    );
    TEXT_CACHE.set(key, text);
  }

  const actual = createHash('sha256').update(text, 'utf8').digest('hex');
  if (actual !== descriptor.sha256) {
    TEXT_CACHE.delete(key);
    throw new CustomerAgreementSourceUnavailableError(
      documentType,
      locale,
      'HASH_MISMATCH',
    );
  }

  return { descriptor, text, sha256: actual };
}
