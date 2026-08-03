import { loadSourceText } from './agreement-source.registry';
import {
  MissingAgreementDataError,
  NOT_APPLICABLE,
  personalizeAgreement,
  PersonalizationData,
  formatServiceTags,
} from './agreement-personalization.util';
import { findDevanagari, findUnresolvedContent } from './agreement-validation.util';
import { TRADE_CODES, UstaadDocumentType } from './agreement-source.types';

/**
 * Runs against the REAL approved documents. A blank surviving into an accepted
 * copy is a legal defect, so every one of these asserts on the actual text
 * that would be hashed and sealed.
 */
const COMPLETE: PersonalizationData = {
  fullLegalName: 'Muhammad Ali Khan',
  fatherName: 'Abdul Rehman Khan',
  cnicNumber: '42101-1234567-1',
  dateOfBirth: '1990-04-12',
  residentialAddress: 'House 12, Street 4, Gulshan-e-Iqbal, Karachi',
  registeredMobile: '+92 332 0219006',
  ustaadAccountId: 'HG-USTAAD-000123',
  mainTrade: 'Electrician',
  approvedServiceTags: 'Fan installation, Switch replacement, Socket repair',
  emergencyContact: 'Fatima Khan, +92 300 1112233',
  verificationProvider: 'HandyGo Verification Partner',
  verificationRequestDate: '2026-08-01',
  verificationRequestReference: 'EVS-2026-0001',
  acceptanceId: 'HG-ACC-2026-ABCDEF123456',
  acceptedAtIso: '2026-08-03T10:15:00.000Z',
  sourceDocumentHash: 'd9fa07a224991b43524d34b5277e6842c6b40896f12f696438d693a550207cc6',
  deviceSessionIpReference: 'android/session-7f3a/203.0.113.9',
};

const DOCS: [UstaadDocumentType, string | null][] = [
  ['USTAAD_SERVICE_PROVIDER_AGREEMENT', null],
  ['BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE', null],
  ...TRADE_CODES.map(
    (t) => ['TRADE_SPECIFIC_SERVICE_AGREEMENT', t] as [UstaadDocumentType, string],
  ),
];

function personalize(
  documentType: UstaadDocumentType,
  trade: string | null,
  data: PersonalizationData = COMPLETE,
) {
  const { text } = loadSourceText(documentType, 'ur_Latn', trade as never);
  return personalizeAgreement(text, data);
}

