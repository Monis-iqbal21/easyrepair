#!/usr/bin/env node
/**
 * DEV-TIME ONLY. Converts the approved agreement PDFs into the canonical
 * text files that production actually reads.
 *
 *   node scripts/ingest-agreement-sources.mjs [--src <folder>]
 *
 * Production never touches the PDFs or the author's local folder: the
 * canonical .txt files this emits are committed and are the only thing the
 * source registry loads. Re-running is safe and idempotent — identical input
 * produces byte-identical output, so the SHA-256 of a document only moves
 * when the approved wording actually moves.
 *
 * The Customer Terms document is deliberately NOT ingested here. It is
 * reserved for a separate Customer flow and must never reach an Ustaad.
 *
 * Requires `pdftotext` (poppler-utils) on PATH.
 */
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT_DIR = path.join(HERE, '..', 'src', 'modules', 'agreements', 'source', 'documents');

const argSrc = process.argv.indexOf('--src');
const SRC_DIR = argSrc !== -1 ? process.argv[argSrc + 1] : path.join(HERE, '..', '..', 'agreements');

/** The three Ustaad documents. The Customer PDF is intentionally absent. */
const SOURCES = {
  USTAAD_SERVICE_PROVIDER_AGREEMENT: 'HANDYGO USTAAD SERVICE PROVIDER AGREEMENT.pdf',
  BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE:
    'HANDYGO BACKGROUND VERIFICATION, EVS CONSENT AUR USTAAD PRIVACY NOTICE.pdf',
  TRADE_SPECIFIC_SERVICE_AGREEMENT: 'HANDYGO TRADE-SPECIFIC SERVICE AGREEMENTS.pdf',
};

/**
 * Schedule heading -> stable trade code. Matched on the heading text of the
 * approved document, never on a translated or UI label.
 */
const SCHEDULES = [
  { code: 'ELECTRICIAN', heading: 'SCHEDULE E — ELECTRICIAN' },
  { code: 'PLUMBER', heading: 'SCHEDULE P — PLUMBER' },
  { code: 'AC_TECHNICIAN', heading: 'SCHEDULE A — AC TECHNICIAN' },
  { code: 'CARPENTER', heading: 'SCHEDULE C — CARPENTER' },
];

/** Common closing that applies to every trade (electronic acceptance rules). */
const CLOSING_HEADING = 'ELECTRONIC ACCEPTANCE';

function extract(pdfPath) {
  const tmp = mkdtempSync(path.join(tmpdir(), 'handygo-agr-'));
  const out = path.join(tmp, 'out.txt');
  try {
    execFileSync('pdftotext', ['-layout', '-enc', 'UTF-8', pdfPath, out], {
      stdio: ['ignore', 'ignore', 'pipe'],
    });
    return readFileSync(out, 'utf8');
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

/**
 * Normalises whitespace so the hash is stable across pdftotext versions and
 * platforms, WITHOUT touching wording, ordering, numbering or punctuation.
 * Legal content is never rewritten here — only trailing spaces, form feeds,
 * CRLF and runs of blank lines are made deterministic.
 */
function canonicalise(raw) {
  return raw
    .replace(/\r\n?/g, '\n')
    .replace(/\f/g, '\n')
    // Soft hyphen and zero-width joiners the PDF exporter injects.
    .replace(/[­​‌‍⁠﻿]/g, '')
    .split('\n')
    .map((line) => line.replace(/[ \t]+$/g, ''))
    .join('\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
    .concat('\n');
}

function sha256(text) {
  return createHash('sha256').update(text, 'utf8').digest('hex');
}

function indexOfLine(lines, predicate, from = 0) {
  for (let i = from; i < lines.length; i++) if (predicate(lines[i])) return i;
  return -1;
}

/**
 * A per-trade document = header + common terms + ONLY that trade's schedule
 * + the shared electronic-acceptance closing.
 *
 * This is what makes "do not make the Ustaad accept schedules for unrelated
 * trades" true at the source level rather than by hiding text in the UI.
 */
function splitTradeDocument(text) {
  const lines = text.split('\n');
  const bounds = SCHEDULES.map((s) => ({
    ...s,
    start: indexOfLine(lines, (l) => l.trim() === s.heading),
  }));

  const missing = bounds.filter((b) => b.start === -1);
  if (missing.length) {
    throw new Error(
      `Schedule heading(s) not found: ${missing.map((m) => m.heading).join(', ')}`,
    );
  }

  const closingStart = indexOfLine(
    lines,
    (l) => l.trim() === CLOSING_HEADING,
    bounds[bounds.length - 1].start,
  );
  if (closingStart === -1) {
    throw new Error(`Closing heading "${CLOSING_HEADING}" not found`);
  }

  const common = lines.slice(0, bounds[0].start).join('\n').trim();
  const closing = lines.slice(closingStart).join('\n').trim();

  return bounds.map((b, i) => {
    const end = i + 1 < bounds.length ? bounds[i + 1].start : closingStart;
    const schedule = lines.slice(b.start, end).join('\n').trim();
    return {
      trade: b.code,
      text: canonicalise([common, schedule, closing].join('\n\n')),
    };
  });
}

// ── Run ─────────────────────────────────────────────────────────────────────

mkdirSync(OUT_DIR, { recursive: true });
const emitted = [];

function emit(documentType, trade, text) {
  const suffix = trade ? `${trade}.` : '';
  const file = `${documentType}.${suffix}ur_Latn.txt`;
  writeFileSync(path.join(OUT_DIR, file), text, 'utf8');
  emitted.push({
    documentType,
    trade: trade ?? null,
    locale: 'ur_Latn',
    file,
    bytes: Buffer.byteLength(text, 'utf8'),
    sha256: sha256(text),
  });
}

for (const [documentType, filename] of Object.entries(SOURCES)) {
  const pdfPath = path.join(SRC_DIR, filename);
  const raw = extract(pdfPath);

  if (documentType === 'TRADE_SPECIFIC_SERVICE_AGREEMENT') {
    for (const part of splitTradeDocument(canonicalise(raw))) {
      emit(documentType, part.trade, part.text);
    }
  } else {
    emit(documentType, null, canonicalise(raw));
  }
}

writeFileSync(
  path.join(OUT_DIR, 'INGEST_MANIFEST.json'),
  JSON.stringify({ generatedFrom: 'approved PDFs', documents: emitted }, null, 2) + '\n',
  'utf8',
);

for (const e of emitted) {
  console.log(
    `${e.sha256.slice(0, 12)}  ${String(e.bytes).padStart(6)} B  ${e.file}`,
  );
}
console.log(`\n${emitted.length} canonical documents -> ${OUT_DIR}`);
