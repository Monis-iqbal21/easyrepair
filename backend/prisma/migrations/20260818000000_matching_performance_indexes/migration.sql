-- Matching-performance indexes.
--
-- Every index below is additive and justified by a specific hot query; see the
-- doc comments on the corresponding @@index in schema.prisma.
--
-- DEPLOYMENT NOTE (read before `prisma migrate deploy` on production):
--   Prisma wraps each migration in a single transaction, so CREATE INDEX
--   CONCURRENTLY (which cannot run inside a transaction block) is deliberately
--   NOT used here. A plain CREATE INDEX takes a SHARE lock on the table:
--   concurrent reads are unaffected, but INSERT/UPDATE/DELETE on that table
--   block until the build finishes.
--
--   At HandyGo's current row counts these builds are sub-second. If
--   worker_profiles / bookings / notifications have grown large enough for the
--   write pause to matter, apply these indexes OUT OF BAND instead:
--
--     1. Run each statement below manually with CONCURRENTLY added, outside any
--        transaction, e.g.
--          CREATE INDEX CONCURRENTLY IF NOT EXISTS "bookings_discovery_idx"
--            ON "bookings" ("status", "categoryId", "createdAt");
--        (If a CONCURRENTLY build fails it leaves an INVALID index — drop it
--        and retry; it is never left in a half-applied, queryable state.)
--     2. Then mark this migration applied without re-running it:
--          npx prisma migrate resolve --applied 20260818000000_matching_performance_indexes
--
--   Every statement is IF NOT EXISTS, so the two routes are interchangeable and
--   re-running is safe.

-- ── WorkerProfile ───────────────────────────────────────────────────────────
-- LIVE candidate filter: four equality predicates then one range on GPS
-- freshness. Replaces a scan of every ONLINE row.
CREATE INDEX IF NOT EXISTS "worker_profiles_live_candidate_idx"
  ON "worker_profiles" ("availabilityStatus", "currentlyWorking", "status", "onboardingStatus", "locationUpdatedAt");

-- Bounding-box geographic pre-filter for the non-PostGIS radius path.
CREATE INDEX IF NOT EXISTS "worker_profiles_bbox_idx"
  ON "worker_profiles" ("currentLat", "currentLng");

-- ── WorkerSkill ─────────────────────────────────────────────────────────────
-- Skill semi-join (categoryId = $1 AND workerProfileId = wp.id) answered from
-- the index alone; the existing unique index is workerProfileId-first.
CREATE INDEX IF NOT EXISTS "worker_skills_category_worker_idx"
  ON "worker_skills" ("categoryId", "workerProfileId");

-- ── Booking ─────────────────────────────────────────────────────────────────
-- New Jobs discovery: status + category equality, createdAt as both the 48h
-- range bound and the ORDER BY key.
CREATE INDEX IF NOT EXISTS "bookings_discovery_idx"
  ON "bookings" ("status", "categoryId", "createdAt");

-- Worker stats/earnings aggregation (completed + cancellation counts).
CREATE INDEX IF NOT EXISTS "bookings_worker_status_idx"
  ON "bookings" ("workerProfileId", "status");

-- ── Notification ────────────────────────────────────────────────────────────
-- Broadcast dedup lookup, now batched per (booking, eventKey) per fan-out.
CREATE INDEX IF NOT EXISTS "notifications_booking_event_idx"
  ON "notifications" ("bookingId", "eventKey", "createdAt");

-- Notification history feed: WHERE userId ORDER BY createdAt DESC LIMIT 50.
CREATE INDEX IF NOT EXISTS "notifications_user_created_idx"
  ON "notifications" ("userId", "createdAt");
