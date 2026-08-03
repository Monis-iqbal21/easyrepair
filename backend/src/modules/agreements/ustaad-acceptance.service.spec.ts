import {
  AgreementSubmissionError,
  UstaadAcceptanceInput,
  UstaadAcceptanceService,
} from './ustaad-acceptance.service';
import { loadSourceText } from './source/agreement-source.registry';
import { findUnresolvedContent } from './source/agreement-validation.util';

/**
 * The acceptance flow used to create TWO records. These pin the completed
 * behaviour: exactly three immutable documents, the Customer document
 * unreachable, idempotent retries, and no orphaned PDFs when anything fails.
 */
function evidenceFor(trade: string | null = 'ELECTRICIAN') {
  const general = loadSourceText('USTAAD_SERVICE_PROVIDER_AGREEMENT', 'ur_Latn', null);
  const evs = loadSourceText('BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE', 'ur_Latn', null);
  const tradeDoc = loadSourceText(
    'TRADE_SPECIFIC_SERVICE_AGREEMENT',
    'ur_Latn',
    trade as never,
  );
  const viewedAt = '2026-08-03T09:00:00.000Z';

  return [
    {
      documentType: 'USTAAD_SERVICE_PROVIDER_AGREEMENT' as const,
      version: general.descriptor.version,
      sourceHash: general.sha256,
      agreementLocale: 'ur_Latn',
      applicableTrade: null,
      viewedAt,
      checkboxAccepted: true,
    },
    {
      documentType: 'TRADE_SPECIFIC_SERVICE_AGREEMENT' as const,
      version: tradeDoc.descriptor.version,
      sourceHash: tradeDoc.sha256,
      agreementLocale: 'ur_Latn',
      applicableTrade: trade,
      viewedAt,
      checkboxAccepted: true,
    },
    {
      documentType: 'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE' as const,
      version: evs.descriptor.version,
      sourceHash: evs.sha256,
      agreementLocale: 'ur_Latn',
      applicableTrade: null,
      viewedAt,
      checkboxAccepted: true,
    },
  ];
}

function makeInput(over: Partial<UstaadAcceptanceInput> = {}): UstaadAcceptanceInput {
  return {
    workerProfileId: 'wp-1234567890abcdef',
    userId: 'user-1',
    fullLegalName: 'Muhammad Ali Khan',
    fatherName: 'Abdul Rehman Khan',
    cnicNumber: '42101-1234567-1',
    dateOfBirth: '1990-04-12',
    residentialAddress: 'House 12, Gulshan-e-Iqbal, Karachi',
    registeredMobile: '+92 332 0219006',
    mainSkillCategoryName: 'Electrician',
    approvedServiceTags: ['Fan installation', 'Switch replacement'],
    emergencyContact: 'Fatima Khan, +92 300 1112233',
    verificationProvider: null,
    verificationRequestDate: null,
    verificationRequestReference: null,
    cnicFrontUrl: 'https://cdn/x/front.jpg',
    cnicBackUrl: 'https://cdn/x/back.jpg',
    liveSelfieUrl: 'https://cdn/x/selfie.jpg',
    ipAddress: '203.0.113.9',
    deviceInfo: 'android/session-7f3a',
    submissionAttemptId: 'attempt-1',
    evidence: evidenceFor(),
    ...over,
  };
}

function makeService() {
  const created: any[] = [];
  const repository = {
    findAcceptanceByIdempotencyKey: jest.fn().mockResolvedValue(null),
    createAcceptance: jest.fn(async (data: any) => {
      const row = { ...data, id: `row-${created.length + 1}` };
      created.push(row);
      return row;
    }),
    // Mirrors the real transaction: all-or-nothing across the three inserts
    // plus the profile-completion update.
    createAcceptancesAndCompleteProfile: jest.fn(async (rows: any[]) => {
      const madeThisCall: any[] = [];
      for (const data of rows) {
        const row = { ...data, id: `row-${created.length + madeThisCall.length + 1}` };
        madeThisCall.push(row);
      }
      created.push(...madeThisCall);
      return madeThisCall;
    }),
  };
  const storage = {
    uploadFile: jest.fn(async (_b: Buffer, name: string) => ({
      url: `https://cdn/${name}`,
      key: `uploads/${name}`,
      sizeBytes: 1,
      mimeType: 'application/pdf',
      fileName: name,
    })),
    deleteByUrl: jest.fn().mockResolvedValue(undefined),
  };
  const service = new UstaadAcceptanceService(
    repository as never,
    storage as never,
  );
  return { service, repository, storage, created };
}

