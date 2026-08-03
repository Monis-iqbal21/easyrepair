import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import {
  AgreementLocale,
  AgreementSourceDescriptor,
  AGREEMENT_LOCALES,
  isAcceptable,
  sourceKey,
  TRADE_CODES,
  TradeCode,
  UstaadDocumentType,
} from './agreement-source.types';

/**
 * THE registry of approved Ustaad agreement source documents.
 *
 * Production reads the committed canonical .txt files next to this file — it
 * never touches the original PDFs or any local folder. Regenerate the text
 * with `node scripts/ingest-agreement-sources.mjs`.
 *
 * ── Why en and ur are PENDING_TRANSLATION ───────────────────────────────────
 * The approved source documents supplied by HandyGo exist in Roman Urdu only.
 * English and Urdu-script variants are declared here so the system knows they
 * are expected, but they carry no text and cannot be viewed or accepted. They
 * become ACTIVE only when HandyGo's legal team supplies certified text and it
 * passes clause-parity validation.
 *
 * This is deliberate: an acceptance record is immutable legal evidence sealed
 * with a SHA-256 hash. Machine-translated contract wording must never end up
 * inside one.
 */
const DOCUMENTS_DIR = path.join(__dirname, 'documents');

const VERSION = '1.0';
const CLAUSE_STRUCTURE_VERSION = '1.0';

const TITLES: Record<UstaadDocumentType, string> = {
  USTAAD_SERVICE_PROVIDER_AGREEMENT: 'HandyGo Ustaad Service Provider Agreement',
  TRADE_SPECIFIC_SERVICE_AGREEMENT: 'HandyGo Trade-Specific Service Agreement',
  BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE:
    'HandyGo Background Verification, EVS Consent aur Ustaad Privacy Notice',
};

const ORIGINAL_PDF: Record<UstaadDocumentType, string> = {
  USTAAD_SERVICE_PROVIDER_AGREEMENT:
    'HANDYGO USTAAD SERVICE PROVIDER AGREEMENT.pdf',
  TRADE_SPECIFIC_SERVICE_AGREEMENT:
    'HANDYGO TRADE-SPECIFIC SERVICE AGREEMENTS.pdf',
  BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE:
    'HANDYGO BACKGROUND VERIFICATION, EVS CONSENT AUR USTAAD PRIVACY NOTICE.pdf',
};

/** SHA-256 of each committed canonical file, pinned at ingestion time. */
const ROMAN_URDU_HASHES: Record<string, string> = {
  'USTAAD_SERVICE_PROVIDER_AGREEMENT.ur_Latn.txt':
    'd9fa07a224991b43524d34b5277e6842c6b40896f12f696438d693a550207cc6',
  'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE.ur_Latn.txt':
    '26a18cfeddc1916cc89ee8d32027d638973bca4bf6081ad60e9ff7800f2caf25',
  'TRADE_SPECIFIC_SERVICE_AGREEMENT.ELECTRICIAN.ur_Latn.txt':
    '0375cd931ccc6fc2d8311bae7ae313e22fd98082be594d72642c5fdeb789703d',
  'TRADE_SPECIFIC_SERVICE_AGREEMENT.PLUMBER.ur_Latn.txt':
    'a45cf2051cf0bf5978770fdfdf0bd8b634b67ef495f854e6c9f21d3f5ca4a9cc',
  'TRADE_SPECIFIC_SERVICE_AGREEMENT.AC_TECHNICIAN.ur_Latn.txt':
    'd6e3dd996ff65dba899d39bb46206e5b62af497559e68fa28643a3d11a8cc734',
  'TRADE_SPECIFIC_SERVICE_AGREEMENT.CARPENTER.ur_Latn.txt':
    '32fdbdb9fb39806222725b5c1f1b1e3ae3f41bd3316ad1c3eed2078c618c82af',
};

function describe(
  documentType: UstaadDocumentType,
  locale: AgreementLocale,
  trade: TradeCode | null,
): AgreementSourceDescriptor {
  const suffix = trade ? `${trade}.` : '';
  const file = `${documentType}.${suffix}${locale}.txt`;
  const hash = ROMAN_URDU_HASHES[file];
  const available = locale === 'ur_Latn' && hash != null;

  return {
    documentType,
    locale,
    trade,
    title: TITLES[documentType],
    version: VERSION,
    clauseStructureVersion: CLAUSE_STRUCTURE_VERSION,
    // Roman Urdu is the approved source and is live. English and Urdu await
    // certified legal text — see the file header.
    status: available ? 'ACTIVE' : 'PENDING_TRANSLATION',
    file: available ? file : null,
    sha256: available ? hash : null,
    originalFilename: ORIGINAL_PDF[documentType],
  };
}

