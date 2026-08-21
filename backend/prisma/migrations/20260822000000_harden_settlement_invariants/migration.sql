-- One authoritative settlement per booking. Financial snapshot columns stay
-- append-only; only this lifecycle flag changes when a correction is added.
ALTER TABLE "booking_settlements"
  ADD COLUMN "isCurrent" BOOLEAN NOT NULL DEFAULT TRUE;

-- Backfill an existing correction chain before creating the partial unique
-- index. If legacy data has multiple live leaves for one booking, index
-- creation intentionally fails instead of silently choosing one.
UPDATE "booking_settlements" AS old
SET "isCurrent" = FALSE
WHERE EXISTS (
  SELECT 1
  FROM "booking_settlements" AS replacement
  WHERE replacement."supersedesId" = old."id"
);

CREATE UNIQUE INDEX "booking_settlements_one_current_per_booking_key"
  ON "booking_settlements"("bookingId")
  WHERE "isCurrent" = TRUE;

ALTER TABLE "booking_settlements"
  ADD CONSTRAINT "booking_settlements_received_not_overpay_check"
  CHECK ("received" <= "expectedTotal");