describe('agreement personalization', () => {
  describe('every approved document fills completely', () => {
    it.each(DOCS)('%s / %s leaves no blank or token', (documentType, trade) => {
      const { text } = personalize(documentType, trade);

      const unresolved = findUnresolvedContent(text);
      expect(unresolved.blanks).toEqual([]);
      expect(unresolved.tokens).toEqual([]);
    });

    it.each(DOCS)('%s / %s contains no Devanagari', (documentType, trade) => {
      const { text } = personalize(documentType, trade);
      expect(findDevanagari(text)).toEqual([]);
    });

    it.each(DOCS)('%s / %s carries the Ustaad data', (documentType, trade) => {
      const { text } = personalize(documentType, trade);

      expect(text).toContain('Muhammad Ali Khan');
      expect(text).toContain('42101-1234567-1');
      expect(text).toContain('HG-USTAAD-000123');
      expect(text).toContain('HG-ACC-2026-ABCDEF123456');
      expect(text).toContain('2026-08-03T10:15:00.000Z');
    });

    it('the source itself still HAS blanks — proving the fill did the work', () => {
      const { text: source } = loadSourceText(
        'USTAAD_SERVICE_PROVIDER_AGREEMENT',
        'ur_Latn',
        null,
      );
      expect(findUnresolvedContent(source).blanks.length).toBeGreaterThan(0);
    });
  });

  describe('legal wording is untouched', () => {
    it('changes only blank lines, never clause text', () => {
      const { text: source } = loadSourceText(
        'USTAAD_SERVICE_PROVIDER_AGREEMENT',
        'ur_Latn',
        null,
      );
      const { text } = personalize('USTAAD_SERVICE_PROVIDER_AGREEMENT', null);

      const sourceLines = source.split('\n');
      const outLines = text.split('\n');
      expect(outLines).toHaveLength(sourceLines.length);

      const changed = outLines.filter((l, i) => l !== sourceLines[i]);
      // Every changed line was either a blank or the availability checkbox.
      for (const line of changed) {
        expect(
          /_{3,}/.test(sourceLines[outLines.indexOf(line)] ?? '') ||
            /Haan/.test(line),
        ).toBe(true);
      }
      // Clause bodies survive verbatim.
      expect(text).toContain('2. AGREEMENT KA STRUCTURE AUR AHMIYAT');
      expect(text).toContain('3. RELATIONSHIP KI NATURE');
    });

    it('ticks the "PDF made available" box rather than leaving it blank', () => {
      const { text } = personalize('USTAAD_SERVICE_PROVIDER_AGREEMENT', null);
      expect(text).toContain('available ki gayi: Haan');
      expect(text).not.toContain('□ Haan □ Nahi');
    });
  });

  describe('trade schedule isolation survives personalization', () => {
    it.each(TRADE_CODES)('%s keeps only its own schedule', (trade) => {
      const { text } = personalize('TRADE_SPECIFIC_SERVICE_AGREEMENT', trade);
      const headings = {
        ELECTRICIAN: 'SCHEDULE E — ELECTRICIAN',
        PLUMBER: 'SCHEDULE P — PLUMBER',
        AC_TECHNICIAN: 'SCHEDULE A — AC TECHNICIAN',
        CARPENTER: 'SCHEDULE C — CARPENTER',
      } as const;

      expect(text).toContain(headings[trade]);
      for (const other of TRADE_CODES) {
        if (other !== trade) expect(text).not.toContain(headings[other]);
      }
    });
  });

  describe('missing mandatory data blocks generation', () => {
    it.each([
      ['fullLegalName', { fullLegalName: '' }],
      ['cnicNumber', { cnicNumber: '' }],
      ['registeredMobile', { registeredMobile: '' }],
      ['ustaadAccountId', { ustaadAccountId: '' }],
      ['residentialAddress', { residentialAddress: null }],
    ] as const)('refuses to generate without %s', (field, override) => {
      expect(() =>
        personalize('USTAAD_SERVICE_PROVIDER_AGREEMENT', null, {
          ...COMPLETE,
          ...override,
        } as PersonalizationData),
      ).toThrow(MissingAgreementDataError);
    });

    it('names the exact profile fields to fix', () => {
      try {
        personalize('BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE', null, {
          ...COMPLETE,
          fatherName: null,
          dateOfBirth: null,
        });
        fail('should have thrown');
      } catch (err) {
        const e = err as MissingAgreementDataError;
        const fields = e.missingFields.map((f) => f.profileField);
        expect(fields).toContain('fatherName');
        expect(fields).toContain('dateOfBirth');
      }
    });

    it('never produces partial output when it throws', () => {
      // No half-written document can escape — the throw happens before the
      // text is returned or hashed.
      expect(() =>
        personalize('USTAAD_SERVICE_PROVIDER_AGREEMENT', null, {
          ...COMPLETE,
          cnicNumber: '',
        }),
      ).toThrow();
    });
  });

  describe('non-applicable fields use a controlled value', () => {
    it('prints "Not applicable" instead of an empty blank', () => {
      const { text, notApplicable } = personalize(
        'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE',
        null,
        {
          ...COMPLETE,
          emergencyContact: null,
          verificationProvider: null,
          verificationRequestDate: null,
          verificationRequestReference: null,
        },
      );

      expect(text).toContain(NOT_APPLICABLE);
      expect(findUnresolvedContent(text).blanks).toEqual([]);
      expect(notApplicable).toContain('Verification Provider/Agency');
    });

    it('always marks the HandyGo reviewer line, signed after review', () => {
      const { notApplicable } = personalize(
        'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE',
        null,
      );
      expect(notApplicable).toContain('Authorized HandyGo Reviewer');
    });
  });

  describe('service tag formatting', () => {
    it('joins tags readably and treats empty as absent', () => {
      expect(formatServiceTags(['Fan', 'Socket'], 'ELECTRICIAN')).toBe('Fan, Socket');
      expect(formatServiceTags([], 'ELECTRICIAN')).toBeNull();
      expect(formatServiceTags(null, 'ELECTRICIAN')).toBeNull();
    });
  });
});
