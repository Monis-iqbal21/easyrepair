-- CreateEnum
CREATE TYPE "BookingUrgency" AS ENUM ('URGENT', 'NORMAL');

-- CreateEnum
CREATE TYPE "TimeSlot" AS ENUM ('MORNING', 'AFTERNOON', 'EVENING', 'NIGHT');

-- AlterTable: add urgency, timeSlot, title fields to bookings
ALTER TABLE "bookings"
  ADD COLUMN "urgency"  "BookingUrgency" NOT NULL DEFAULT 'NORMAL',
  ADD COLUMN "timeSlot" "TimeSlot",
  ADD COLUMN "title"    TEXT;
