-- Adds the minimal, additive storage needed for the Admin OTP Diagnostics
-- / Reveal feature:
--   1. "auth_otps" gains an SMS-dispatch diagnostic flag plus an
--      AES-256-GCM encrypted copy of the code (ciphertext/iv/tag), stored
--      alongside the existing bcrypt "otpHash". Normal OTP verification is
--      untouched — it still reads only "otpHash".
--   2. A new, narrow "otp_reveal_audit_logs" table records every admin OTP
--      reveal (who, which OTP record, target phone, purpose, when) — never
--      the revealed plaintext code itself.
--
-- Additive only: one new nullable/defaulted column set on an existing table,
-- and one new table. No existing column is altered or dropped, no data loss.
--
-- NOT applied to the live database by this change — apply with
-- `prisma migrate deploy` when ready, after OTP_ADMIN_ENCRYPTION_KEY is
-- configured in the target environment.

-- AlterTable
ALTER TABLE "auth_otps" ADD COLUMN IF NOT EXISTS "smsDispatched" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "auth_otps" ADD COLUMN IF NOT EXISTS "otpCiphertext" TEXT;
ALTER TABLE "auth_otps" ADD COLUMN IF NOT EXISTS "otpCipherIv" TEXT;
ALTER TABLE "auth_otps" ADD COLUMN IF NOT EXISTS "otpCipherTag" TEXT;

-- CreateTable
CREATE TABLE IF NOT EXISTS "otp_reveal_audit_logs" (
    "id" TEXT NOT NULL,
    "adminUserId" TEXT NOT NULL,
    "authOtpId" TEXT NOT NULL,
    "targetPhone" TEXT NOT NULL,
    "purpose" "AuthOtpPurpose" NOT NULL,
    "ipAddress" TEXT,
    "userAgent" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "otp_reveal_audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "otp_reveal_audit_logs_adminUserId_idx" ON "otp_reveal_audit_logs"("adminUserId");

-- CreateIndex
CREATE INDEX IF NOT EXISTS "otp_reveal_audit_logs_authOtpId_idx" ON "otp_reveal_audit_logs"("authOtpId");

-- CreateIndex
CREATE INDEX IF NOT EXISTS "otp_reveal_audit_logs_createdAt_idx" ON "otp_reveal_audit_logs"("createdAt");
