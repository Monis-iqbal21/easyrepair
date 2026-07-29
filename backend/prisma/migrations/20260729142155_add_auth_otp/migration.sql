-- CreateEnum
CREATE TYPE "AuthOtpPurpose" AS ENUM ('CLIENT_LOGIN_REGISTER', 'WORKER_REGISTER', 'WORKER_LOGIN');

-- CreateTable
CREATE TABLE "auth_otps" (
    "id" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "purpose" "AuthOtpPurpose" NOT NULL,
    "otpHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "consumedAt" TIMESTAMP(3),
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "requestIp" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "auth_otps_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "auth_otps_phone_purpose_idx" ON "auth_otps"("phone", "purpose");

-- CreateIndex
CREATE INDEX "auth_otps_expiresAt_idx" ON "auth_otps"("expiresAt");

-- CreateIndex
CREATE INDEX "auth_otps_consumedAt_idx" ON "auth_otps"("consumedAt");

-- CreateIndex
CREATE INDEX "auth_otps_requestIp_createdAt_idx" ON "auth_otps"("requestIp", "createdAt");
