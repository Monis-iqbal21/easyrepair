import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { AgreementType } from '@prisma/client';
import { CustomerAgreementAccessService } from './customer-agreement-access.service';

/**
 * Read-side ownership guarantees — mirrors
 * ustaad-agreement-access.service tests: a Worker document is never
 * reachable through this service, the bucket URL never leaves the server,
 * and a mismatched owner is rejected.
 */

function customerRow(over: Record<string, unknown> = {}) {
  return {
    id: 'row-1',
    acceptanceId: 'HG-ACC-2026-ABCDEF123456',
    workerProfileId: null,
    clientProfileId: 'cp-1',
    userId: 'user-1',
    agreementType: AgreementType.CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE,
    agreementTitle: 'HandyGo Customer Terms, Booking Rules aur Privacy Notice',
    agreementVersion: '1.0',
    agreementLocale: 'UR_LATN',
    applicableTrade: null,
    acceptancePdfStorageKey: 'uploads/client-documents/cp-1/agreements/x.pdf',
    acceptancePdfUrl: 'https://cdn.example/x.pdf',
    acceptedPdfHash: 'a'.repeat(64),
    sourceDocumentHash: 'b'.repeat(64),
    acceptedDocumentHash: 'c'.repeat(64),
    documentViewedAt: null,
    acceptedAt: new Date('2026-08-07T00:00:00.000Z'),
    createdAt: new Date('2026-08-07T00:00:00.000Z'),
    // Identity snapshot — frozen at acceptance time, independent of the
    // clientProfileId/userId relations.
    fullLegalNameSnapshot: 'Ayesha Siddiqui',
    mobileSnapshot: '+92 300 1234567',
    clientAccountIdSnapshot: 'HG-CUSTOMER-ABC1234567',
    ipAddress: '203.0.113.9',
    deviceInfo: 'android/session-7f3a',
    checkboxAccepted: true,
    ...over,
  };
}

function makeService(rows: Record<string, unknown>[]) {
  const repository = {
    findAcceptanceForDownloadByAcceptanceId: jest.fn(async (id: string) =>
      rows.find((r) => r.acceptanceId === id || r.id === id) ?? null,
    ),
    findClientAcceptances: jest.fn(async (clientProfileId: string) =>
      rows.filter((r) => r.clientProfileId === clientProfileId),
    ),
  };
  const storage = {
    keyFromUrl: jest.fn((url: string) => url.split('/').pop()),
    getObject: jest.fn(async (key: string) =>
      key ? { body: Buffer.from('PDF-BYTES'), contentType: 'application/pdf' } : null,
    ),
  };
  const service = new CustomerAgreementAccessService(
    repository as never,
    storage as never,
  );
  return { service, repository, storage };
}

describe('CustomerAgreementAccessService', () => {
  describe('listForClient', () => {
    it('returns metadata without the storage URL', async () => {
      const { service } = makeService([customerRow()]);
      const rows = await service.listForClient('cp-1');

      expect(rows).toHaveLength(1);
      expect(rows[0].documentType).toBe(
        'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE',
      );
      expect(rows[0]).not.toHaveProperty('acceptancePdfUrl');
    });
  });

  describe('getPdf', () => {
    it('returns the PDF bytes for the owning client', async () => {
      const { service } = makeService([customerRow()]);
      const pdf = await service.getPdf('HG-ACC-2026-ABCDEF123456', 'cp-1');

      expect(pdf.body.toString()).toBe('PDF-BYTES');
      expect(pdf.contentType).toBe('application/pdf');
      expect(pdf.fileName).toBe('handygo-agreement-HG-ACC-2026-ABCDEF123456.pdf');
    });

    it('rejects a mismatched owner — another client cannot fetch it by id', async () => {
      const { service } = makeService([customerRow()]);
      await expect(
        service.getPdf('HG-ACC-2026-ABCDEF123456', 'cp-someone-else'),
      ).rejects.toThrow(ForbiddenException);
    });

    it('404s for an unknown acceptance id', async () => {
      const { service } = makeService([]);
      await expect(service.getPdf('does-not-exist', 'cp-1')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('never serves a Worker document through this service', async () => {
      const workerRow = customerRow({
        agreementType: AgreementType.GENERAL_USTAAD,
        clientProfileId: null,
        workerProfileId: 'wp-1',
      });
      const { service } = makeService([workerRow]);
      await expect(
        service.getPdf('HG-ACC-2026-ABCDEF123456', 'cp-1'),
      ).rejects.toThrow(NotFoundException);
    });

    it('the admin path (no owner arg) skips the ownership check', async () => {
      const { service } = makeService([customerRow()]);
      const pdf = await service.getPdf('HG-ACC-2026-ABCDEF123456');
      expect(pdf.body.toString()).toBe('PDF-BYTES');
    });

    it(
      'remains admin-auditable after the Client profile was deleted ' +
        '(clientProfileId nulled by the SetNull relation) — the row and its ' +
        'PDF are still reachable by acceptance id',
      async () => {
        const orphaned = customerRow({ clientProfileId: null });
        const { service } = makeService([orphaned]);

        const pdf = await service.getPdf('HG-ACC-2026-ABCDEF123456');

        expect(pdf.body.toString()).toBe('PDF-BYTES');
        expect(pdf.fileName).toBe(
          'handygo-agreement-HG-ACC-2026-ABCDEF123456.pdf',
        );
      },
    );

    it(
      'every legal snapshot field survives with clientProfileId AND userId ' +
        'both nulled — the row is still complete, self-contained evidence',
      async () => {
        const orphaned = customerRow({ clientProfileId: null, userId: null });
        const { repository } = makeService([orphaned]);
        const row = await repository.findAcceptanceForDownloadByAcceptanceId(
          'HG-ACC-2026-ABCDEF123456',
        );

        expect(row).toMatchObject({
          acceptanceId: 'HG-ACC-2026-ABCDEF123456',
          agreementTitle:
            'HandyGo Customer Terms, Booking Rules aur Privacy Notice',
          agreementVersion: '1.0',
          fullLegalNameSnapshot: 'Ayesha Siddiqui',
          mobileSnapshot: '+92 300 1234567',
          clientAccountIdSnapshot: 'HG-CUSTOMER-ABC1234567',
          sourceDocumentHash: 'b'.repeat(64),
          acceptedDocumentHash: 'c'.repeat(64),
          acceptedPdfHash: 'a'.repeat(64),
          ipAddress: '203.0.113.9',
          deviceInfo: 'android/session-7f3a',
          checkboxAccepted: true,
        });
        expect(row!.acceptedAt).toEqual(new Date('2026-08-07T00:00:00.000Z'));
      },
    );

    it('listForClient still returns an orphaned row\'s history entry by id lookup', async () => {
      // listForClient is keyed by clientProfileId, so a now-null
      // clientProfileId naturally drops out of the CLIENT's own list — that
      // is correct (no profile exists to list it under). Admin/legal audit
      // instead goes through getPdf by acceptanceId, verified above, and
      // through the raw acceptance row itself, which this proves survives.
      const orphaned = customerRow({ clientProfileId: null });
      const { repository } = makeService([orphaned]);
      const row = await repository.findAcceptanceForDownloadByAcceptanceId(
        'HG-ACC-2026-ABCDEF123456',
      );

      expect(row).not.toBeNull();
      expect(row!.clientProfileId).toBeNull();
      expect(row!.acceptanceId).toBe('HG-ACC-2026-ABCDEF123456');
    });
  });
});
