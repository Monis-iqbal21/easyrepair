CREATE TYPE "SettlementCaseType" AS ENUM ('SHORT', 'UNPAID_LABOUR', 'UNPAID_FEE');
CREATE TYPE "SettlementCaseStatus" AS ENUM ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED');
CREATE TYPE "SettlementCasePriority" AS ENUM ('LOW', 'NORMAL', 'HIGH', 'URGENT');
CREATE TYPE "SettlementCaseEventType" AS ENUM ('CREATED', 'STATUS_CHANGED', 'ASSIGNED', 'NOTE_ADDED', 'CONTACT_ATTEMPTED', 'COLLECTION_CREATED', 'RESOLVED', 'REOPENED');
CREATE TYPE "ContactChannel" AS ENUM ('PHONE', 'SMS', 'WHATSAPP', 'EMAIL', 'OTHER');
CREATE TYPE "ContactOutcome" AS ENUM ('REACHED', 'NO_ANSWER', 'PROMISED_PAYMENT', 'DISPUTED', 'WRONG_NUMBER', 'OTHER');
CREATE TYPE "CommissionCollectionStatus" AS ENUM ('PENDING', 'COLLECTED', 'FAILED', 'CANCELLED');

CREATE TABLE "settlement_cases" (
  "id" TEXT NOT NULL, "bookingId" TEXT NOT NULL, "workerProfileId" TEXT NOT NULL,
  "settlementId" TEXT NOT NULL, "type" "SettlementCaseType" NOT NULL,
  "status" "SettlementCaseStatus" NOT NULL DEFAULT 'OPEN',
  "priority" "SettlementCasePriority" NOT NULL DEFAULT 'NORMAL',
  "assignedToUserId" TEXT, "resolvedAt" TIMESTAMPTZ(3),
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "settlement_cases_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "settlement_cases_settlementId_type_key" ON "settlement_cases"("settlementId", "type");
CREATE INDEX "settlement_cases_status_priority_createdAt_idx" ON "settlement_cases"("status", "priority", "createdAt");
CREATE INDEX "settlement_cases_bookingId_idx" ON "settlement_cases"("bookingId");
CREATE INDEX "settlement_cases_workerProfileId_idx" ON "settlement_cases"("workerProfileId");
CREATE INDEX "settlement_cases_assignedToUserId_idx" ON "settlement_cases"("assignedToUserId");

CREATE TABLE "settlement_case_events" (
  "id" TEXT NOT NULL, "caseId" TEXT NOT NULL, "type" "SettlementCaseEventType" NOT NULL,
  "actorUserId" TEXT NOT NULL, "metadata" JSONB,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "settlement_case_events_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "settlement_case_events_caseId_createdAt_idx" ON "settlement_case_events"("caseId", "createdAt");
CREATE INDEX "settlement_case_events_actorUserId_idx" ON "settlement_case_events"("actorUserId");

CREATE TABLE "settlement_case_notes" (
  "id" TEXT NOT NULL, "caseId" TEXT NOT NULL, "authorUserId" TEXT NOT NULL,
  "body" TEXT NOT NULL, "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "settlement_case_notes_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "settlement_case_notes_caseId_createdAt_idx" ON "settlement_case_notes"("caseId", "createdAt");
CREATE INDEX "settlement_case_notes_authorUserId_idx" ON "settlement_case_notes"("authorUserId");

CREATE TABLE "settlement_contact_attempts" (
  "id" TEXT NOT NULL, "caseId" TEXT NOT NULL, "actorUserId" TEXT NOT NULL,
  "channel" "ContactChannel" NOT NULL, "outcome" "ContactOutcome" NOT NULL,
  "note" TEXT, "followUpAt" TIMESTAMPTZ(3),
  "contactedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "settlement_contact_attempts_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "settlement_contact_attempts_caseId_contactedAt_idx" ON "settlement_contact_attempts"("caseId", "contactedAt");
CREATE INDEX "settlement_contact_attempts_actorUserId_idx" ON "settlement_contact_attempts"("actorUserId");
CREATE INDEX "settlement_contact_attempts_followUpAt_idx" ON "settlement_contact_attempts"("followUpAt");

CREATE TABLE "commission_collections" (
  "id" TEXT NOT NULL, "workerProfileId" TEXT NOT NULL, "collectionDate" DATE NOT NULL,
  "amount" INTEGER NOT NULL, "status" "CommissionCollectionStatus" NOT NULL DEFAULT 'PENDING',
  "createdByUserId" TEXT NOT NULL, "collectedAt" TIMESTAMPTZ(3), "failureReason" TEXT,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "commission_collections_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "commission_collections_workerProfileId_collectionDate_key" ON "commission_collections"("workerProfileId", "collectionDate");
CREATE INDEX "commission_collections_status_collectionDate_idx" ON "commission_collections"("status", "collectionDate");
CREATE INDEX "commission_collections_createdByUserId_idx" ON "commission_collections"("createdByUserId");

CREATE TABLE "commission_collection_items" (
  "id" TEXT NOT NULL, "collectionId" TEXT NOT NULL, "settlementId" TEXT NOT NULL,
  "amount" INTEGER NOT NULL, "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "commission_collection_items_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "commission_collection_items_collectionId_settlementId_key" ON "commission_collection_items"("collectionId", "settlementId");
CREATE INDEX "commission_collection_items_settlementId_idx" ON "commission_collection_items"("settlementId");

ALTER TABLE "settlement_cases" ADD CONSTRAINT "settlement_cases_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "settlement_cases" ADD CONSTRAINT "settlement_cases_workerProfileId_fkey" FOREIGN KEY ("workerProfileId") REFERENCES "worker_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "settlement_cases" ADD CONSTRAINT "settlement_cases_settlementId_fkey" FOREIGN KEY ("settlementId") REFERENCES "booking_settlements"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "settlement_cases" ADD CONSTRAINT "settlement_cases_assignedToUserId_fkey" FOREIGN KEY ("assignedToUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "settlement_case_events" ADD CONSTRAINT "settlement_case_events_caseId_fkey" FOREIGN KEY ("caseId") REFERENCES "settlement_cases"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "settlement_case_events" ADD CONSTRAINT "settlement_case_events_actorUserId_fkey" FOREIGN KEY ("actorUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "settlement_case_notes" ADD CONSTRAINT "settlement_case_notes_caseId_fkey" FOREIGN KEY ("caseId") REFERENCES "settlement_cases"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "settlement_case_notes" ADD CONSTRAINT "settlement_case_notes_authorUserId_fkey" FOREIGN KEY ("authorUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "settlement_contact_attempts" ADD CONSTRAINT "settlement_contact_attempts_caseId_fkey" FOREIGN KEY ("caseId") REFERENCES "settlement_cases"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "settlement_contact_attempts" ADD CONSTRAINT "settlement_contact_attempts_actorUserId_fkey" FOREIGN KEY ("actorUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "commission_collections" ADD CONSTRAINT "commission_collections_workerProfileId_fkey" FOREIGN KEY ("workerProfileId") REFERENCES "worker_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "commission_collections" ADD CONSTRAINT "commission_collections_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "commission_collection_items" ADD CONSTRAINT "commission_collection_items_collectionId_fkey" FOREIGN KEY ("collectionId") REFERENCES "commission_collections"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "commission_collection_items" ADD CONSTRAINT "commission_collection_items_settlementId_fkey" FOREIGN KEY ("settlementId") REFERENCES "booking_settlements"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
