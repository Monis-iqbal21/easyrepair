-- Add ServiceCategory.soleLane alongside the existing inspectionOnly flag.
--
-- WHY
--   `inspectionOnly BOOLEAN` can only ever say "INSPECTION and nothing else".
--   Appliances Repair is BIDDING-only — an appliance fault cannot be quoted
--   from a fixed-price catalog, and the platform no longer sells a paid
--   inspection visit for it — which that boolean cannot express.
--
--   `soleLane` names the single lane a restricted category offers. It does not
--   replace `inspectionOnly`; it takes precedence over it:
--
--     1. soleLane IS NOT NULL   -> that lane, and nothing else.
--     2. else inspectionOnly    -> INSPECTION only (legacy behaviour, verbatim).
--     3. else                   -> unrestricted, exactly as before.
--
-- SAFETY
--   * Purely ADDITIVE. Nothing is dropped and nothing is renamed.
--   * `inspectionOnly` is retained in the table AND in the /categories
--     response, so an older APK that only knows that field keeps working and
--     keeps rendering exactly what it renders today.
--   * `soleLane` is NULLable with no default, so every existing row stays on
--     rule 2 or rule 3 and no category's lanes change implicitly.
--   * No backfill from `inspectionOnly`. Rule 2 already preserves those
--     categories, so copying the value across would only create a second place
--     the same fact is written.
--   * Existing bookings are NOT touched: the rule gates lane SELECTION at
--     create and edit time only. Every historical Appliances Repair inspection
--     keeps its lane, its fee snapshot and its report.
--   * The stored inspectionFee is left alone. soleLane, not the fee, decides
--     the lanes; the fee is simply inert on a bidding-only category.
--   * Every statement is idempotent, so re-running is a no-op.
--   * Reversible with:
--       UPDATE "service_categories" SET "soleLane" = NULL;
--       ALTER TABLE "service_categories" DROP COLUMN "soleLane";

ALTER TABLE "service_categories"
  ADD COLUMN IF NOT EXISTS "soleLane" "BookingLane";

-- Defensive: an earlier local-only revision of this change dropped
-- "inspectionOnly". That revision was never pushed, but a development database
-- may have run it, and this release requires the column to exist. Restoring it
-- here is a no-op everywhere it was never dropped.
ALTER TABLE "service_categories"
  ADD COLUMN IF NOT EXISTS "inspectionOnly" BOOLEAN NOT NULL DEFAULT false;

-- The one product change: Appliances Repair becomes BIDDING-only. Matched by
-- name because categories are seed data with a unique name, not fixed ids.
-- inspectionOnly is set false explicitly so the two fields cannot disagree —
-- soleLane would win regardless, but a row saying "inspection only" while
-- behaving as bidding-only is a trap for the next reader.
UPDATE "service_categories"
  SET "soleLane" = 'BIDDING',
      "inspectionOnly" = false
  WHERE "name" = 'Appliances Repair';
