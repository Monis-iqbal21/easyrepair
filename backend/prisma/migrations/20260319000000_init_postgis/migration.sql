-- PostGIS disabled temporarily for Railway standard PostgreSQL
-- CREATE EXTENSION IF NOT EXISTS postgis;

-- ALTER TABLE "worker_profiles"
--   ADD COLUMN IF NOT EXISTS "location" geography(Point, 4326);

-- CREATE INDEX IF NOT EXISTS "worker_profiles_location_idx"
--   ON "worker_profiles" USING GIST ("location");