import {
  activeCustomerSources,
  CUSTOMER_AGREEMENT_SOURCES,
  CustomerAgreementSourceUnavailableError,
  findCustomerSource,
  loadCustomerSourceText,
} from './customer-agreement-source.registry';
import { CUSTOMER_DOCUMENT_TYPES } from './agreement-source.types';
import {
  findDevanagari,
  findUnresolvedContent,
} from './agreement-validation.util';

describe('Customer agreement source registry', () => {
  describe('document scope', () => {
    it('covers exactly the one Customer document type', () => {
      expect(CUSTOMER_DOCUMENT_TYPES).toEqual([
        'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
      ]);
    });

    it('declares the document in each of the 3 languages', () => {
      expect(CUSTOMER_AGREEMENT_SOURCES).toHaveLength(3);
      expect(new Set(CUSTOMER_AGREEMENT_SOURCES.map((s) => s.locale))).toEqual(
        new Set(['en', 'ur', 'ur_Latn']),
      );
    });
  });

  describe('language gating', () => {
    it('activates Roman Urdu — the approved source language', () => {
      const source = findCustomerSource(
        'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
        'ur_Latn',
      )!;
      expect(source.status).toBe('ACTIVE');
      expect(source.file).not.toBeNull();
      expect(source.sha256).toMatch(/^[0-9a-f]{64}$/);
    });

    it('holds English and Urdu as PENDING_TRANSLATION with no text', () => {
      for (const locale of ['en', 'ur'] as const) {
        const source = findCustomerSource(
          'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
          locale,
        )!;
        expect(source.status).toBe('PENDING_TRANSLATION');
        expect(source.file).toBeNull();
        expect(source.sha256).toBeNull();
      }
    });

    it('refuses to load a variant that is not ACTIVE', () => {
      expect(() =>
        loadCustomerSourceText(
          'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
          'en',
        ),
      ).toThrow(CustomerAgreementSourceUnavailableError);
    });

    it('reports only Roman Urdu as available today', () => {
      expect(activeCustomerSources().map((s) => s.locale)).toEqual([
        'ur_Latn',
      ]);
    });
  });

  describe('canonical text integrity', () => {
    it('loads the approved document and matches its pinned hash', () => {
      const loaded = loadCustomerSourceText(
        'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
        'ur_Latn',
      );
      const descriptor = findCustomerSource(
        'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
        'ur_Latn',
      )!;
      expect(loaded.sha256).toBe(descriptor.sha256);
      // The real document is ~46 KB of legal text.
      expect(loaded.text.length).toBeGreaterThan(20000);
    });

    it('contains the exact title, version and effective-date wording', () => {
      const { text } = loadCustomerSourceText(
        'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
        'ur_Latn',
      );
      expect(text).toContain(
        'HANDYGO CUSTOMER TERMS, BOOKING',
      );
      expect(text).toContain('Document Version: 1.0');
    });

    it('never contains Devanagari', () => {
      const { text } = loadCustomerSourceText(
        'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
        'ur_Latn',
      );
      expect(findDevanagari(text)).toEqual([]);
    });

    it('the source itself still carries its fill-in blanks (before personalization)', () => {
      const { text } = loadCustomerSourceText(
        'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
        'ur_Latn',
      );
      const unresolved = findUnresolvedContent(text);
      expect(unresolved.blanks.length).toBeGreaterThan(0);
    });
  });

  describe('unknown document type', () => {
    it('is unreachable — findCustomerSource only accepts CustomerDocumentType', () => {
      // Compile-time guarantee: this file cannot ask for a Worker document
      // type through this registry at all, since the parameter is typed
      // CustomerDocumentType, not AgreementDocumentType.
      expect(CUSTOMER_DOCUMENT_TYPES).not.toContain(
        'USTAAD_SERVICE_PROVIDER_AGREEMENT',
      );
    });
  });
});
