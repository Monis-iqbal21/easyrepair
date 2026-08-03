import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import {
  generateAgreementAcceptancePdf,
  assertRenderableLocale,
  UnrenderablePdfLocaleError,
} from '../../../common/utils/agreement-pdf.util';
import { loadSourceText } from './agreement-source.registry';
import {
  personalizeAgreement,
  PersonalizationData,
} from './agreement-personalization.util';
import { sha256Bytes, sha256Text } from './acceptance-identity.util';
import { findDevanagari, findUnresolvedContent } from './agreement-validation.util';
import { TRADE_CODES, UstaadDocumentType } from './agreement-source.types';

const DATA: PersonalizationData = {
  fullLegalName: 'Muhammad Ali Khan',
  fatherName: 'Abdul Rehman Khan',
  cnicNumber: '42101-1234567-1',
  dateOfBirth: '1990-04-12',
  residentialAddress: 'House 12, Street 4, Gulshan-e-Iqbal, Karachi',
  registeredMobile: '+92 332 0219006',
  ustaadAccountId: 'HG-USTAAD-000123',
  mainTrade: 'Electrician',
  approvedServiceTags: 'Fan installation, Switch replacement',
  emergencyContact: 'Fatima Khan, +92 300 1112233',
  verificationProvider: 'HandyGo Verification Partner',
  verificationRequestDate: '2026-08-01',
  verificationRequestReference: 'EVS-2026-0001',
  acceptanceId: 'HG-ACC-2026-ABCDEF123456',
  acceptedAtIso: '2026-08-03T10:15:00.000Z',
  sourceDocumentHash: 'a'.repeat(64),
  deviceSessionIpReference: 'android/session-7f3a/203.0.113.9',
};

/** Builds the exact accepted artefacts the service will seal. */
async function buildPdf(
  documentType: UstaadDocumentType,
  trade: (typeof TRADE_CODES)[number] | null,
) {
  const source = loadSourceText(documentType, 'ur_Latn', trade);
  const personalized = personalizeAgreement(source.text, {
    ...DATA,
    sourceDocumentHash: source.sha256,
  });
  const acceptedDocumentHash = sha256Text(personalized.text);

  const pdf = await generateAgreementAcceptancePdf({
    acceptanceId: DATA.acceptanceId,
    fullLegalName: DATA.fullLegalName,
    cnicNumber: DATA.cnicNumber,
    mobile: DATA.registeredMobile,
    agreementType:
      documentType === 'USTAAD_SERVICE_PROVIDER_AGREEMENT'
        ? 'GENERAL_USTAAD'
        : documentType === 'TRADE_SPECIFIC_SERVICE_AGREEMENT'
          ? 'TRADE_SPECIFIC'
          : 'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE',
    agreementTitle: source.descriptor.title,
    agreementVersion: source.descriptor.version,
    agreementContent: personalized.text,
    agreementHash: source.sha256,
    acceptedAt: new Date(DATA.acceptedAtIso),
    agreementLocale: 'ur_Latn',
    applicableTrade: trade,
    acceptedDocumentHash,
    ipAddress: '203.0.113.9',
    deviceInfo: 'android/session-7f3a',
  });

  return { pdf, personalized, acceptedDocumentHash, source };
}

