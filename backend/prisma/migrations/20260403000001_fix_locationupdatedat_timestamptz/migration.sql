-- Fix: locationUpdatedAt was TIMESTAMP(3) (no timezone) which caused the
-- freshness filter (locationUpdatedAt > NOW() - INTERVAL '30 minutes') to
-- produce false negatives on Railway because PostgreSQL casts NOW() to the
-- session timezone before comparing against the bare UTC value.
--
-- Changing to TIMESTAMPTZ makes both sides of the comparison timezone-aware,
-- so the result is correct regardless of the server's session timezone.
--
-- USING clause interprets all existing stored values as UTC (which is how
-- Prisma/Node.js wrote them), preserving their meaning correctly.

ALTER TABLE "worker_profiles"
  ALTER COLUMN "locationUpdatedAt" TYPE TIMESTAMPTZ(3)
  USING "locationUpdatedAt" AT TIME ZONE 'UTC';
