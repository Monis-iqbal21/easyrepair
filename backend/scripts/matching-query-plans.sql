-- ============================================================================
-- HandyGo — representative matching query plans (READ-ONLY)
-- ============================================================================
--
-- Every statement here is EXPLAIN-only: nothing is inserted, updated, deleted
-- or locked. It is safe to run against a development or staging database.
--
--   psql "$DATABASE_URL" -f backend/scripts/matching-query-plans.sql
--
-- EXPLAIN (no ANALYZE) is used throughout so it can be run anywhere without
-- executing the query. On a database with a REPRESENTATIVE dataset, swap in
-- `EXPLAIN (ANALYZE, BUFFERS)` to get real timings — do NOT do this on
-- production, and do not quote timings taken from an empty/seed database:
-- with a few dozen rows Postgres correctly prefers a sequential scan and the
-- plan tells you nothing about behaviour at scale.
--
-- Replace the :placeholders below with real ids/coordinates before running.
-- Defaults are Karachi city centre and a 7 km match radius.
--
-- ── What to look for ────────────────────────────────────────────────────────
--
--   Query 1 (live candidates)   → Index Scan / Bitmap Index Scan using
--                                 worker_profiles_live_candidate_idx, with the
--                                 bounding box applied as an index or heap
--                                 filter. NOT "Seq Scan on worker_profiles".
--   Query 2 (New Jobs feed)     → Index Scan using bookings_discovery_idx.
--                                 The 48h window must appear as an index
--                                 CONDITION on createdAt, not a Filter, and
--                                 there should be no separate Sort node.
--   Query 3 (skill semi-join)   → Index Only Scan using
--                                 worker_skills_category_worker_idx.
--   Query 4 (broadcast dedup)   → Index Scan using
--                                 notifications_booking_event_idx.
--   Query 5 (notification feed) → Index Scan Backward using
--                                 notifications_user_created_idx, no Sort.
--   Query 6 (worker stats)      → Index Only Scan using
--                                 bookings_worker_status_idx (GroupAggregate
--                                 or HashAggregate above it).
--   Query 7 (PostGIS radius)    → Index Scan using
--                                 worker_profiles_location_gist_idx.
--                                 Only meaningful once migration
--                                 20260818000100_worker_location_geography has
--                                 been applied; before that the column does
--                                 not exist and the app uses query 1 instead.
--
-- A "Seq Scan on worker_profiles" or "Seq Scan on bookings" in queries 1, 2 or
-- 7 on a large table means the corresponding index is missing or was not
-- applied — check that migration 20260818000000_matching_performance_indexes
-- ran, and that ANALYZE has been run since.
-- ============================================================================

\set job_lat 24.8607
\set job_lng 67.0011
\set category_id '''00000000-0000-0000-0000-000000000000'''
\set booking_id '''00000000-0000-0000-0000-000000000000'''
\set user_id    '''00000000-0000-0000-0000-000000000000'''
-- Bounding box for a 7 km radius around the job (what the application sends).
\set min_lat 24.7978
\set max_lat 24.9236
\set min_lng 66.9317
\set max_lng 67.0705


-- ── 1. LIVE candidate workers (broadcast fan-out, non-PostGIS path) ─────────
--     MatchingRepository.findCandidateWorkers
EXPLAIN
SELECT wp.id, wp."userId", wp."currentLat", wp."currentLng"
FROM worker_profiles wp
WHERE wp."availabilityStatus" = 'ONLINE'
  AND wp."currentlyWorking" = FALSE
  AND wp.status = 'ACTIVE'
  AND wp."onboardingStatus" = 'APPROVED'
  AND wp."profileCompleted" = TRUE
  AND wp."locationUpdatedAt" >= NOW() - INTERVAL '30 minutes'
  AND wp."lastSeenAt" >= NOW() - INTERVAL '6 hours'
  AND wp."currentLat" BETWEEN :min_lat AND :max_lat
  AND wp."currentLng" BETWEEN :min_lng AND :max_lng
  AND EXISTS (
    SELECT 1 FROM worker_skills ws
    WHERE ws."workerProfileId" = wp.id
      AND ws."categoryId" = :category_id
  );


