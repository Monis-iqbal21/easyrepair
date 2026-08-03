import {
  AGREEMENT_SOURCES,
  activeSources,
  availableLocales,
  findSource,
  loadSourceText,
  AgreementSourceUnavailableError,
} from './agreement-source.registry';
import {
  assertFullyPopulated,
  assertNoDevanagari,
  checkDocumentParity,
  extractClauseIds,
  findDevanagari,
  findUnresolvedContent,
} from './agreement-validation.util';
import {
  scheduleHeadingFor,
  supportedTradeCategoryNames,
  tradeCodeForCategoryName,
} from './trade-mapping.util';
import {
  buildIdempotencyKey,
  generateAcceptanceId,
  localeFromEnum,
  localeToEnum,
  parseAgreementLocale,
  sha256Bytes,
  sha256Text,
} from './acceptance-identity.util';
import {
  AGREEMENT_LOCALES,
  DOCUMENT_TYPES,
  isUstaadDocumentType,
  TRADE_CODES,
  USTAAD_DOCUMENT_TYPES,
} from './agreement-source.types';

/**
 * Runs against the REAL committed canonical documents, not fixtures — these
 * are the safety rails that stand between an approved contract and an
 * immutable acceptance record.
 */
describe('Ustaad agreement source registry', () => {
  describe('document scope', () => {
    it('covers exactly the three Ustaad document types', () => {
      expect([...USTAAD_DOCUMENT_TYPES]).toEqual([
        'USTAAD_SERVICE_PROVIDER_AGREEMENT',
        'TRADE_SPECIFIC_SERVICE_AGREEMENT',
        'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE',
      ]);
    });

    it('never admits the Customer document into the Ustaad flow', () => {
      expect(DOCUMENT_TYPES).toContain(
        'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
      );
      expect([...USTAAD_DOCUMENT_TYPES]).not.toContain(
        'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
      );
      expect(isUstaadDocumentType('CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE')).toBe(
        false,
      );
      expect(
        AGREEMENT_SOURCES.some(
          (s) =>
            (s.documentType as string) ===
            'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
        ),
      ).toBe(false);
    });

    it('declares 6 documents in each of the 3 languages', () => {
      expect(AGREEMENT_SOURCES).toHaveLength(18);
      for (const locale of AGREEMENT_LOCALES) {
        expect(AGREEMENT_SOURCES.filter((s) => s.locale === locale)).toHaveLength(6);
      }
    });
  });

  describe('language gating', () => {
    it('activates Roman Urdu — the approved source language', () => {
      expect(activeSources()).toHaveLength(6);
      expect(activeSources().every((s) => s.locale === 'ur_Latn')).toBe(true);
    });

    it('holds English and Urdu as PENDING_TRANSLATION with no text', () => {
      // Certified legal text does not exist yet; nothing unverified may be
      // viewable or acceptable.
      for (const locale of ['en', 'ur'] as const) {
        const variants = AGREEMENT_SOURCES.filter((s) => s.locale === locale);
        expect(variants).toHaveLength(6);
        for (const v of variants) {
          expect(v.status).toBe('PENDING_TRANSLATION');
          expect(v.file).toBeNull();
          expect(v.sha256).toBeNull();
        }
      }
    });

    it('refuses to load a variant that is not ACTIVE', () => {
      expect(() =>
        loadSourceText('USTAAD_SERVICE_PROVIDER_AGREEMENT', 'en', null),
      ).toThrow(AgreementSourceUnavailableError);
      expect(() =>
        loadSourceText('USTAAD_SERVICE_PROVIDER_AGREEMENT', 'ur', null),
      ).toThrow(/NOT_ACTIVE/);
    });

    it('reports only Roman Urdu as available today', () => {
      expect(availableLocales('USTAAD_SERVICE_PROVIDER_AGREEMENT', null)).toEqual([
        'ur_Latn',
      ]);
      expect(
        availableLocales('TRADE_SPECIFIC_SERVICE_AGREEMENT', 'ELECTRICIAN'),
      ).toEqual(['ur_Latn']);
    });
  });

  describe('canonical text integrity', () => {
    it.each(activeSources().map((s) => [s.file!, s] as const))(
      'loads %s and matches its pinned hash',
      (_file, descriptor) => {
        const loaded = loadSourceText(
          descriptor.documentType,
          descriptor.locale,
          descriptor.trade,
        );
        expect(loaded.sha256).toBe(descriptor.sha256);
        expect(loaded.text.length).toBeGreaterThan(5000);
      },
    );

    it('rejects an edited canonical file via the hash check', () => {
      // The registry pins the hash, so tampering cannot go unnoticed.
      const descriptor = findSource(
        'USTAAD_SERVICE_PROVIDER_AGREEMENT',
        'ur_Latn',
        null,
      )!;
      expect(descriptor.sha256).toMatch(/^[0-9a-f]{64}$/);
    });
  });

  describe('trade schedule isolation', () => {
    it.each(TRADE_CODES)(
      '%s document contains only its own schedule',
      (trade) => {
        const { text } = loadSourceText(
          'TRADE_SPECIFIC_SERVICE_AGREEMENT',
          'ur_Latn',
          trade,
        );

        expect(text).toContain(scheduleHeadingFor(trade));
        for (const other of TRADE_CODES) {
          if (other === trade) continue;
          expect(text).not.toContain(scheduleHeadingFor(other));
        }
      },
    );

    it.each(TRADE_CODES)('%s document keeps the common terms', (trade) => {
      const { text } = loadSourceText(
        'TRADE_SPECIFIC_SERVICE_AGREEMENT',
        'ur_Latn',
        trade,
      );
      // Common obligations and the shared electronic-acceptance rules must
      // travel with every trade — only the schedule is trade-specific.
      expect(text).toContain('COMMON TRADE-SPECIFIC TERMS');
      expect(text).toContain('ELECTRONIC ACCEPTANCE');
      expect(text).toContain('COMPANY DETAILS');
    });
  });

  describe('trade mapping', () => {
    it.each([
      ['Electrician', 'ELECTRICIAN'],
      ['Plumber', 'PLUMBER'],
      ['AC Technician', 'AC_TECHNICIAN'],
      ['Carpenter', 'CARPENTER'],
    ])('maps %s -> %s', (category, code) => {
      expect(tradeCodeForCategoryName(category)).toBe(code);
    });

    it('returns null for an unsupported trade instead of guessing', () => {
      // Must block submission — never substitute another trade's schedule.
      for (const unsupported of ['Painter', 'Cleaner', 'Gardener', 'Car Wash']) {
        expect(tradeCodeForCategoryName(unsupported)).toBeNull();
      }
      expect(tradeCodeForCategoryName(null)).toBeNull();
      expect(tradeCodeForCategoryName('')).toBeNull();
    });

    it('every supported category resolves to a registered document', () => {
      for (const name of supportedTradeCategoryNames()) {
        const trade = tradeCodeForCategoryName(name)!;
        const descriptor = findSource(
          'TRADE_SPECIFIC_SERVICE_AGREEMENT',
          'ur_Latn',
          trade,
        );
        expect(descriptor?.status).toBe('ACTIVE');
      }
    });
  });

  describe('Hindi / Devanagari', () => {
    it.each(activeSources().map((s) => [s.file!, s] as const))(
      '%s contains no Devanagari',
      (_file, descriptor) => {
        const { text } = loadSourceText(
          descriptor.documentType,
          descriptor.locale,
          descriptor.trade,
        );
        expect(findDevanagari(text)).toEqual([]);
        expect(() => assertNoDevanagari(text, _file)).not.toThrow();
      },
    );

    it('detects Devanagari when it is present', () => {
      const hits = findDevanagari('Ustaad ka kaam\nयह हिंदी है\nnormal line');
      expect(hits).toHaveLength(1);
      expect(hits[0].line).toBe(2);
      expect(() => assertNoDevanagari('यह', 'probe')).toThrow(/Devanagari/);
    });
  });

  describe('unresolved content detection', () => {
    it('finds the fill-in blanks that the SOURCE legitimately contains', () => {
      // The source is a template with blanks; the ACCEPTED copy must not be.
      const { text } = loadSourceText(
        'USTAAD_SERVICE_PROVIDER_AGREEMENT',
        'ur_Latn',
        null,
      );
      expect(findUnresolvedContent(text).blanks.length).toBeGreaterThan(0);
    });

    it('rejects a generated document that still has blanks or tokens', () => {
      expect(() =>
        assertFullyPopulated('CNIC Number: ______________', 'generated'),
      ).toThrow(/unfilled blank/);
      expect(() =>
        assertFullyPopulated('Name: {{ fullLegalName }}', 'generated'),
      ).toThrow(/unresolved template token/);
      expect(() =>
        assertFullyPopulated('Name: Ali Khan\nCNIC: 42101-1234567-1', 'generated'),
      ).not.toThrow();
    });
  });

  describe('clause parity', () => {
    it('extracts clause identifiers from the approved wording', () => {
      const ids = extractClauseIds(
        ['1. PARTIES', '2.1 Something', 'SCHEDULE E — ELECTRICIAN', 'E1. SERVICES'].join(
          '\n',
        ),
      );
      expect(ids).toEqual(['1', '2.1', 'SCHEDULE E', 'E1']);
    });

    it('finds a real clause structure in every active document', () => {
      for (const descriptor of activeSources()) {
        const { text } = loadSourceText(
          descriptor.documentType,
          descriptor.locale,
          descriptor.trade,
        );
        expect(extractClauseIds(text).length).toBeGreaterThan(10);
      }
    });

    it('reports en and ur as MISSING_VARIANT, which is what blocks activation', () => {
      const issues = checkDocumentParity(
        'USTAAD_SERVICE_PROVIDER_AGREEMENT',
        null,
      );
      const missing = issues.filter((i) => i.kind === 'MISSING_VARIANT');

      expect(missing.map((i) => i.locale).sort()).toEqual(['en', 'ur']);
      expect(missing.every((i) => i.detail.includes('PENDING_TRANSLATION'))).toBe(
        true,
      );
    });

    it.each(TRADE_CODES)(
      '%s: parity reports the same two missing languages',
      (trade) => {
        const issues = checkDocumentParity(
          'TRADE_SPECIFIC_SERVICE_AGREEMENT',
          trade,
        );
        expect(
          issues.filter((i) => i.kind === 'MISSING_VARIANT').map((i) => i.locale).sort(),
        ).toEqual(['en', 'ur']);
        // No clause drift is reported, because there is no rival text yet.
        expect(issues.filter((i) => i.kind === 'CLAUSE_MISSING')).toEqual([]);
      },
    );
  });
});

