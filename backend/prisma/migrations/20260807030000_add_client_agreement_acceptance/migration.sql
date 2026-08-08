-- Extends agreement_acceptances to also support CLIENT (Customer) agreement
-- acceptances, alongside the existing WORKER (Ustaad) flow.
--
-- Backward compatible by construction: workerProfileId becomes nullable
-- (every existing row already has it set, so no data changes), the two new
-- CNIC/skill columns become nullable (existing Worker rows keep their
-- values), and every new column is nullable or has a default.
--
-- Legal-preservation note: clientProfileId and userId are both ON DELETE
-- SET NULL, never CASCADE. An acceptance row is permanent legal evidence —
-- deleting/deactivating a Client profile or User account must unlink it,
-- never delete it. Every identifying fact needed for an audit (name,
-- mobile, account id, agreement title/version, source/accepted/PDF hashes,
-- acceptance id, timestamps, IP/device reference) is already frozen on this
-- row's own snapshot columns, independent of the FK relations.

-- ── agreement_acceptances: allow either a Worker or a Client owner ─────────

ALTER TABLE "agreement_acceptances" ALTER COLUMN "workerProfileId" DROP NOT NULL;

ALTER TABLE "agreement_acceptances" ADD COLUMN IF NOT EXISTS "clientProfileId" TEXT;

ALTER TABLE "agreement_acceptances"
  ADD CONSTRAINT "agreement_acceptances_clientProfileId_fkey"
  FOREIGN KEY ("clientProfileId") REFERENCES "client_profiles"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

-- The acceptance row must outlive the User account too — a hard user delete
-- (if one is ever introduced) must not take the legal record with it.
ALTER TABLE "agreement_acceptances" DROP CONSTRAINT IF EXISTS "agreement_acceptances_userId_fkey";
ALTER TABLE "agreement_acceptances" ALTER COLUMN "userId" DROP NOT NULL;
ALTER TABLE "agreement_acceptances"
  ADD CONSTRAINT "agreement_acceptances_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "users"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

-- CNIC and main skill are Worker-only concepts; a Customer has neither.
ALTER TABLE "agreement_acceptances" ALTER COLUMN "cnicNumberSnapshot" DROP NOT NULL;
ALTER TABLE "agreement_acceptances" ALTER COLUMN "mainSkillSnapshot" DROP NOT NULL;

ALTER TABLE "agreement_acceptances"
  ADD COLUMN IF NOT EXISTS "clientAccountIdSnapshot" TEXT;

CREATE INDEX IF NOT EXISTS "agreement_acceptances_clientProfileId_idx"
  ON "agreement_acceptances" ("clientProfileId");

-- One immutable acceptance per Client per exact agreement version + hash —
-- the DB-level idempotency guard for the CLIENT flow. Postgres treats NULL
-- as distinct in a unique index, so every WORKER row (clientProfileId IS
-- NULL) is unaffected by this constraint.
CREATE UNIQUE INDEX IF NOT EXISTS "agreement_acceptances_clientProfileId_agreementType_agreementVersion_agreementHash_key"
  ON "agreement_acceptances" ("clientProfileId", "agreementType", "agreementVersion", "agreementHash");