-- ── 2. New Jobs discovery feed (marketplace browsing — no ONLINE filter) ────
--     BidsRepository.findAvailableJobsForWorker
EXPLAIN
SELECT b.id
FROM bookings b
WHERE b.status = 'PENDING'
  AND b."workerProfileId" IS NULL
  AND b."categoryId" = :category_id
  AND b."createdAt" >= NOW() - INTERVAL '48 hours'
  AND b.latitude BETWEEN :min_lat AND :max_lat
  AND b.longitude BETWEEN :min_lng AND :max_lng
  AND NOT EXISTS (
    SELECT 1 FROM booking_worker_exclusions e
    WHERE e."bookingId" = b.id
      AND e."workerProfileId" = :category_id  -- substitute a real workerProfileId
  )
ORDER BY b."createdAt" DESC;


-- ── 3. Skill semi-join in isolation ────────────────────────────────────────
EXPLAIN
SELECT ws."workerProfileId"
FROM worker_skills ws
WHERE ws."categoryId" = :category_id;


-- ── 4. Broadcast dedup, batched per chunk ──────────────────────────────────
--     NotificationsRepository.findNotifiedUserIds
EXPLAIN
SELECT DISTINCT n."userId"
FROM notifications n
WHERE n."bookingId" = :booking_id
  AND n."eventKey" = 'booking.bidding.available'
  AND n."createdAt" >= NOW() - INTERVAL '1 day'
  AND n."userId" = ANY (ARRAY[:user_id]::text[]);


-- ── 5. Notification history feed ───────────────────────────────────────────
EXPLAIN
SELECT n.*
FROM notifications n
WHERE n."userId" = :user_id
ORDER BY n."createdAt" DESC
LIMIT 50;


-- ── 6. Batched worker stats (completed / cancellation aggregation) ─────────
EXPLAIN
SELECT b."workerProfileId", COUNT(*)
FROM bookings b
WHERE b."workerProfileId" = ANY (ARRAY[:category_id]::text[])  -- real worker ids
  AND b.status = 'COMPLETED'
GROUP BY b."workerProfileId";


-- ── 7. PostGIS radius search (only after the geography migration) ──────────
--     BookingsRepository._queryNearbyWorkersPostgis
--     Skip this block if worker_profiles.location does not exist yet.
EXPLAIN
SELECT wp.id,
       ST_Distance(
         wp.location,
         ST_SetSRID(ST_MakePoint(:job_lng, :job_lat), 4326)::geography
       ) AS distance_meters
FROM worker_profiles wp
WHERE wp."availabilityStatus" = 'ONLINE'
  AND wp."currentlyWorking" = FALSE
  AND wp.status = 'ACTIVE'
  AND wp."onboardingStatus" = 'APPROVED'
  AND wp."profileCompleted" = TRUE
  AND wp."locationUpdatedAt" > NOW() - INTERVAL '30 minutes'
  AND wp."lastSeenAt" > NOW() - INTERVAL '6 hours'
  AND ST_DWithin(
        wp.location,
        ST_SetSRID(ST_MakePoint(:job_lng, :job_lat), 4326)::geography,
        20000
      )
ORDER BY distance_meters ASC
LIMIT 200;


-- ── Environment checks ─────────────────────────────────────────────────────
-- Is PostGIS available on this database?
SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') AS postgis_enabled;

-- Did the geography migration land?
SELECT EXISTS (
  SELECT 1 FROM information_schema.columns
  WHERE table_name = 'worker_profiles' AND column_name = 'location'
) AS worker_location_column_present;

-- Which matching indexes are actually present?
SELECT indexname
FROM pg_indexes
WHERE indexname IN (
  'worker_profiles_live_candidate_idx',
  'worker_profiles_bbox_idx',
  'worker_profiles_location_gist_idx',
  'worker_skills_category_worker_idx',
  'bookings_discovery_idx',
  'bookings_worker_status_idx',
  'notifications_booking_event_idx',
  'notifications_user_created_idx'
)
ORDER BY indexname;
