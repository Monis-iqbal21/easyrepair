ALTER TABLE "users"
  ADD COLUMN IF NOT EXISTS "notificationLocale" TEXT NOT NULL DEFAULT 'ur_Latn';
