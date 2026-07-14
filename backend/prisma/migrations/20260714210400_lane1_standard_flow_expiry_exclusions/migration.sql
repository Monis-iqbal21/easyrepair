-- AlterEnum
-- Adds ARRIVED and EXPIRED to BookingStatus. Postgres requires ALTER TYPE ...
-- ADD VALUE to run outside an explicit multi-statement transaction block in
-- older PG versions; Prisma's migrate engine handles this automatically when
-- applied via `prisma migrate deploy`. Existing rows/values are untouched.
ALTER TYPE "BookingStatus" ADD VALUE 'ARRIVED';
ALTER TYPE "BookingStatus" ADD VALUE 'EXPIRED';

-- CreateEnum
CREATE TYPE "CancelledByRole" AS ENUM ('CLIENT', 'WORKER');

-- AlterTable
-- All new columns are nullable and non-destructive. Existing rows get NULL
-- for every new column; no existing column is dropped, renamed, or has its
-- nullability/type changed.
ALTER TABLE "bookings" ADD COLUMN     "enRouteAt" TIMESTAMP(3),
ADD COLUMN     "arrivedAt" TIMESTAMP(3),
ADD COLUMN     "cancelledByRole" "CancelledByRole",
ADD COLUMN     "expiresAt" TIMESTAMP(3),
ADD COLUMN     "liveStartedAt" TIMESTAMP(3),
ADD COLUMN     "relistedAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "booking_standard_service_items" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "standardServiceId" TEXT,
    "nameSnapshot" TEXT NOT NULL,
    "priceSnapshot" DOUBLE PRECISION NOT NULL,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "booking_standard_service_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "booking_worker_exclusions" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "workerProfileId" TEXT NOT NULL,
    "reason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "booking_worker_exclusions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "bookings_expiresAt_idx" ON "bookings"("expiresAt");

-- CreateIndex
CREATE INDEX "booking_standard_service_items_bookingId_idx" ON "booking_standard_service_items"("bookingId");

-- CreateIndex
CREATE INDEX "booking_standard_service_items_standardServiceId_idx" ON "booking_standard_service_items"("standardServiceId");

-- CreateIndex
CREATE INDEX "booking_worker_exclusions_bookingId_idx" ON "booking_worker_exclusions"("bookingId");

-- CreateIndex
CREATE INDEX "booking_worker_exclusions_workerProfileId_idx" ON "booking_worker_exclusions"("workerProfileId");

-- CreateIndex
CREATE UNIQUE INDEX "booking_worker_exclusions_bookingId_workerProfileId_key" ON "booking_worker_exclusions"("bookingId", "workerProfileId");

-- AddForeignKey
ALTER TABLE "booking_standard_service_items" ADD CONSTRAINT "booking_standard_service_items_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "bookings"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_standard_service_items" ADD CONSTRAINT "booking_standard_service_items_standardServiceId_fkey" FOREIGN KEY ("standardServiceId") REFERENCES "standard_services"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_worker_exclusions" ADD CONSTRAINT "booking_worker_exclusions_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "bookings"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_worker_exclusions" ADD CONSTRAINT "booking_worker_exclusions_workerProfileId_fkey" FOREIGN KEY ("workerProfileId") REFERENCES "worker_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;
