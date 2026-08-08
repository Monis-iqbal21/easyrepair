import { Prisma } from '@prisma/client';

/**
 * Guards the legal-preservation guarantee on AgreementAcceptance: this row is
 * permanent evidence of an electronic acceptance, so a Client profile or User
 * account being deleted/deactivated/closed must never take it with it.
 *
 * These read the REAL generated Prisma DMMF (Prisma.dmmf), not just the
 * source text of schema.prisma — so a schema change that accidentally
 * reintroduces `onDelete: Cascade` (via any syntax) fails here, at the
 * compiled-client level the app actually runs against.
 */
function agreementAcceptanceModel() {
  const model = Prisma.dmmf.datamodel.models.find(
    (m) => m.name === 'AgreementAcceptance',
  );
  if (!model) throw new Error('AgreementAcceptance model not found in DMMF');
  return model;
}

function field(name: string) {
  const model = agreementAcceptanceModel();
  const f = model.fields.find((x) => x.name === name);
  if (!f) throw new Error(`Field "${name}" not found on AgreementAcceptance`);
  return f;
}

describe('AgreementAcceptance — legal-preservation relations', () => {
  describe('CLIENT: deleting the ClientProfile must not delete the acceptance', () => {
    it('the clientProfile relation is SetNull, never Cascade', () => {
      const relation = field('clientProfile');
      expect(relation.kind).toBe('object');
      expect((relation as { relationOnDelete?: string }).relationOnDelete).toBe(
        'SetNull',
      );
    });

    it('clientProfileId is nullable, so it can actually receive NULL', () => {
      const scalar = field('clientProfileId');
      expect(scalar.isRequired).toBe(false);
    });
  });

  describe('User account deletion must not delete the acceptance either', () => {
    it('the user relation is SetNull, never Cascade', () => {
      const relation = field('user');
      expect(relation.kind).toBe('object');
      expect((relation as { relationOnDelete?: string }).relationOnDelete).toBe(
        'SetNull',
      );
    });

    it('userId is nullable, so it can actually receive NULL', () => {
      const scalar = field('userId');
      expect(scalar.isRequired).toBe(false);
    });
  });

  describe('WORKER/Ustaad behavior is unchanged', () => {
    it('the workerProfile relation is still Cascade, exactly as before', () => {
      const relation = field('workerProfile');
      expect(relation.kind).toBe('object');
      expect((relation as { relationOnDelete?: string }).relationOnDelete).toBe(
        'Cascade',
      );
    });

    it('workerProfileId is still nullable (unrelated pre-existing change)', () => {
      const scalar = field('workerProfileId');
      expect(scalar.isRequired).toBe(false);
    });
  });

  describe('immutable snapshot fields survive independently of any relation', () => {
    // These are what an admin/legal audit actually reads. None of them may
    // ever be dropped or become droppable as a side effect of the
    // relation fix — they are the record once its FKs are nulled out.
    const requiredEvidenceFields = [
      'acceptanceId',
      'agreementType',
      'agreementTitle',
      'agreementVersion',
      'agreementContentSnapshot',
      'agreementHash',
      'fullLegalNameSnapshot',
      'mobileSnapshot',
      'acceptedAt',
      'checkboxAccepted',
    ];

    it.each(requiredEvidenceFields)('%s is still present on the model', (name) => {
      expect(() => field(name)).not.toThrow();
    });

    it('acceptanceId stays globally unique — still the stable public identifier', () => {
      const f = field('acceptanceId');
      expect(f.isUnique || f.isId).toBe(true);
    });

    // Nullable by design (not every row has every optional evidence field —
    // e.g. a Client row has no CNIC), but must still exist as columns so a
    // populated one is never lost.
    const optionalEvidenceFields = [
      'clientAccountIdSnapshot',
      'sourceDocumentHash',
      'acceptedDocumentHash',
      'acceptedPdfHash',
      'acceptedDocumentSnapshot',
      'acceptancePdfUrl',
      'acceptancePdfStorageKey',
      'ipAddress',
      'deviceInfo',
    ];

    it.each(optionalEvidenceFields)('%s is still present on the model', (name) => {
      expect(() => field(name)).not.toThrow();
    });
  });
});
