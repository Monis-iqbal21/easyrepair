import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { AgreementType } from '@prisma/client';
import { generateAgreementAcceptancePdf } from '../../../common/utils/agreement-pdf.util';
import { loadCustomerSourceText } from './customer-agreement-source.registry';
import { personalizeAgreement } from './agreement-personalization.util';
import { sha256Bytes, sha256Text } from './acceptance-identity.util';
import { findDevanagari, findUnresolvedContent } from './agreement-validation.util';

/** Extracts the PDF's text so we assert on what a reader actually sees. */
function pdfText(pdf: Buffer): string {
  const dir = mkdtempSync(path.join(tmpdir(), 'hg-cust-pdf-'));
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

async function buildPdf() {
  const source = loadCustomerSourceText(
    'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
    'ur_Latn',
  );
  const personalized = personalizeAgreement(source.text, {
    fullLegalName: 'Ayesha Siddiqui',
    fatherName: null,
    cnicNumber: '',
    dateOfBirth: null,
    residentialAddress: null,
    registeredMobile: '+92 300 1234567',
    ustaadAccountId: '',
    mainTrade: '',
    approvedServiceTags: null,
    emergencyContact: null,
    verificationProvider: null,
    verificationRequestDate: null,
    verificationRequestReference: null,
    customerAccountId: 'HG-CUSTOMER-ABC1234567',
    acceptanceId: 'HG-ACC-2026-ABCDEF123456',
    acceptedAtIso: '2026-08-07T10:15:00.000Z',
    sourceDocumentHash: source.sha256,
    deviceSessionIpReference: 'android/session-7f3a / 203.0.113.9',
  });
  const acceptedDocumentHash = sha256Text(personalized.text);

  const pdf = await generateAgreementAcceptancePdf({
    acceptanceId: 'HG-ACC-2026-ABCDEF123456',
    fullLegalName: 'Ayesha Siddiqui',
    mobile: '+92 300 1234567',
    agreementType: AgreementType.CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE,
    agreementTitle: source.descriptor.title,
    agreementVersion: source.descriptor.version,
    agreementContent: personalized.text,
    agreementHash: source.sha256,
    acceptedAt: new Date('2026-08-07T10:15:00.000Z'),
    agreementLocale: 'ur_Latn',
    acceptedDocumentHash,
    ipAddress: '203.0.113.9',
    deviceInfo: 'android/session-7f3a',
  });

  return { pdf, personalized, acceptedDocumentHash, source };
}

describe('Customer accepted agreement PDF', () => {
  it('produces a valid, openable PDF', async () => {
    const { pdf } = await buildPdf();
    expect(pdf.length).toBeGreaterThan(5000);
    expect(pdf.subarray(0, 5).toString('latin1')).toBe('%PDF-');
    expect(pdfText(pdf).length).toBeGreaterThan(1000);
  });

  it('contains the personalized Client information', async () => {
    const { pdf } = await buildPdf();
    const text = pdfText(pdf);

    expect(text).toContain('Ayesha Siddiqui');
    expect(text).toContain('+92 300 1234567');
    expect(text).toContain('HG-CUSTOMER-ABC1234567');
  });

  it('never prints a CNIC line — a Customer has none', async () => {
    const { pdf } = await buildPdf();
    expect(pdfText(pdf)).not.toContain('CNIC:');
  });

  it('contains the acceptance id, server timestamp and version', async () => {
    const { pdf, source } = await buildPdf();
    const text = pdfText(pdf);

    expect(text).toContain('HG-ACC-2026-ABCDEF123456');
    expect(text).toContain('2026-08-07T10:15:00.000Z');
    expect(text).toContain(source.descriptor.version);
  });

  it('records both the source and accepted hashes', async () => {
    const { pdf, source, acceptedDocumentHash } = await buildPdf();
    const text = pdfText(pdf).replace(/\s+/g, '');

    expect(text).toContain(source.sha256);
    expect(text).toContain(acceptedDocumentHash);
    expect(acceptedDocumentHash).not.toBe(source.sha256);
  });

  it('leaves no blank underscores and no template tokens', async () => {
    const { pdf, personalized } = await buildPdf();

    expect(findUnresolvedContent(personalized.text).blanks).toEqual([]);
    expect(findUnresolvedContent(personalized.text).tokens).toEqual([]);
    expect(pdfText(pdf)).not.toMatch(/_{4,}/);
  });

  it('contains no Devanagari', async () => {
    const { pdf, personalized } = await buildPdf();
    expect(findDevanagari(personalized.text)).toEqual([]);
    expect(findDevanagari(pdfText(pdf))).toEqual([]);
  });

  it('hashes stably for identical content', async () => {
    const a = await buildPdf();
    const b = await buildPdf();
    expect(a.acceptedDocumentHash).toBe(b.acceptedDocumentHash);
    expect(sha256Bytes(a.pdf)).toMatch(/^[0-9a-f]{64}$/);
  });
});
