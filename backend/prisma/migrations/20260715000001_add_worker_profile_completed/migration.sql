-- AlterTable: add profileCompleted boolean gate to worker_profiles
-- Additive only — no drops, no renames. Existing rows default to false.
ALTER TABLE "worker_profiles" ADD COLUMN "profileCompleted" BOOLEAN NOT NULL DEFAULT false;
