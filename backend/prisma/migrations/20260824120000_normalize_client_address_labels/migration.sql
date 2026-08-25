-- Extend the existing client_addresses table rather than introducing a
-- second saved-address store. The API owns normalization; this backfill only
-- brings any legacy rows under the same invariant.
ALTER TABLE "client_addresses" ADD COLUMN "normalizedLabel" TEXT;

UPDATE "client_addresses"
SET "normalizedLabel" = lower(
  btrim(regexp_replace("label", '\s+', ' ', 'g'))
);

-- Never delete or merge legacy user data silently. If an environment somehow
-- contains same-client duplicate labels, deployment stops with a precise
-- message so the owner can resolve those records before retrying.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM "client_addresses"
    GROUP BY "clientProfileId", "normalizedLabel"
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'Duplicate normalized client address labels must be resolved before applying this migration';
  END IF;
END $$;

ALTER TABLE "client_addresses"
ALTER COLUMN "normalizedLabel" SET NOT NULL;

CREATE UNIQUE INDEX "client_addresses_clientProfileId_normalizedLabel_key"
ON "client_addresses"("clientProfileId", "normalizedLabel");
