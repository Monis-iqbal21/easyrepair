CREATE TYPE "ComplaintIssueType" AS ENUM (
  'WORK_QUALITY',
  'PRICE_PAYMENT',
  'USTAAD_BEHAVIOUR',
  'DAMAGE',
  'PART_MATERIAL',
  'WARRANTY_REWORK',
  'OTHER'
);

CREATE TYPE "ComplaintSource" AS ENUM (
  'APP_CUSTOMER',
  'APP_WORKER',
  'WEBSITE_BOT',
  'WHATSAPP_BOT',
  'EMAIL',
  'ADMIN'
);

CREATE TYPE "ComplaintStatus" AS ENUM (
  'OPEN',
  'IN_PROGRESS',
  'WAITING_ON_CUSTOMER',
  'RESOLVED',
  'CLOSED'
);

CREATE TYPE "ComplaintPriority" AS ENUM ('LOW', 'NORMAL', 'HIGH', 'URGENT');

CREATE TYPE "ComplaintEventType" AS ENUM (
  'CREATED',
  'STATUS_CHANGED',
  'ASSIGNED',
  'PRIORITY_CHANGED',
  'HUMAN_REQUESTED',
  'RESOLVED',
  'REOPENED'
);

CREATE TABLE "complaints" (
  "id" TEXT NOT NULL,
  "bookingId" TEXT,
  "reporterUserId" TEXT,
  "reportedWorkerProfileId" TEXT,
  "issueTypes" "ComplaintIssueType"[] NOT NULL,
  "otherText" TEXT,
  "source" "ComplaintSource" NOT NULL,
  "status" "ComplaintStatus" NOT NULL DEFAULT 'OPEN',
  "priority" "ComplaintPriority" NOT NULL DEFAULT 'NORMAL',
  "assignedToUserId" TEXT,
  "humanRequested" BOOLEAN NOT NULL DEFAULT FALSE,
  "humanRequestedAt" TIMESTAMPTZ(3),
  "resolvedAt" TIMESTAMPTZ(3),
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "complaints_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "complaints_issue_types_not_empty_check"
    CHECK (cardinality("issueTypes") > 0),
  CONSTRAINT "complaints_other_text_check"
    CHECK (
      NOT ('OTHER'::"ComplaintIssueType" = ANY("issueTypes"))
      OR NULLIF(BTRIM("otherText"), '') IS NOT NULL
    ),
  CONSTRAINT "complaints_human_requested_at_check"
    CHECK (
      ("humanRequested" = FALSE AND "humanRequestedAt" IS NULL)
      OR ("humanRequested" = TRUE AND "humanRequestedAt" IS NOT NULL)
    )
);

-- PostgreSQL treats NULL values as distinct in a normal unique index. This is
-- the database-level one-Complaint-per-booking guarantee while preserving
-- unlimited future complaints whose bookingId is NULL.
CREATE UNIQUE INDEX "complaints_bookingId_key" ON "complaints"("bookingId");
CREATE INDEX "complaints_status_priority_createdAt_idx"
  ON "complaints"("status", "priority", "createdAt");
CREATE INDEX "complaints_reporterUserId_idx" ON "complaints"("reporterUserId");
CREATE INDEX "complaints_reportedWorkerProfileId_idx"
  ON "complaints"("reportedWorkerProfileId");
CREATE INDEX "complaints_assignedToUserId_idx"
  ON "complaints"("assignedToUserId");

CREATE TABLE "complaint_events" (
  "id" TEXT NOT NULL,
  "complaintId" TEXT NOT NULL,
  "type" "ComplaintEventType" NOT NULL,
  "actorUserId" TEXT,
  "metadata" JSONB,
  "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "complaint_events_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "complaint_events_complaintId_createdAt_idx"
  ON "complaint_events"("complaintId", "createdAt");
CREATE INDEX "complaint_events_actorUserId_idx"
  ON "complaint_events"("actorUserId");

ALTER TABLE "notifications" ADD COLUMN "complaintEventId" TEXT;
CREATE UNIQUE INDEX "notifications_complaintEventId_key"
  ON "notifications"("complaintEventId");

ALTER TABLE "complaints"
  ADD CONSTRAINT "complaints_bookingId_fkey"
  FOREIGN KEY ("bookingId") REFERENCES "bookings"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "complaints"
  ADD CONSTRAINT "complaints_reporterUserId_fkey"
  FOREIGN KEY ("reporterUserId") REFERENCES "users"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "complaints"
  ADD CONSTRAINT "complaints_reportedWorkerProfileId_fkey"
  FOREIGN KEY ("reportedWorkerProfileId") REFERENCES "worker_profiles"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "complaints"
  ADD CONSTRAINT "complaints_assignedToUserId_fkey"
  FOREIGN KEY ("assignedToUserId") REFERENCES "users"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "complaint_events"
  ADD CONSTRAINT "complaint_events_complaintId_fkey"
  FOREIGN KEY ("complaintId") REFERENCES "complaints"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "complaint_events"
  ADD CONSTRAINT "complaint_events_actorUserId_fkey"
  FOREIGN KEY ("actorUserId") REFERENCES "users"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "notifications"
  ADD CONSTRAINT "notifications_complaintEventId_fkey"
  FOREIGN KEY ("complaintEventId") REFERENCES "complaint_events"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
