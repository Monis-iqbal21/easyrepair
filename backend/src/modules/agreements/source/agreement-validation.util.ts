import {
  AgreementLocale,
  AGREEMENT_LOCALES,
  AgreementSourceDescriptor,
  isAcceptable,
  TradeCode,
  UstaadDocumentType,
} from './agreement-source.types';
import { findSource, loadSourceText } from './agreement-source.registry';

/**
 * Content safety-rails for agreement text. Everything here is a *detector*:
 * it never rewrites legal wording, it only refuses to let bad content through.
 */

// ── Devanagari ──────────────────────────────────────────────────────────────

/**
 * HandyGo is a Pakistani product. Devanagari (U+0900–U+097F) is Hindi script
 * and must never appear in any agreement text, UI string or generated PDF.
 */
export const DEVANAGARI_RANGE = /[ऀ-ॿ]/;
const DEVANAGARI_GLOBAL = /[ऀ-ॿ]/g;

export interface DevanagariHit {
  /** 1-based line number. */
  line: number;
  /** The offending characters found on that line. */
  characters: string[];
  /** Trimmed line, for the failure message. */
  excerpt: string;
}

export function findDevanagari(text: string): DevanagariHit[] {
  const hits: DevanagariHit[] = [];
  text.split('\n').forEach((line, index) => {
    const matches = line.match(DEVANAGARI_GLOBAL);
    if (matches) {
      hits.push({
        line: index + 1,
        characters: [...new Set(matches)],
        excerpt: line.trim().slice(0, 120),
      });
    }
  });
  return hits;
}

export function assertNoDevanagari(text: string, label: string): void {
  const hits = findDevanagari(text);
  if (hits.length === 0) return;
  const detail = hits
    .slice(0, 5)
    .map((h) => `line ${h.line}: ${h.characters.join('')} — "${h.excerpt}"`)
    .join('; ');
  throw new Error(
    `Devanagari (Hindi) characters found in ${label}: ${detail}` +
      (hits.length > 5 ? ` (+${hits.length - 5} more)` : ''),
  );
}

// ── Unresolved blanks and template tokens ───────────────────────────────────

/**
 * The approved SOURCE documents legitimately contain fill-in rules such as
 * `CNIC Number: ______`. A GENERATED, accepted document must not: every blank
 * has to have been replaced with real Ustaad data or a controlled
 * "not applicable" value before it is hashed and sealed.
 */
const BLANK_UNDERSCORES = /_{3,}/g;
const TEMPLATE_TOKEN = /\{\{\s*[\w.]+\s*\}\}|\$\{\s*[\w.]+\s*\}/g;

export interface UnresolvedContent {
  blanks: { line: number; excerpt: string }[];
  tokens: { line: number; token: string }[];
}

export function findUnresolvedContent(text: string): UnresolvedContent {
  const blanks: UnresolvedContent['blanks'] = [];
  const tokens: UnresolvedContent['tokens'] = [];

  text.split('\n').forEach((line, index) => {
    if (BLANK_UNDERSCORES.test(line)) {
      blanks.push({ line: index + 1, excerpt: line.trim().slice(0, 120) });
    }
    BLANK_UNDERSCORES.lastIndex = 0;

    for (const match of line.matchAll(TEMPLATE_TOKEN)) {
      tokens.push({ line: index + 1, token: match[0] });
    }
  });

  return { blanks, tokens };
}

/** Guards a generated/accepted document immediately before it is sealed. */
export function assertFullyPopulated(text: string, label: string): void {
  const { blanks, tokens } = findUnresolvedContent(text);
  const problems: string[] = [];
  if (blanks.length) {
    problems.push(
      `${blanks.length} unfilled blank(s), first at line ${blanks[0].line}: "${blanks[0].excerpt}"`,
    );
  }
  if (tokens.length) {
    problems.push(
      `${tokens.length} unresolved template token(s), first: ${tokens[0].token} (line ${tokens[0].line})`,
    );
  }
  if (problems.length) {
    throw new Error(`Accepted document ${label} is not fully populated: ${problems.join('; ')}`);
  }
}

// ── Clause parity across languages ──────────────────────────────────────────

/**
 * Clause identifiers as they appear in the approved documents: `1.`, `2.3`,
 * `E1.`, `P7.`, `A4.2`, `C6.` — a numbering token at the start of a line.
 * Language variants must expose exactly the same set, in the same order.
 */
