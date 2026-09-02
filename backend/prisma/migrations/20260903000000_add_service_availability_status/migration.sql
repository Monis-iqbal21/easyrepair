-- Additive lifecycle for Worker registration. `isActive` is deliberately
-- retained for legacy Client-list compatibility.
CREATE TYPE "ServiceAvailabilityStatus" AS ENUM ('ACTIVE', 'INACTIVE', 'SOON');

ALTER TABLE "service_categories"
ADD COLUMN "availabilityStatus" "ServiceAvailabilityStatus" NOT NULL DEFAULT 'ACTIVE';

-- Initial mapping is grounded in the existing Flutter product configuration:
-- kLaunchActiveServiceCategories is the explicit launch-active set, and its
-- documented complement is rendered as Coming Soon. Existing false values
-- remain inactive; no category name is inferred from its wording.
UPDATE "service_categories"
SET "availabilityStatus" = CASE
  WHEN "isActive" = false THEN 'INACTIVE'::"ServiceAvailabilityStatus"
  WHEN "name" IN (
    'AC Technician',
    'Electrician',
    'Plumber',
    'Carpenter',
    'Appliances Repair'
  ) THEN 'ACTIVE'::"ServiceAvailabilityStatus"
  ELSE 'SOON'::"ServiceAvailabilityStatus"
END;

CREATE INDEX "service_categories_availabilityStatus_idx"
ON "service_categories"("availabilityStatus");
