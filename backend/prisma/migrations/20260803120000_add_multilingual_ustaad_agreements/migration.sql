-- Multilingual Ustaad agreement acceptance.
--
-- Adds the language / trade / lifecycle dimension to agreement sources, and
-- the evidence fields an immutable acceptance record needs (accepted locale,
-- source + accepted hashes, personalized snapshot, viewed-at, idempotency).
--
-- Backward compatible by construction: every new column is nullable or has a
-- default, and existing rows are the Roman Urdu source, so they default to
-- UR_LATN / ACTIVE and keep working untouched.

-- ── Enums ───────────────────────────────────────────────────────────────────

-- Third Ustaad document + the Customer document (registered only; it must
-- never enter the Ustaad flow).
ALTER TYPE "AgreementType" ADD VALUE IF NOT EXISTS 'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE';
ALTER TYPE "AgreementType" ADD VALUE IF NOT EXISTS 'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE';

DO $$ BEGIN
  CREATE TYPE "AgreementLocale" AS ENUM ('EN', 'UR', 'UR_LATN');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE "AgreementSourceStatus" AS ENUM ('ACTIVE', 'PENDING_TRANSLATION', 'DRAFT', 'RETIRED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE "AgreementTradeCode" AS ENUM ('ELECTRICIAN', 'PLUMBER', 'AC_TECHNICIAN', 'CARPENTER');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE "AgreementAcceptanceMethod" AS ENUM ('ELECTRONIC_IN_APP');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── agreement_templates ─────────────────────────────────────────────────────

ALTER TABLE "agreement_templates"
  ADD COLUMN IF NOT EXISTS "locale" "AgreementLocale" NOT NULL DEFAULT 'UR_LATN',
  ADD COLUMN IF NOT EXISTS "tradeCode" "AgreementTradeCode",
  ADD COLUMN IF NOT EXISTS "status" "AgreementSourceStatus" NOT NULL DEFAULT 'ACTIVE',
  ADD COLUMN IF NOT EXISTS "clauseStructureVersion" TEXT NOT NULL DEFAULT '1.0',
  ADD COLUMN IF NOT EXISTS "originalFilename" TEXT,
  ADD COLUMN IF NOT EXISTS "activatedAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "retiredAt" TIMESTAMP(3);

-- One row per (type, trade, locale, version): a language variant is its own
-- row with its own hash, never a column on a shared row.
CREATE UNIQUE INDEX IF NOT EXISTS "agreement_templates_type_tradeCode_locale_version_key"
  ON "agreement_templates" ("type", "tradeCode", "locale", "version");

CREATE INDEX IF NOT EXISTS "agreement_templates_type_tradeCode_locale_status_idx"
  ON "agreement_templates" ("type", "tradeCode", "locale", "status");

-- ── agreement_acceptances ───────────────────────────────────────────────────

ALTER TABLE "agreement_acceptances"
  ADD COLUMN IF NOT EXISTS "acceptanceId" TEXT,
  ADD COLUMN IF NOT EXISTS "agreementLocale" "AgreementLocale" NOT NULL DEFAULT 'UR_LATN',
  ADD COLUMN IF NOT EXISTS "applicableTrade" "AgreementTradeCode",
  ADD COLUMN IF NOT EXISTS "sourceDocumentHash" TEXT,
  ADD COLUMN IF NOT EXISTS "acceptedDocumentHash" TEXT,
  ADD COLUMN IF NOT EXISTS "acceptedPdfHash" TEXT,
  ADD COLUMN IF NOT EXISTS "acceptedDocumentSnapshot" TEXT,
  ADD COLUMN IF NOT EXISTS "documentViewedAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "acceptanceMethod" "AgreementAcceptanceMethod" NOT NULL DEFAULT 'ELECTRONIC_IN_APP',
  ADD COLUMN IF NOT EXISTS "effectiveAt" TIMESTAMPTZ(3),
  ADD COLUMN IF NOT EXISTS "pdfMadeAvailableAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "fatherNameSnapshot" TEXT,
  ADD COLUMN IF NOT EXISTS "dateOfBirthSnapshot" TEXT,
  ADD COLUMN IF NOT EXISTS "addressSnapshot" TEXT,
  ADD COLUMN IF NOT EXISTS "ustaadAccountIdSnapshot" TEXT,
  ADD COLUMN IF NOT EXISTS "emergencyContactSnapshot" TEXT,
  ADD COLUMN IF NOT EXISTS "approvedTradeSnapshot" TEXT,
  ADD COLUMN IF NOT EXISTS "approvedServiceTagsSnapshot" TEXT,
  ADD COLUMN IF NOT EXISTS "verificationProviderSnapshot" TEXT,
  ADD COLUMN IF NOT EXISTS "verificationRequestRefSnapshot" TEXT,
  ADD COLUMN IF NOT EXISTS "idempotencyKey" TEXT;

-- A retried or double-tapped submission must return the SAME record rather
-- than creating a second immutable legal document.
CREATE UNIQUE INDEX IF NOT EXISTS "agreement_acceptances_acceptanceId_key"
  ON "agreement_acceptances" ("acceptanceId");

CREATE UNIQUE INDEX IF NOT EXISTS "agreement_acceptances_idempotencyKey_key"
  ON "agreement_acceptances" ("idempotencyKey");

-- ── worker_profiles: identity fields the EVS Consent document requires ──────
--
-- Father's name and date of birth are mandatory blanks in the approved
-- Background Verification / EVS Consent document, and were not collected
-- anywhere before. Nullable so existing rows are unaffected; profile
-- completion collects them and generation blocks until they are present.

ALTER TABLE "worker_profiles"
  ADD COLUMN IF NOT EXISTS "fatherName" TEXT,
  ADD COLUMN IF NOT EXISTS "dateOfBirth" TEXT,
  ADD COLUMN IF NOT EXISTS "emergencyContact" TEXT;

-- Registry-backed acceptances have no AgreementTemplate row (the canonical
-- source is a committed, hash-pinned file). Legacy rows keep their FK.
ALTER TABLE "agreement_acceptances" ALTER COLUMN "agreementTemplateId" DROP NOT NULL;