function buildRegistry(): AgreementSourceDescriptor[] {
  const out: AgreementSourceDescriptor[] = [];
  for (const locale of AGREEMENT_LOCALES) {
    out.push(describe('USTAAD_SERVICE_PROVIDER_AGREEMENT', locale, null));
    out.push(describe('BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE', locale, null));
    for (const trade of TRADE_CODES) {
      out.push(describe('TRADE_SPECIFIC_SERVICE_AGREEMENT', locale, trade));
    }
  }
  return out;
}

/** All 18 declared variants: 6 documents × 3 languages. */
export const AGREEMENT_SOURCES: readonly AgreementSourceDescriptor[] =
  Object.freeze(buildRegistry());

const BY_KEY = new Map(
  AGREEMENT_SOURCES.map((d) => [
    sourceKey(d.documentType, d.locale, d.trade),
    d,
  ]),
);

export function findSource(
  documentType: UstaadDocumentType,
  locale: AgreementLocale,
  trade: TradeCode | null,
): AgreementSourceDescriptor | null {
  return BY_KEY.get(sourceKey(documentType, locale, trade)) ?? null;
}

/** Every variant that may currently be viewed or accepted. */
export function activeSources(): AgreementSourceDescriptor[] {
  return AGREEMENT_SOURCES.filter((d) => isAcceptable(d.status));
}

/** Languages a given document is currently acceptable in. */
export function availableLocales(
  documentType: UstaadDocumentType,
  trade: TradeCode | null,
): AgreementLocale[] {
  return AGREEMENT_LOCALES.filter((locale) => {
    const d = findSource(documentType, locale, trade);
    return d != null && isAcceptable(d.status);
  });
}

export class AgreementSourceUnavailableError extends Error {
  constructor(
    readonly documentType: UstaadDocumentType,
    readonly locale: AgreementLocale,
    readonly trade: TradeCode | null,
    readonly reason: 'NOT_REGISTERED' | 'NOT_ACTIVE' | 'HASH_MISMATCH',
  ) {
    super(
      `Agreement source unavailable (${reason}): ${sourceKey(documentType, locale, trade)}`,
    );
    this.name = 'AgreementSourceUnavailableError';
  }
}

const TEXT_CACHE = new Map<string, string>();

/**
 * The canonical form of an approved document.
 *
 * A legal document is defined by its characters, not by the line-ending
 * convention of whichever machine checked it out. Git rewrites `.txt` to CRLF
 * on a Windows checkout (and a UTF-8 BOM can survive an editor round-trip),
 * either of which changes the bytes without changing a single word — and would
 * make the SHA-256 guard below fire on a completely clean tree.
 *
 * Normalising here means the pinned hash, the text shown to the Ustaad, and the
 * `sourceHash` sealed into the acceptance record are identical on every
 * platform. The hashes in this file were pinned against this LF form.
 */
function canonicalise(text: string): string {
  return text.replace(/^﻿/, '').replace(/\r\n/g, '\n');
}

/**
 * The exact approved text for one document-language(-trade) version.
 *
 * Verifies the file still hashes to what the registry pinned at ingestion,
 * so an edited or corrupted canonical file fails loudly instead of being
 * shown to an Ustaad and sealed into an acceptance record.
 */
export function loadSourceText(
  documentType: UstaadDocumentType,
  locale: AgreementLocale,
  trade: TradeCode | null,
): { descriptor: AgreementSourceDescriptor; text: string; sha256: string } {
  const descriptor = findSource(documentType, locale, trade);
  if (!descriptor) {
    throw new AgreementSourceUnavailableError(
      documentType,
      locale,
      trade,
      'NOT_REGISTERED',
    );
  }
  if (!isAcceptable(descriptor.status) || !descriptor.file) {
    throw new AgreementSourceUnavailableError(
      documentType,
      locale,
      trade,
      'NOT_ACTIVE',
    );
  }

  const key = sourceKey(documentType, locale, trade);
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
    throw new AgreementSourceUnavailableError(
      documentType,
      locale,
      trade,
      'HASH_MISMATCH',
    );
  }

  return { descriptor, text, sha256: actual };
}
