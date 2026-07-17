-- Data-only backfill, no schema change.
-- profileCompleted (added in 20260715000001_add_worker_profile_completed) was
-- never set true by any code path until now (see workers.repository.ts
-- replaceSkills, updated alongside this migration). Existing workers who
-- already added skills before this gate existed should not be retroactively
-- locked out of STANDARD/INSPECTION hiring or BIDDING.
-- Non-destructive: only flips false -> true for workers who already have at
-- least one worker_skills row; never touches workers without skills; never
-- sets anything back to false.
UPDATE worker_profiles
SET "profileCompleted" = true
WHERE EXISTS (
  SELECT 1 FROM worker_skills WHERE worker_skills."workerProfileId" = worker_profiles.id
);