/** Extracts the PDF's text so we assert on what a reader actually sees. */
function pdfText(pdf: Buffer): string {
  const dir = mkdtempSync(path.join(tmpdir(), 'hg-pdf-'));
  try {
    const file = path.join(dir, 'a.pdf');
    writeFileSync(file, pdf);
    execFileSync('pdftotext', ['-layout', '-enc', 'UTF-8', file, `${file}.txt`], {
      stdio: ['ignore', 'ignore', 'pipe'],
    });
    return readFileSync(`${file}.txt`, 'utf8');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const DOCS: [UstaadDocumentType, (typeof TRADE_CODES)[number] | null][] = [
  ['USTAAD_SERVICE_PROVIDER_AGREEMENT', null],
  ['BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE', null],
  ...TRADE_CODES.map(
    (t) =>
      ['TRADE_SPECIFIC_SERVICE_AGREEMENT', t] as [
        UstaadDocumentType,
        (typeof TRADE_CODES)[number],
      ],
  ),
];

describe('accepted agreement PDF', () => {
  describe.each(DOCS)('%s / %s', (documentType, trade) => {
    it('produces a valid, openable PDF', async () => {
      const { pdf } = await buildPdf(documentType, trade);

      expect(pdf.length).toBeGreaterThan(5000);
      expect(pdf.subarray(0, 5).toString('latin1')).toBe('%PDF-');
      // pdftotext parsing it at all is the real "opens successfully" proof.
      expect(pdfText(pdf).length).toBeGreaterThan(1000);
    });

    it('contains the personalized Ustaad information', async () => {
      const { pdf } = await buildPdf(documentType, trade);
      const text = pdfText(pdf);

      expect(text).toContain('Muhammad Ali Khan');
      expect(text).toContain('42101-1234567-1');
      expect(text).toContain('HG-USTAAD-000123');
    });

    it('contains the acceptance id, server timestamp and version', async () => {
      const { pdf, source } = await buildPdf(documentType, trade);
      const text = pdfText(pdf);

      expect(text).toContain('HG-ACC-2026-ABCDEF123456');
      expect(text).toContain('2026-08-03T10:15:00.000Z');
      expect(text).toContain(source.descriptor.version);
    });

    it('records both the source and accepted hashes', async () => {
      const { pdf, source, acceptedDocumentHash } = await buildPdf(
        documentType,
        trade,
      );
      const text = pdfText(pdf).replace(/\s+/g, '');

      expect(text).toContain(source.sha256);
      expect(text).toContain(acceptedDocumentHash);
      // The accepted document necessarily differs from the blank source.
      expect(acceptedDocumentHash).not.toBe(source.sha256);
    });

    it('states the electronic acceptance and the language', async () => {
      const { pdf } = await buildPdf(documentType, trade);
      const text = pdfText(pdf);

      expect(text).toContain('electronically accepted through the HandyGo');
      expect(text).toContain('ur_Latn');
    });

    it('leaves no blank underscores and no template tokens', async () => {
      const { pdf, personalized } = await buildPdf(documentType, trade);

      // Assert on the sealed canonical text (authoritative) …
      expect(findUnresolvedContent(personalized.text).blanks).toEqual([]);
      expect(findUnresolvedContent(personalized.text).tokens).toEqual([]);
      // … and on what the reader actually sees in the PDF.
      expect(pdfText(pdf)).not.toMatch(/_{4,}/);
    });

    it('contains no Devanagari', async () => {
      const { pdf, personalized } = await buildPdf(documentType, trade);

      expect(findDevanagari(personalized.text)).toEqual([]);
      expect(findDevanagari(pdfText(pdf))).toEqual([]);
    });

    it('hashes stably for identical content and changes when content changes', async () => {
      const a = await buildPdf(documentType, trade);
      const b = await buildPdf(documentType, trade);

      expect(a.acceptedDocumentHash).toBe(b.acceptedDocumentHash);
      expect(sha256Text(a.personalized.text + ' ')).not.toBe(
        a.acceptedDocumentHash,
      );
      // PDF byte hash is well-formed (pdfkit embeds a creation date, so the
      // canonical text hash — not the byte hash — is the stable identity).
      expect(sha256Bytes(a.pdf)).toMatch(/^[0-9a-f]{64}$/);
    });
  });

  describe('trade schedule isolation in the rendered PDF', () => {
    it.each(TRADE_CODES)('%s PDF shows only its own schedule', async (trade) => {
      const { pdf } = await buildPdf('TRADE_SPECIFIC_SERVICE_AGREEMENT', trade);
      const text = pdfText(pdf).replace(/\s+/g, ' ');

      const headings = {
        ELECTRICIAN: 'SCHEDULE E',
        PLUMBER: 'SCHEDULE P',
        AC_TECHNICIAN: 'SCHEDULE A',
        CARPENTER: 'SCHEDULE C',
      } as const;

      expect(text).toContain(headings[trade]);
      for (const other of TRADE_CODES) {
        if (other !== trade) expect(text).not.toContain(headings[other]);
      }
    });
  });

  describe('Urdu-script rendering is refused until a font is configured', () => {
    it('rejects locale ur rather than emitting unreadable glyphs', () => {
      // Helvetica has no Arabic-script glyphs and pdfkit does no shaping.
      expect(() => assertRenderableLocale('ur')).toThrow(UnrenderablePdfLocaleError);
      expect(() => assertRenderableLocale('ur')).toThrow(/Urdu-capable font/);
    });

    it('allows the locales that genuinely render today', () => {
      expect(() => assertRenderableLocale('ur_Latn')).not.toThrow();
      expect(() => assertRenderableLocale('en')).not.toThrow();
      expect(() => assertRenderableLocale(null)).not.toThrow();
    });

    it('refuses at generation time too', async () => {
      await expect(
        generateAgreementAcceptancePdf({
          acceptanceId: 'x',
          fullLegalName: 'x',
          cnicNumber: 'x',
          mobile: 'x',
          agreementType: 'GENERAL_USTAAD',
          agreementTitle: 'x',
          agreementVersion: '1.0',
          agreementContent: 'x',
          agreementHash: 'x',
          acceptedAt: new Date(),
          agreementLocale: 'ur',
        }),
      ).rejects.toThrow(UnrenderablePdfLocaleError);
    });
  });
});
