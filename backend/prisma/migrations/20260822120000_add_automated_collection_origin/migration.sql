-- Scheduled nightly runs have no authenticated admin actor. Preserve that
-- distinction explicitly instead of attributing system work to a human.
ALTER TABLE "commission_collections"
  ALTER COLUMN "createdByUserId" DROP NOT NULL,
  ADD COLUMN "automated" BOOLEAN NOT NULL DEFAULT FALSE;
