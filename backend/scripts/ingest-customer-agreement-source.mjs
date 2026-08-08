#!/usr/bin/env node
/**
 * DEV-TIME ONLY. Converts the approved Customer Terms PDF into the canonical
 * text file production actually reads.
 *
 *   node scripts/ingest-customer-agreement-source.mjs [--src <folder>]
 *
 * Mirrors scripts/ingest-agreement-sources.mjs (see that file for the Ustaad
 * documents), kept separate on purpose: the Customer document must never be
 * reachable from the Ustaad ingest path, and it needs no trade-schedule
 * splitting. Production never touches the PDF or this script — only the
 * committed canonical .txt this emits is ever read at runtime.
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
const OUT_DIR = path.join(
  HERE,
  '..',
  'src',
  'modules',
  'agreements',
  'source',
  'customer-documents',
);

const argSrc = process.argv.indexOf('--src');
const SRC_DIR = argSrc !== -1 ? process.argv[argSrc + 1] : path.join(HERE, '..', '..', 'agreements');

const DOCUMENT_TYPE = 'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE';
const PDF_FILENAME = 'HANDYGO CUSTOMER TERMS, BOOKING RULES AUR PRIVACY NOTICE.pdf';

function extract(pdfPath) {
  const tmp = mkdtempSync(path.join(tmpdir(), 'handygo-cust-agr-'));
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

/** Identical normalisation rule to the Ustaad ingest script — see that file. */
function canonicalise(raw) {
  return raw
    .replace(/\r\n?/g, '\n')
    .replace(/\f/g, '\n')
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

mkdirSync(OUT_DIR, { recursive: true });

const pdfPath = path.join(SRC_DIR, PDF_FILENAME);
const text = canonicalise(extract(pdfPath));
const file = `${DOCUMENT_TYPE}.ur_Latn.txt`;
writeFileSync(path.join(OUT_DIR, file), text, 'utf8');

const manifest = {
  generatedFrom: 'approved PDF',
  documents: [
    {
      documentType: DOCUMENT_TYPE,
      trade: null,
      locale: 'ur_Latn',
      file,
      bytes: Buffer.byteLength(text, 'utf8'),
      sha256: sha256(text),
    },
  ],
};
writeFileSync(
  path.join(OUT_DIR, 'INGEST_MANIFEST.json'),
  JSON.stringify(manifest, null, 2) + '\n',
  'utf8',
);

console.log(`${sha256(text).slice(0, 12)}  ${String(Buffer.byteLength(text, 'utf8')).padStart(6)} B  ${file}`);
console.log(`\n1 canonical document -> ${OUT_DIR}`);
