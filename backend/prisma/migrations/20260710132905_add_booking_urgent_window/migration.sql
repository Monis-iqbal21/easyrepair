-- CreateEnum
CREATE TYPE "UrgentWindow" AS ENUM ('WITHIN_1_HOUR', 'WITHIN_2_HOURS', 'WITHIN_4_HOURS');

-- AlterTable
ALTER TABLE "bookings" ADD COLUMN     "urgentWindow" "UrgentWindow";