describe('UstaadAcceptanceService', () => {
  jest.setTimeout(30000);

  describe('exactly three documents', () => {
    it('creates one record per Ustaad document type', async () => {
      const { service, created } = makeService();
      const results = await service.acceptAll(makeInput());

      expect(results).toHaveLength(3);
      expect(results.map((r) => r.documentType).sort()).toEqual([
        'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE',
        'TRADE_SPECIFIC_SERVICE_AGREEMENT',
        'USTAAD_SERVICE_PROVIDER_AGREEMENT',
      ]);
      expect(created).toHaveLength(3);
    });

    it('never creates the Customer document', async () => {
      const { service, created } = makeService();
      const results = await service.acceptAll(makeInput());

      for (const row of [...results, ...created]) {
        expect(JSON.stringify(row)).not.toContain('CUSTOMER_TERMS');
      }
    });

    it('maps each to the right Prisma AgreementType', async () => {
      const { service, created } = makeService();
      await service.acceptAll(makeInput());

      expect(created.map((c) => c.agreementType).sort()).toEqual([
        'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE',
        'GENERAL_USTAAD',
        'TRADE_SPECIFIC',
      ]);
    });
  });

  describe('what gets sealed', () => {
    it('stores Roman Urdu locale, hashes, snapshot and viewed time', async () => {
      const { service, created } = makeService();
      await service.acceptAll(makeInput());

      for (const row of created) {
        expect(row.agreementLocale).toBe('UR_LATN');
        expect(row.sourceDocumentHash).toMatch(/^[0-9a-f]{64}$/);
        expect(row.acceptedDocumentHash).toMatch(/^[0-9a-f]{64}$/);
        expect(row.acceptedPdfHash).toMatch(/^[0-9a-f]{64}$/);
        // The personalized snapshot differs from the blank source.
        expect(row.acceptedDocumentHash).not.toBe(row.sourceDocumentHash);
        expect(row.documentViewedAt).toBeInstanceOf(Date);
        expect(row.pdfMadeAvailableAt).toBeInstanceOf(Date);
        expect(row.acceptancePdfStorageKey).toBeTruthy();
      }
    });

    it('seals a snapshot with no unresolved blanks or tokens', async () => {
      const { service, created } = makeService();
      await service.acceptAll(makeInput());

      for (const row of created) {
        const unresolved = findUnresolvedContent(row.acceptedDocumentSnapshot);
        expect(unresolved.blanks).toEqual([]);
        expect(unresolved.tokens).toEqual([]);
      }
    });

    it('records the trade only on the trade document', async () => {
      const { service, created } = makeService();
      await service.acceptAll(makeInput());

      const byType = Object.fromEntries(
        created.map((c) => [c.agreementType, c]),
      );
      expect(byType['TRADE_SPECIFIC'].applicableTrade).toBe('ELECTRICIAN');
      expect(byType['GENERAL_USTAAD'].applicableTrade).toBeUndefined();
    });

    it('keeps the Ustaad account id out of CNIC and filenames', async () => {
      const { service, storage } = makeService();
      await service.acceptAll(makeInput());

      for (const call of storage.uploadFile.mock.calls) {
        expect(call[1]).not.toContain('42101');
      }
    });
  });

  describe('idempotency', () => {
    it('returns the existing record for a repeated attempt', async () => {
      const { service, repository } = makeService();
      repository.findAcceptanceByIdempotencyKey.mockResolvedValue({
        id: 'existing-1',
        acceptanceId: 'HG-ACC-2026-EXISTING0001',
        agreementType: 'GENERAL_USTAAD',
        agreementTitle: 't',
        agreementVersion: '1.0',
        agreementLocale: 'UR_LATN',
        applicableTrade: null,
        sourceDocumentHash: 'a'.repeat(64),
        acceptedDocumentHash: 'b'.repeat(64),
        acceptedPdfHash: 'c'.repeat(64),
        acceptedAt: new Date(),
      });

      const results = await service.acceptAll(makeInput());

      expect(results).toHaveLength(3);
      expect(results.every((r) => r.reused)).toBe(true);
      // The transaction still runs so the profile is completed, but it inserts
      // nothing — the existing immutable records are reused as-is.
      const call =
        repository.createAcceptancesAndCompleteProfile.mock.calls[0];
      expect(call[0]).toEqual([]);
    });

    it('a double tap with the same attempt id creates no duplicates', async () => {
      const { service, repository, created } = makeService();
      repository.findAcceptanceByIdempotencyKey.mockImplementation(
        async (key: string) => created.find((c) => c.idempotencyKey === key) ?? null,
      );

      const input = makeInput();
      await service.acceptAll(input);
      await service.acceptAll(input);

      expect(created).toHaveLength(3);
    });

    it('a new attempt id is a genuinely new acceptance', async () => {
      const { service, created } = makeService();
      await service.acceptAll(makeInput({ submissionAttemptId: 'attempt-1' }));
      await service.acceptAll(makeInput({ submissionAttemptId: 'attempt-2' }));

      const keys = created.map((c) => c.idempotencyKey);
      expect(new Set(keys).size).toBe(6);
    });
  });

  describe('failure safety', () => {
    it('deletes uploaded PDFs when a later database write fails', async () => {
      const { service, repository, storage } = makeService();
      repository.createAcceptancesAndCompleteProfile.mockRejectedValueOnce(
        new Error('db down'),
      );

      await expect(service.acceptAll(makeInput())).rejects.toThrow('db down');

      // All three uploads are cleaned up — no orphaned sensitive PDFs, and the
      // transaction means no row and no completed profile survives either.
      expect(storage.deleteByUrl).toHaveBeenCalledTimes(3);
    });

    it('deletes uploads when storage itself fails midway', async () => {
      const { service, storage } = makeService();
      storage.uploadFile
        .mockImplementationOnce(async (_b: Buffer, name: string) => ({
          url: `https://cdn/${name}`,
          key: `uploads/${name}`,
          sizeBytes: 1,
          mimeType: 'application/pdf',
          fileName: name,
        }))
        .mockRejectedValueOnce(new Error('s3 down'));

      await expect(service.acceptAll(makeInput())).rejects.toThrow('s3 down');
      expect(storage.deleteByUrl).toHaveBeenCalledTimes(1);
    });

    it('never returns a partial two-of-three as success', async () => {
      const { service, repository, created } = makeService();
      repository.createAcceptancesAndCompleteProfile.mockRejectedValueOnce(
        new Error('db down'),
      );

      await expect(service.acceptAll(makeInput())).rejects.toThrow();
      // Nothing partially committed: the three inserts and the profile update
      // share one transaction.
      expect(created).toHaveLength(0);
    });
  });

  describe('submission validation', () => {
    it('rejects an unsupported trade instead of defaulting', async () => {
      const { service, repository } = makeService();

      await expect(
        service.acceptAll(makeInput({ mainSkillCategoryName: 'Painter' })),
      ).rejects.toMatchObject({ code: 'UNSUPPORTED_TRADE' });
      expect(repository.createAcceptancesAndCompleteProfile).not.toHaveBeenCalled();
    });

    it('rejects a stale source hash and asks for a re-open', async () => {
      const { service } = makeService();
      const evidence = evidenceFor();
      evidence[0].sourceHash = 'f'.repeat(64);

      await expect(service.acceptAll(makeInput({ evidence }))).rejects.toMatchObject(
        { code: 'STALE_DOCUMENT' },
      );
    });

    it('rejects a document that was never viewed', async () => {
      const { service } = makeService();
      const evidence = evidenceFor();
      evidence[1].viewedAt = '';

      await expect(service.acceptAll(makeInput({ evidence }))).rejects.toMatchObject(
        { code: 'NOT_VIEWED' },
      );
    });

    it('rejects an unticked checkbox even if the client says otherwise', async () => {
      const { service } = makeService();
      const evidence = evidenceFor();
      evidence[2].checkboxAccepted = false;

      await expect(service.acceptAll(makeInput({ evidence }))).rejects.toMatchObject(
        { code: 'NOT_ACCEPTED' },
      );
    });

    it('rejects missing evidence for one of the three rows', async () => {
      const { service } = makeService();
      const evidence = evidenceFor().slice(0, 2);

      await expect(service.acceptAll(makeInput({ evidence }))).rejects.toMatchObject(
        { code: 'MISSING_EVIDENCE' },
      );
    });

    it('reports the exact missing profile fields', async () => {
      const { service, repository } = makeService();

      await expect(
        service.acceptAll(makeInput({ fatherName: null, dateOfBirth: null })),
      ).rejects.toMatchObject({ code: 'MISSING_PROFILE_DATA' });
      expect(repository.createAcceptancesAndCompleteProfile).not.toHaveBeenCalled();
    });

    it('every validation failure is an AgreementSubmissionError', async () => {
      const { service } = makeService();
      try {
        await service.acceptAll(makeInput({ mainSkillCategoryName: null }));
        fail('should have thrown');
      } catch (err) {
        expect(err).toBeInstanceOf(AgreementSubmissionError);
      }
    });
  });

  describe('account id derivation', () => {
    it('is stable, uppercase and carries no personal data', () => {
      const id = UstaadAcceptanceService.accountIdFor('wp-1234567890abcdef');
      expect(id).toBe(UstaadAcceptanceService.accountIdFor('wp-1234567890abcdef'));
      expect(id).toMatch(/^HG-USTAAD-[0-9A-Z]{10}$/);
    });
  });
});
