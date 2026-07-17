-- AlterTable
-- Loosen issueFound/recommendedRepair to nullable: a report may now be submitted
-- with a voice note only, so written findings are no longer mandatory at the DB level
-- (business rule "text OR voice note required" is enforced in InspectionReportsService).
-- This is a safe, non-destructive relaxation of a NOT NULL constraint — existing rows
-- are untouched, no data is lost, nothing is dropped or renamed.
ALTER TABLE "inspection_reports"
  ALTER COLUMN "issueFound" DROP NOT NULL,
  ALTER COLUMN "recommendedRepair" DROP NOT NULL,
  ADD COLUMN "voiceNoteUrl" TEXT,
  ADD COLUMN "voiceNoteStorageKey" TEXT,
  ADD COLUMN "voiceNoteMimeType" TEXT,
  ADD COLUMN "voiceNoteDurationSeconds" DOUBLE PRECISION;
