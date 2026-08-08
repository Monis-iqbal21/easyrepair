import { AgreementType } from '@prisma/client';
import {
  CustomerAcceptanceInput,
  CustomerAcceptanceService,
  CustomerAgreementSubmissionError,
} from './customer-acceptance.service';
import { loadCustomerSourceText } from './source/customer-agreement-source.registry';
import { findUnresolvedContent } from './source/agreement-validation.util';

/**
 * The Client acceptance flow — a single-document sibling of
 * UstaadAcceptanceService (see ustaad-acceptance.service.spec.ts). Pins:
 * exactly one immutable record, idempotent duplicate acceptance, separate
 * records per client, checkbox enforcement, and no orphaned PDFs on failure.
 */

function makeInput(
  over: Partial<CustomerAcceptanceInput> = {},
): CustomerAcceptanceInput {
  return {
    clientProfileId: 'cp-1234567890abcdef',
    userId: 'user-1',
    fullLegalName: 'Ayesha Siddiqui',
    registeredMobile: '+92 300 1234567',
    ipAddress: '203.0.113.9',
    deviceInfo: 'android/session-7f3a',
    checkboxAccepted: true,
    ...over,
  };
}

function makeService() {
  const rows = new Map<string, any>();
  let seq = 0;

  const repository = {
    findClientAcceptanceByUniqueKey: jest.fn(
      async (
        clientProfileId: string,
        agreementType: AgreementType,
        agreementVersion: string,
        agreementHash: string,
      ) => {
        const key = `${clientProfileId}|${agreementType}|${agreementVersion}|${agreementHash}`;
        return rows.get(key) ?? null;
      },
    ),
    createClientAcceptance: jest.fn(async (data: any) => {
      const key = `${data.clientProfileId}|${data.agreementType}|${data.agreementVersion}|${data.agreementHash}`;
      const existing = rows.get(key);
      if (existing) return existing;
      const row = { ...data, id: `row-${++seq}` };
      rows.set(key, row);
      return row;
    }),
  };
  const storage = {
    uploadFile: jest.fn(
      async (_b: Buffer, name: string, _mime: string, _prefix: string) => ({
        url: `https://cdn/${name}`,
        key: `uploads/${name}`,
        sizeBytes: 1,
        mimeType: 'application/pdf',
        fileName: name,
      }),
    ),
    deleteByUrl: jest.fn().mockResolvedValue(undefined),
  };
  const service = new CustomerAcceptanceService(
    repository as never,
    storage as never,
  );
  return { service, repository, storage, rows };
}