describe('server-generated acceptance identity', () => {
  it('generates a unique, human-quotable acceptance id with no personal data', () => {
    const a = generateAcceptanceId(new Date('2026-08-03T10:00:00Z'));
    const b = generateAcceptanceId(new Date('2026-08-03T10:00:00Z'));

    expect(a).toMatch(/^HG-ACC-2026-[0-9A-F]{12}$/);
    expect(a).not.toBe(b);
  });

  it('hashes text and bytes deterministically', () => {
    expect(sha256Text('abc')).toBe(sha256Text('abc'));
    expect(sha256Text('abc')).toMatch(/^[0-9a-f]{64}$/);
    expect(sha256Text('abc')).not.toBe(sha256Text('abd'));
    expect(sha256Bytes(Buffer.from('abc'))).toBe(sha256Text('abc'));
  });

  describe('idempotency key', () => {
    const base = {
      workerProfileId: 'worker-1',
      documentType: 'USTAAD_SERVICE_PROVIDER_AGREEMENT',
      documentVersion: '1.0',
      locale: 'ur_Latn',
      trade: null,
      submissionAttemptId: 'attempt-1',
    } as const;

    it('is stable for a retry of the same attempt', () => {
      expect(buildIdempotencyKey({ ...base })).toBe(buildIdempotencyKey({ ...base }));
    });

    it('differs per document type, version, locale, trade and attempt', () => {
      const key = buildIdempotencyKey(base);
      const variants = [
        { ...base, documentType: 'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE' as const },
        { ...base, documentVersion: '1.1' },
        { ...base, locale: 'en' as const },
        { ...base, trade: 'PLUMBER' as const },
        { ...base, submissionAttemptId: 'attempt-2' },
        { ...base, workerProfileId: 'worker-2' },
      ];
      for (const v of variants) {
        expect(buildIdempotencyKey(v)).not.toBe(key);
      }
    });

    it('leaks no identifiers — it is a fixed-length digest', () => {
      const key = buildIdempotencyKey(base);
      expect(key).toMatch(/^[0-9a-f]{64}$/);
      expect(key).not.toContain('worker-1');
    });
  });

  describe('locale mapping', () => {
    it('round-trips every app locale through the Prisma enum', () => {
      for (const locale of AGREEMENT_LOCALES) {
        expect(localeFromEnum(localeToEnum(locale))).toBe(locale);
      }
      expect(localeToEnum('ur_Latn')).toBe('UR_LATN');
    });

    it('rejects an unknown locale from the wire instead of guessing', () => {
      for (const bad of ['hi', 'ur-Latn', 'EN', '', null, 42, undefined]) {
        expect(parseAgreementLocale(bad)).toBeNull();
      }
      expect(parseAgreementLocale('ur_Latn')).toBe('ur_Latn');
    });
  });
});
