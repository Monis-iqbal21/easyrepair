-- CreateEnum
CREATE TYPE "InspectionDecisionStatus" AS ENUM ('PENDING_CLIENT_DECISION', 'ACCEPTED_REPAIR', 'CLOSED_AFTER_INSPECTION');

-- CreateTable
CREATE TABLE "inspection_reports" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "workerProfileId" TEXT NOT NULL,
    "issueFound" TEXT NOT NULL,
    "recommendedRepair" TEXT NOT NULL,
    "labourCost" DOUBLE PRECISION NOT NULL,
    "partsNeeded" BOOLEAN NOT NULL DEFAULT false,
    "partsTotal" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "repairQuoteTotal" DOUBLE PRECISION NOT NULL,
    "notes" TEXT,
    "decisionStatus" "InspectionDecisionStatus" NOT NULL DEFAULT 'PENDING_CLIENT_DECISION',
    "acceptedAt" TIMESTAMP(3),
    "closedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "inspection_reports_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "inspection_report_parts" (
    "id" TEXT NOT NULL,
    "reportId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "unitPrice" DOUBLE PRECISION NOT NULL,
    "warranty" TEXT,
    "lineTotal" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "inspection_report_parts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "inspection_report_photos" (
    "id" TEXT NOT NULL,
    "reportId" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "storageKey" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "inspection_report_photos_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "inspection_reports_bookingId_key" ON "inspection_reports"("bookingId");

-- CreateIndex
CREATE INDEX "inspection_reports_workerProfileId_idx" ON "inspection_reports"("workerProfileId");

-- CreateIndex
CREATE INDEX "inspection_report_parts_reportId_idx" ON "inspection_report_parts"("reportId");

-- CreateIndex
CREATE INDEX "inspection_report_photos_reportId_idx" ON "inspection_report_photos"("reportId");

-- AddForeignKey
ALTER TABLE "inspection_reports" ADD CONSTRAINT "inspection_reports_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "bookings"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "inspection_reports" ADD CONSTRAINT "inspection_reports_workerProfileId_fkey" FOREIGN KEY ("workerProfileId") REFERENCES "worker_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "inspection_report_parts" ADD CONSTRAINT "inspection_report_parts_reportId_fkey" FOREIGN KEY ("reportId") REFERENCES "inspection_reports"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "inspection_report_photos" ADD CONSTRAINT "inspection_report_photos_reportId_fkey" FOREIGN KEY ("reportId") REFERENCES "inspection_reports"("id") ON DELETE CASCADE ON UPDATE CASCADE;
