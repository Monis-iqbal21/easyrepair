/* eslint-disable @typescript-eslint/no-var-requires */
/**
 * Post-build gate for the approved legal source documents.
 *
 * `nest build` compiles TypeScript; it does not copy `.txt`/`.json` unless
 * nest-cli.json says so. When that config was missing, the build succeeded,
 * the server booted healthy, and only the Ustaad hit the failure — an ENOENT
 * on the first agreement request in production.
 *
 * This runs the real compiled loader against the real compiled output, so the
 * build fails here rather than in front of a user. It checks three things the
 * endpoint depends on:
 *
 *   1. every source file was copied into dist;
 *   2. every file still hashes to its pinned SHA-256 (the tamper guard);
 *   3. all three documents resolve for every supported trade.
 *
 * Wired as `postbuild`, so a deployment cannot ship without it.
 */
const fs = require('fs');
const path = require('path');

const DIST_DOCS = path.join(
  __dirname,
  '..',
  'dist',
  'src',
  'modules',
  'agreements',
  'source',
  'documents',
);

const REQUIRED_FILES = [
  'USTAAD_SERVICE_PROVIDER_AGREEMENT.ur_Latn.txt',
  'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE.ur_Latn.txt',
  'TRADE_SPECIFIC_SERVICE_AGREEMENT.ELECTRICIAN.ur_Latn.txt',
  'TRADE_SPECIFIC_SERVICE_AGREEMENT.PLUMBER.ur_Latn.txt',
  'TRADE_SPECIFIC_SERVICE_AGREEMENT.AC_TECHNICIAN.ur_Latn.txt',
  'TRADE_SPECIFIC_SERVICE_AGREEMENT.CARPENTER.ur_Latn.txt',
  'INGEST_MANIFEST.json',
];

/** Service category name → the trade schedule it must resolve to. */
const TRADES = [
  ['Electrician', 'ELECTRICIAN'],
  ['Plumber', 'PLUMBER'],
  ['AC Technician', 'AC_TECHNICIAN'],
  ['Carpenter', 'CARPENTER'],
];

function fail(lines) {
  console.error('\n  Build asset verification FAILED\n');
  for (const line of lines) console.error(`   - ${line}`);
  console.error(
    '\n  The agreement endpoint would throw at runtime. Check the `assets`\n' +
      '  entry in nest-cli.json.\n',
  );
  process.exit(1);
}

// 1. Files present.
if (!fs.existsSync(DIST_DOCS)) {
  fail([`documents directory was not copied into the build: ${DIST_DOCS}`]);
}

const missing = REQUIRED_FILES.filter(
  (f) => !fs.existsSync(path.join(DIST_DOCS, f)),
);
if (missing.length > 0) {
  fail(missing.map((f) => `missing from dist: ${f}`));
}

// 2 + 3. The compiled loader reads and hash-verifies each document, and the
// compiled service resolves the full three-document set per trade. Any
// mismatch throws AgreementSourceUnavailableError.
const {
  UstaadTemplateService,
} = require('../dist/src/modules/agreements/ustaad-template.service');

const problems = [];
const service = new UstaadTemplateService();

for (const [categoryName, expectedTrade] of TRADES) {
  try {
    const templates = service.getTemplatesForWorker(categoryName, 'ur_Latn');
    if (templates.length !== 3) {
      problems.push(
        `${categoryName}: expected 3 documents, got ${templates.length}`,
      );
      continue;
    }
    for (const t of templates) {
      if (!t.contentText || t.contentText.length < 1000) {
        problems.push(`${categoryName}/${t.documentType}: content missing`);
      }
      if (!/^[0-9a-f]{64}$/.test(t.sourceHash)) {
        problems.push(`${categoryName}/${t.documentType}: bad sourceHash`);
      }
    }
    // The right schedule, never a substituted one.
    const tradeDoc = templates.find(
      (t) => t.documentType === 'TRADE_SPECIFIC_SERVICE_AGREEMENT',
    );
    if (!tradeDoc || tradeDoc.applicableTrade !== expectedTrade) {
      problems.push(
        `${categoryName}: resolved to ${tradeDoc && tradeDoc.applicableTrade}, expected ${expectedTrade}`,
      );
    }
  } catch (err) {
    problems.push(`${categoryName}: ${err && err.message ? err.message : err}`);
  }
}

if (problems.length > 0) fail(problems);

console.log(
  `  Agreement assets verified: ${REQUIRED_FILES.length} files, ` +
    `3 documents x ${TRADES.length} trades, all hashes match.`,
);