const CLAUSE_ID = /^\s*((?:[A-Z]\d+|\d+)(?:\.\d+)*)\.?\s+\S/;
const SCHEDULE_HEADING = /^\s*(SCHEDULE\s+[A-Z])\b/;

export function extractClauseIds(text: string): string[] {
  const ids: string[] = [];
  for (const line of text.split('\n')) {
    const schedule = line.match(SCHEDULE_HEADING);
    if (schedule) {
      ids.push(schedule[1].replace(/\s+/g, ' ').toUpperCase());
      continue;
    }
    const clause = line.match(CLAUSE_ID);
    if (clause) ids.push(clause[1]);
  }
  return ids;
}

export interface ParityIssue {
  documentType: UstaadDocumentType;
  trade: TradeCode | null;
  locale: AgreementLocale;
  kind:
    | 'MISSING_VARIANT'
    | 'CLAUSE_MISSING'
    | 'CLAUSE_EXTRA'
    | 'ORDER_MISMATCH'
    | 'STRUCTURE_VERSION_MISMATCH'
    | 'DEVANAGARI';
  detail: string;
}

/**
 * Compares every declared language variant of one document against the
 * reference locale, so a clause can never be missing from — or invented in —
 * a single language.
 *
 * Variants still PENDING_TRANSLATION are reported as MISSING_VARIANT rather
 * than silently skipped: that is exactly the signal that stops such a variant
 * from being activated.
 */
export function checkDocumentParity(
  documentType: UstaadDocumentType,
  trade: TradeCode | null,
  referenceLocale: AgreementLocale = 'ur_Latn',
): ParityIssue[] {
  const issues: ParityIssue[] = [];

  const reference = findSource(documentType, referenceLocale, trade);
  if (!reference || !isAcceptable(reference.status)) {
    return [
      {
        documentType,
        trade,
        locale: referenceLocale,
        kind: 'MISSING_VARIANT',
        detail: `reference locale ${referenceLocale} is not ACTIVE`,
      },
    ];
  }

  const referenceText = loadSourceText(documentType, referenceLocale, trade).text;
  const referenceIds = extractClauseIds(referenceText);

  for (const locale of AGREEMENT_LOCALES) {
    if (locale === referenceLocale) continue;

    const descriptor = findSource(documentType, locale, trade);
    if (!descriptor || !isAcceptable(descriptor.status)) {
      issues.push({
        documentType,
        trade,
        locale,
        kind: 'MISSING_VARIANT',
        detail: `status=${descriptor?.status ?? 'NOT_REGISTERED'}`,
      });
      continue;
    }

    if (descriptor.clauseStructureVersion !== reference.clauseStructureVersion) {
      issues.push({
        documentType,
        trade,
        locale,
        kind: 'STRUCTURE_VERSION_MISMATCH',
        detail: `${descriptor.clauseStructureVersion} vs ${reference.clauseStructureVersion}`,
      });
    }

    const text = loadSourceText(documentType, locale, trade).text;

    for (const hit of findDevanagari(text)) {
      issues.push({
        documentType,
        trade,
        locale,
        kind: 'DEVANAGARI',
        detail: `line ${hit.line}: ${hit.characters.join('')}`,
      });
    }

    const ids = extractClauseIds(text);
    const refSet = new Set(referenceIds);
    const set = new Set(ids);

    for (const id of referenceIds) {
      if (!set.has(id)) {
        issues.push({
          documentType,
          trade,
          locale,
          kind: 'CLAUSE_MISSING',
          detail: id,
        });
      }
    }
    for (const id of ids) {
      if (!refSet.has(id)) {
        issues.push({
          documentType,
          trade,
          locale,
          kind: 'CLAUSE_EXTRA',
          detail: id,
        });
      }
    }
    if (
      ids.length === referenceIds.length &&
      ids.some((id, i) => id !== referenceIds[i])
    ) {
      issues.push({
        documentType,
        trade,
        locale,
        kind: 'ORDER_MISMATCH',
        detail: 'clause order differs from the reference locale',
      });
    }
  }

  return issues;
}

/**
 * True only when a variant is complete enough to be safely activated. The
 * activation path calls this; nothing becomes ACTIVE without passing.
 */
export function canActivate(
  descriptor: AgreementSourceDescriptor,
): { ok: boolean; issues: ParityIssue[] } {
  const issues = checkDocumentParity(
    descriptor.documentType,
    descriptor.trade,
  ).filter((i) => i.locale === descriptor.locale && i.kind !== 'MISSING_VARIANT');
  return { ok: issues.length === 0, issues };
}
