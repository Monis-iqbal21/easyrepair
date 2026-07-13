-- CreateEnum
CREATE TYPE "BookingLane" AS ENUM ('STANDARD', 'INSPECTION', 'BIDDING');

-- AlterTable
ALTER TABLE "bookings" ADD COLUMN     "inspectionFeeSnapshot" DOUBLE PRECISION,
ADD COLUMN     "lane" "BookingLane" NOT NULL DEFAULT 'BIDDING',
ADD COLUMN     "standardServiceId" TEXT,
ADD COLUMN     "standardServiceNameSnapshot" TEXT,
ADD COLUMN     "standardServicePriceSnapshot" DOUBLE PRECISION;

-- AlterTable
ALTER TABLE "service_categories" ADD COLUMN     "inspectionFee" DOUBLE PRECISION;

-- CreateTable
CREATE TABLE "standard_services" (
    "id" TEXT NOT NULL,
    "categoryId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "price" DOUBLE PRECISION NOT NULL,
    "iconUrl" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "standard_services_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "standard_services_categoryId_idx" ON "standard_services"("categoryId");

-- CreateIndex
CREATE INDEX "bookings_lane_idx" ON "bookings"("lane");

-- CreateIndex
CREATE INDEX "bookings_standardServiceId_idx" ON "bookings"("standardServiceId");

-- AddForeignKey
ALTER TABLE "standard_services" ADD CONSTRAINT "standard_services_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "service_categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_standardServiceId_fkey" FOREIGN KEY ("standardServiceId") REFERENCES "standard_services"("id") ON DELETE SET NULL ON UPDATE CASCADE;
