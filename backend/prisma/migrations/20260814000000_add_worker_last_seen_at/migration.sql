-- Adds WorkerProfile.lastSeenAt — a server-observed "app is genuinely
-- active" presence timestamp, distinct from onlineAt (set once per Go-Online
-- session) and locationUpdatedAt (GPS freshness for nearby-radius matching).
-- Refreshed only by legitimate Worker activity (touchWorkerPresence), and
-- read by both the matching-time eligibility gate and the scheduled
-- stale-ONLINE cleanup job to expire an abandoned/logged-out-elsewhere
-- ONLINE lease after WORKER_ONLINE_STALE_HOURS (default 6h).
--
-- Deployment safety: the eligibility gate treats a NULL lastSeenAt as stale.
-- Backfilling every row to NULL would therefore make every CURRENTLY ONLINE
-- worker vanish from matching the instant this migration is applied, until
-- each one next refreshes location or goes online again. To avoid that, ONLINE
-- rows are backfilled from the safest existing recent signal (locationUpdatedAt,
-- falling back to onlineAt, falling back to NOW() if neither is set) in the
-- same migration. OFFLINE/BUSY rows are left NULL — they are not eligible for
-- matching regardless, so there is nothing to preserve for them.
--
-- NOT applied to the live database by this change — apply with
-- `prisma migrate deploy` when ready.

ALTER TABLE "worker_profiles" ADD COLUMN "lastSeenAt" TIMESTAMPTZ(3);

UPDATE "worker_profiles"
SET "lastSeenAt" = COALESCE("locationUpdatedAt", "onlineAt", NOW())
WHERE "availabilityStatus" = 'ONLINE';

CREATE INDEX "worker_profiles_availabilityStatus_lastSeenAt_idx"
  ON "worker_profiles" ("availabilityStatus", "lastSeenAt");
