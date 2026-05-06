-- Add onlineAt to worker_profiles
-- Records when the current online session started; cleared on going offline.
-- Used by the auto-offline BullMQ job to detect stale sessions.

ALTER TABLE "worker_profiles" ADD COLUMN "onlineAt" TIMESTAMPTZ(3);
