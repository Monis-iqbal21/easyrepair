-- Generalise a category's lane restriction: inspectionOnly -> soleLane.
--
-- WHY
--   `inspectionOnly BOOLEAN` could only ever say "INSPECTION and nothing
--   else". Appliances Repair is now BIDDING-only — an appliance fault cannot
--   be quoted from a fixed-price catalog, and the platform no longer sells a
--   paid inspection visit for it — which that boolean cannot express. Adding
--   a second `biddingOnly` boolean beside it would allow the impossible state
--   where both are true, so the existing flag is generalised instead: one
--   nullable enum naming the single lane a restricted category offers.
--
--   NULL keeps the pre-existing rule for every unrestricted category —
--   BIDDING always, INSPECTION when inspectionFee is set, STANDARD from the
--   fixed-price catalog — so nothing but Appliances Repair changes.
--
-- SAFETY
--   * The column is added NULLable with no default, so existing rows are
--     untouched until the backfill below names them explicitly.
--   * The backfill is written from the old column, so any category some other
--     environment had flagged inspection-only keeps exactly that rule.
--   * Appliances Repair is then moved to BIDDING. It is the only row this
--     migration re-points, and it is matched by its unique name.
--   * Existing bookings are NOT touched: `soleLane` gates lane SELECTION at
--     create/edit time only. Every historical Appliances Repair inspection
--     keeps its lane, its fee snapshot and its report.
--   * `inspectionOnly` is dropped last, after its every reader has moved to
--     `soleLane` in the same release.
--   * Reversible with:
--       ALTER TABLE "service_categories"
--         ADD COLUMN "inspectionOnly" BOOLEAN NOT NULL DEFAULT false;
--       UPDATE "service_categories" SET "inspectionOnly" = true
--         WHERE "soleLane" = 'INSPECTION';
--       ALTER TABLE "service_categories" DROP COLUMN "soleLane";

ALTER TABLE "service_categories"
  ADD COLUMN IF NOT EXISTS "soleLane" "BookingLane";

-- Carry the old rule across verbatim.
UPDATE "service_categories"
  SET "soleLane" = 'INSPECTION'
  WHERE "inspectionOnly" = true;

-- The one product change: Appliances Repair becomes BIDDING-only. Guarded by
-- name because categories are seed data with a unique name, not fixed ids.
UPDATE "service_categories"
  SET "soleLane" = 'BIDDING'
  WHERE "name" = 'Appliances Repair';

ALTER TABLE "service_categories"
  DROP COLUMN IF EXISTS "inspectionOnly";
