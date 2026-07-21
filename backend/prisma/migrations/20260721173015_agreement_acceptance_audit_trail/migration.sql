-- CreateEnum
CREATE TYPE "AgreementType" AS ENUM ('GENERAL_USTAAD', 'TRADE_SPECIFIC');

-- AlterTable
ALTER TABLE "worker_profiles" ADD COLUMN     "cnicNumber" TEXT;

-- CreateTable
CREATE TABLE "agreement_templates" (
    "id" TEXT NOT NULL,
    "type" "AgreementType" NOT NULL,
    "categoryId" TEXT,
    "title" TEXT NOT NULL,
    "version" TEXT NOT NULL,
    "contentText" TEXT NOT NULL,
    "fileUrl" TEXT,
    "fileStorageKey" TEXT,
    "contentHash" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "agreement_templates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "agreement_acceptances" (
    "id" TEXT NOT NULL,
    "workerProfileId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "agreementTemplateId" TEXT NOT NULL,
    "agreementType" "AgreementType" NOT NULL,
    "agreementTitle" TEXT NOT NULL,
    "agreementVersion" TEXT NOT NULL,
    "agreementContentSnapshot" TEXT NOT NULL,
    "agreementFileSnapshotUrl" TEXT,
    "agreementFileSnapshotStorageKey" TEXT,
    "agreementHash" TEXT NOT NULL,
    "fullLegalNameSnapshot" TEXT NOT NULL,
    "cnicNumberSnapshot" TEXT NOT NULL,
    "mobileSnapshot" TEXT NOT NULL,
    "mainSkillSnapshot" TEXT NOT NULL,
    "cnicFrontUrlSnapshot" TEXT,
    "cnicBackUrlSnapshot" TEXT,
    "liveSelfieUrlSnapshot" TEXT,
    "acceptedAt" TIMESTAMPTZ(3) NOT NULL,
    "ipAddress" TEXT,
    "deviceInfo" TEXT,
    "checkboxAccepted" BOOLEAN NOT NULL DEFAULT true,
    "acceptancePdfUrl" TEXT,
    "acceptancePdfStorageKey" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "agreement_acceptances_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "agreement_templates_type_categoryId_isActive_idx" ON "agreement_templates"("type", "categoryId", "isActive");

-- CreateIndex
CREATE INDEX "agreement_acceptances_workerProfileId_idx" ON "agreement_acceptances"("workerProfileId");

-- CreateIndex
CREATE INDEX "agreement_acceptances_userId_idx" ON "agreement_acceptances"("userId");

-- CreateIndex
CREATE INDEX "agreement_acceptances_agreementTemplateId_idx" ON "agreement_acceptances"("agreementTemplateId");

-- CreateIndex
CREATE UNIQUE INDEX "agreement_acceptances_workerProfileId_agreementTemplateId_key" ON "agreement_acceptances"("workerProfileId", "agreementTemplateId");

-- CreateIndex
CREATE UNIQUE INDEX "worker_profiles_cnicNumber_key" ON "worker_profiles"("cnicNumber");

-- AddForeignKey
ALTER TABLE "agreement_templates" ADD CONSTRAINT "agreement_templates_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "service_categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "agreement_acceptances" ADD CONSTRAINT "agreement_acceptances_workerProfileId_fkey" FOREIGN KEY ("workerProfileId") REFERENCES "worker_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "agreement_acceptances" ADD CONSTRAINT "agreement_acceptances_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "agreement_acceptances" ADD CONSTRAINT "agreement_acceptances_agreementTemplateId_fkey" FOREIGN KEY ("agreementTemplateId") REFERENCES "agreement_templates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