describe('CustomerAcceptanceService', () => {
  jest.setTimeout(30000);

  describe('a new acceptance', () => {
    it('creates exactly one immutable record for Version 1.0', async () => {
      const { service } = makeService();
      const result = await service.accept(makeInput());

      expect(result.documentType).toBe(
        'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
      );
      expect(result.agreementType).toBe(
        AgreementType.CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE,
      );
      expect(result.version).toBe('1.0');
      expect(result.reused).toBe(false);
      expect(result.acceptanceId).toMatch(/^HG-ACC-\d{4}-[A-F0-9]{12}$/);
      expect(result.sourceHash).toMatch(/^[0-9a-f]{64}$/);
      expect(result.acceptedDocumentHash).toMatch(/^[0-9a-f]{64}$/);
      expect(result.acceptedPdfHash).toMatch(/^[0-9a-f]{64}$/);
    });

    it('uploads the personalized PDF to the client-scoped storage path', async () => {
      const { service, storage } = makeService();
      await service.accept(makeInput({ clientProfileId: 'cp-abc' }));

      expect(storage.uploadFile).toHaveBeenCalledTimes(1);
      const [, , , keyPrefix] = storage.uploadFile.mock.calls[0];
      expect(keyPrefix).toBe('uploads/client-documents/cp-abc/agreements');
    });

    it('seals a personalized snapshot with no leftover blanks', async () => {
      const { service, repository } = makeService();
      await service.accept(makeInput());

      const created = repository.createClientAcceptance.mock.calls[0][0];
      expect(created.acceptedDocumentSnapshot).toContain('Ayesha Siddiqui');
      expect(created.acceptedDocumentSnapshot).toContain('+92 300 1234567');
      expect(
        findUnresolvedContent(created.acceptedDocumentSnapshot).blanks,
      ).toEqual([]);
    });

    it('snapshots the exact source document and its hash', async () => {
      const { service, repository } = makeService();
      const source = loadCustomerSourceText(
        'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
        'ur_Latn',
      );
      await service.accept(makeInput());

      const created = repository.createClientAcceptance.mock.calls[0][0];
      expect(created.agreementContentSnapshot).toBe(source.text);
      expect(created.agreementHash).toBe(source.sha256);
      expect(created.sourceDocumentHash).toBe(source.sha256);
    });
  });

  describe('checkbox enforcement', () => {
    it('rejects when the checkbox was not ticked', async () => {
      const { service, repository } = makeService();
      await expect(
        service.accept(makeInput({ checkboxAccepted: false })),
      ).rejects.toThrow(CustomerAgreementSubmissionError);
      expect(repository.createClientAcceptance).not.toHaveBeenCalled();
    });

    it('carries the NOT_ACCEPTED code', async () => {
      const { service } = makeService();
      try {
        await service.accept(makeInput({ checkboxAccepted: false }));
        fail('expected rejection');
      } catch (err) {
        expect((err as CustomerAgreementSubmissionError).code).toBe(
          'NOT_ACCEPTED',
        );
      }
    });
  });

  describe('missing profile data', () => {
    it('rejects when the registered name is missing', async () => {
      const { service } = makeService();
      await expect(
        service.accept(makeInput({ fullLegalName: '' })),
      ).rejects.toThrow(CustomerAgreementSubmissionError);
    });

    it('rejects when the registered mobile is missing', async () => {
      const { service } = makeService();
      await expect(
        service.accept(makeInput({ registeredMobile: '' })),
      ).rejects.toThrow(CustomerAgreementSubmissionError);
    });
  });

  describe('idempotency', () => {
    it('a repeated acceptance for the same client returns the SAME record', async () => {
      const { service, storage } = makeService();
      const input = makeInput();

      const first = await service.accept(input);
      const second = await service.accept(input);

      expect(second.id).toBe(first.id);
      expect(second.acceptanceId).toBe(first.acceptanceId);
      expect(second.reused).toBe(true);
      // Only the first attempt generated and uploaded a PDF.
      expect(storage.uploadFile).toHaveBeenCalledTimes(1);
    });

    it('never creates a duplicate row for the same client/version/hash', async () => {
      const { service, repository } = makeService();
      const input = makeInput();

      await service.accept(input);
      await service.accept(input);

      expect(repository.createClientAcceptance).toHaveBeenCalledTimes(1);
    });

    it('a future version/hash forces a new acceptance while Version 1.0 is retained', async () => {
      // Simulates the state after a hypothetical Version 2.0 ships: the
      // client already accepted 1.0 (seeded directly, as if from history),
      // and now accepts again against whatever the registry currently
      // resolves to. The two rows must coexist — the old one is never
      // overwritten or deleted.
      const { service, repository, rows } = makeService();
      const input = makeInput({ clientProfileId: 'cp-upgrading' });

      const oldVersionKey =
        'cp-upgrading|CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE|0.9|' +
        '0'.repeat(64);
      rows.set(oldVersionKey, {
        id: 'row-old-version',
        acceptanceId: 'HG-ACC-2025-OLDVERSION00001',
        agreementType: 'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
        agreementTitle: 'HandyGo Customer Terms, Booking Rules aur Privacy Notice',
        agreementVersion: '0.9',
        sourceDocumentHash: '0'.repeat(64),
        acceptedDocumentHash: '0'.repeat(64),
        acceptedPdfHash: '0'.repeat(64),
        acceptedAt: new Date('2025-01-01T00:00:00.000Z'),
      });

      const result = await service.accept(input);

      // The current (1.0) acceptance was created fresh — not reused.
      expect(result.version).toBe('1.0');
      expect(result.reused).toBe(false);
      expect(result.acceptanceId).not.toBe('HG-ACC-2025-OLDVERSION00001');

      // The old 0.9 row is still there, completely untouched.
      const preserved = rows.get(oldVersionKey);
      expect(preserved.acceptanceId).toBe('HG-ACC-2025-OLDVERSION00001');
      expect(preserved.agreementVersion).toBe('0.9');

      expect(repository.createClientAcceptance).toHaveBeenCalledTimes(1);
    });
  });

  describe('separate clients', () => {
    it('two different clients each get their own acceptance record', async () => {
      const { service } = makeService();
      const a = await service.accept(makeInput({ clientProfileId: 'cp-a' }));
      const b = await service.accept(makeInput({ clientProfileId: 'cp-b' }));

      expect(a.id).not.toBe(b.id);
      expect(a.acceptanceId).not.toBe(b.acceptanceId);
    });
  });

  describe('failure safety', () => {
    it('rolls back the uploaded PDF when the database write fails', async () => {
      const { service, repository, storage } = makeService();
      repository.createClientAcceptance.mockRejectedValueOnce(
        new Error('db unavailable'),
      );

      await expect(service.accept(makeInput())).rejects.toThrow(
        'db unavailable',
      );
      expect(storage.deleteByUrl).toHaveBeenCalledTimes(1);
    });
  });

  describe('account id derivation', () => {
    it('is stable for the same client profile id', () => {
      const a = CustomerAcceptanceService.accountIdFor('cp-1234567890');
      const b = CustomerAcceptanceService.accountIdFor('cp-1234567890');
      expect(a).toBe(b);
      expect(a).toMatch(/^HG-CUSTOMER-[A-Z0-9]{10}$/);
    });

    it('differs for different client profile ids', () => {
      const a = CustomerAcceptanceService.accountIdFor('cp-aaaaaaaaaa');
      const b = CustomerAcceptanceService.accountIdFor('cp-bbbbbbbbbb');
      expect(a).not.toBe(b);
    });
  });
});
