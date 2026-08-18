-- PostGIS worker location: an indexable geography mirror of currentLat/currentLng.
--
-- WHY
--   The pre-existing PostGIS radius query built its geography inline:
--     ST_DWithin(ST_SetSRID(ST_MakePoint(wp."currentLng", wp."currentLat"),4326)::geography, ...)
--   That is a computed expression over every row, so no index could ever serve
--   it — each radius rung was a sequential scan of worker_profiles. This
--   migration materialises the same value into a real column and indexes it
--   with GIST, which is what makes ST_DWithin scalable.
--
-- SAFETY / COMPATIBILITY
--   * Purely additive. No column is dropped, renamed or retyped.
--   * currentLat / currentLng remain the authoritative fields and are
--     completely untouched — every existing write path, API contract and the
--     Haversine fallback keep working exactly as before.
--   * The column is GENERATED ALWAYS AS ... STORED, so PostgreSQL maintains it
--     from currentLat/currentLng automatically. There is no application write
--     path to add and nothing that can drift; existing rows are backfilled by
--     the ALTER itself. NULL lat/lng yields NULL location, which ST_DWithin
--     correctly treats as "no match" — the same as today's IS NOT NULL guards.
--   * Fully reversible: `ALTER TABLE "worker_profiles" DROP COLUMN "location";`
--     (dropping the column drops its index) restores the previous state
--     exactly.
--   * Guarded by a PostGIS availability check. If the extension is not
--     installed the migration succeeds as a no-op and the application keeps
--     using the Haversine + bounding-box path (USE_POSTGIS=false), so this can
--     never block a deploy.
--
-- DEPLOYMENT NOTE
--   ADD COLUMN ... GENERATED ALWAYS AS ... STORED rewrites the table and holds
--   an ACCESS EXCLUSIVE lock for the duration. On a large worker_profiles table
--   schedule it in a maintenance window, or apply it out of band and then run
--     npx prisma migrate resolve --applied 20260818000100_worker_location_geography
--   The application does NOT depend on this migration: USE_POSTGIS must be
--   flipped to true separately, and only after this has been applied.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') THEN

    ALTER TABLE "worker_profiles"
      ADD COLUMN IF NOT EXISTS "location" geography(Point, 4326)
      GENERATED ALWAYS AS (
        CASE
          WHEN "currentLat" IS NULL OR "currentLng" IS NULL THEN NULL
          ELSE ST_SetSRID(ST_MakePoint("currentLng", "currentLat"), 4326)::geography
        END
      ) STORED;

    CREATE INDEX IF NOT EXISTS "worker_profiles_location_gist_idx"
      ON "worker_profiles" USING GIST ("location");

  ELSE
    RAISE NOTICE 'PostGIS extension not installed - skipping worker_profiles.location. The Haversine + bounding-box matching path (USE_POSTGIS=false) is unaffected.';
  END IF;
END
$$;
