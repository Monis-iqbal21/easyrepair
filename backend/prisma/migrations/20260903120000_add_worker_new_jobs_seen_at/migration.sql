-- Read-marker for the Ustaad "Naye Kaam" (New Jobs) badge.
--
-- Purely additive and backward-compatible: one nullable column, no default,
-- no backfill, no index. Every existing row keeps NULL, which the badge reads
-- as "this Ustaad has never opened the screen" — so the jobs already in their
-- 24h window show as unread, which is the truthful answer rather than a
-- migration artefact. Code deployed before this column is unaffected; code
-- deployed after it treats NULL as the honest default.
--
-- IF NOT EXISTS keeps the statement re-runnable, matching the house style of
-- the surrounding migrations.
ALTER TABLE "worker_profiles"
  ADD COLUMN IF NOT EXISTS "newJobsSeenAt" TIMESTAMPTZ(3);
