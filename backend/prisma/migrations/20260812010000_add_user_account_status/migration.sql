-- Adds a User-level account access restriction, distinct from WorkerStatus
-- (Worker-only job-eligibility gate, untouched by this migration) and from
-- deletedAt/isActive (account deletion). Only ACTIVE/SUSPENDED — no
-- BLOCKED/BANNED variants. Additive only: a new enum plus one NOT NULL
-- defaulted column on "users" — every existing row backfills to
-- accountStatus = 'ACTIVE' with no data loss.
--
-- NOT applied to the live database by this change — apply with
-- `prisma migrate deploy` when ready.

DO $$ BEGIN
  CREATE TYPE "AccountStatus" AS ENUM ('ACTIVE', 'SUSPENDED');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "accountStatus" "AccountStatus" NOT NULL DEFAULT 'ACTIVE';
