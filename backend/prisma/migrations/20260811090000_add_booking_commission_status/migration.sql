-- Adds per-booking HandyGo commission settlement tracking (18% commission,
-- unchanged) so admin can later mark each completed job's commission as
-- PAID independently of every other job. Additive only: a new enum plus two
-- nullable/defaulted columns on "bookings" — every existing row backfills to
-- commissionStatus = 'PENDING' with no data loss.
--
-- Deliberately separate from, and does not touch, the still-pending
-- 20260810120000_add_refresh_token_rotation_grace migration (unrelated auth
-- work). NOT applied to the live database by this change — apply both with
-- `prisma migrate deploy` when ready.

DO $$ BEGIN
  CREATE TYPE "CommissionStatus" AS ENUM ('PENDING', 'PAID');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS "commissionStatus" "CommissionStatus" NOT NULL DEFAULT 'PENDING';
ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS "commissionStatusUpdatedAt" TIMESTAMP(3);
