-- Adds a short grace-window rotation mechanism to refresh tokens.
--
-- Previously, refreshing a token deleted the old row immediately and
-- created a brand-new one. If the app crashed or was killed after the
-- backend committed that rotation but before Flutter finished persisting
-- the new pair to secure storage, the device was left holding a refresh
-- token the backend had already deleted — the next refresh attempt would
-- be a hard, unrecoverable "Invalid or expired refresh token" rejection,
-- logging the user out even though nothing about their session was
-- actually wrong.
--
-- Both new columns are nullable and default to NULL for every existing
-- row, so this is fully backward compatible: a token that has never been
-- rotated (the common case) is unaffected.

ALTER TABLE "refresh_tokens" ADD COLUMN IF NOT EXISTS "replacedByToken" TEXT;
ALTER TABLE "refresh_tokens" ADD COLUMN IF NOT EXISTS "supersededAt" TIMESTAMP(3);
