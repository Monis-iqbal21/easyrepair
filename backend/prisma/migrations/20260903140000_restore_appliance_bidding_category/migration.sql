-- Production inspection found no Appliance(s) Repair row. The applied
-- 20260903130000 migration only UPDATEd seed data, so it affected zero rows.
-- Data-only follow-up: create the missing category, or repair only an existing
-- appliance spelling/case/spacing variant. Preserve existing IDs, names, fees,
-- bookings, skills and every other category. No full seed is run.
BEGIN;

INSERT INTO "service_categories" (
  "id", "name", "description", "isActive", "availabilityStatus",
  "inspectionFee", "inspectionOnly", "soleLane", "createdAt", "updatedAt"
)
SELECT
  gen_random_uuid()::text,
  'Appliances Repair',
  'Washing machine, fridge, microwave & home appliance diagnosis and repair',
  true, 'ACTIVE', 500, false, 'BIDDING', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
WHERE NOT EXISTS (
  SELECT 1 FROM "service_categories"
  WHERE lower(btrim(regexp_replace("name", '[[:space:]]+', ' ', 'g')))
    IN ('appliance repair', 'appliances repair')
);

UPDATE "service_categories"
SET "isActive" = true,
    "availabilityStatus" = 'ACTIVE',
    "inspectionOnly" = false,
    "soleLane" = 'BIDDING',
    "updatedAt" = CURRENT_TIMESTAMP
WHERE lower(btrim(regexp_replace("name", '[[:space:]]+', ' ', 'g')))
    IN ('appliance repair', 'appliances repair')
  AND (
    "isActive" IS DISTINCT FROM true
    OR "availabilityStatus" IS DISTINCT FROM 'ACTIVE'
    OR "inspectionOnly" IS DISTINCT FROM false
    OR "soleLane" IS DISTINCT FROM 'BIDDING'
  );

COMMIT;
