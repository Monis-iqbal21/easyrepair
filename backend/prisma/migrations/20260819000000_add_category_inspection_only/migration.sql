-- Inspection-only service categories.
--
-- WHY
--   Until now nothing in the data model expressed WHICH booking lanes a
--   category supports. Inspection availability was inferred from
--   `inspectionFee IS NULL` ("inspection not offered"), while STANDARD and
--   BIDDING were simply always allowed. "Appliances Repair" needs the
--   opposite statement — inspection and nothing else — so it gets an explicit
--   flag rather than another inference.
--
-- SAFETY
--   * Purely additive: one column, NOT NULL with a DEFAULT, so existing rows
--     are backfilled to FALSE in place and no table rewrite of user data
--     occurs beyond the default fill.
--   * DEFAULT FALSE means every category that exists today keeps all three
--     lanes, byte-for-byte the previous behaviour.
--   * Reversible with: ALTER TABLE "service_categories" DROP COLUMN "inspectionOnly";
--
-- The "Appliances Repair" category row itself is created by prisma/seed.ts
-- (idempotent upsert), not here — categories are seed data, not schema.

ALTER TABLE "service_categories"
  ADD COLUMN IF NOT EXISTS "inspectionOnly" BOOLEAN NOT NULL DEFAULT false;
