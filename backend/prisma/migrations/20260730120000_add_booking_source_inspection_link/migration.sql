-- AlterTable
ALTER TABLE "bookings" ADD COLUMN     "sourceInspectionBookingId" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "bookings_sourceInspectionBookingId_key" ON "bookings"("sourceInspectionBookingId");

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_sourceInspectionBookingId_fkey" FOREIGN KEY ("sourceInspectionBookingId") REFERENCES "bookings"("id") ON DELETE SET NULL ON UPDATE CASCADE;
