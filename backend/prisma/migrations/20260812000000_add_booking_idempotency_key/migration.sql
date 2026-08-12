-- Adds a client-generated dedup key for one "Create Booking" submission
-- attempt. The app reuses the same UUID while retrying that same attempt
-- (e.g. after a timeout/lost response); the backend then returns the
-- already-created booking instead of creating a duplicate. Nullable and
-- additive only — every existing row backfills to NULL, and any client that
-- doesn't send the key keeps behaving exactly as before.
--
-- NOT applied to the live database by this change — apply with
-- `prisma migrate deploy` when ready.

ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS "idempotencyKey" TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS "bookings_idempotencyKey_key" ON "bookings"("idempotencyKey");
