-- Cash & Settlement foundation: append-only whole-rupee ledger plus the two
-- post-completion confirmation states. PaymentStatus is deliberately untouched.
ALTER TYPE "BookingStatus" ADD VALUE IF NOT EXISTS 'AWAITING_CONFIRMATION';
ALTER TYPE "BookingStatus" ADD VALUE IF NOT EXISTS 'SETTLED';

CREATE TYPE "SettlementSource" AS ENUM ('OTP', 'USTAAD', 'CLIENT', 'ADMIN');

CREATE TABLE "booking_settlements" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "workerProfileId" TEXT NOT NULL,
    "supersedesId" TEXT,
    "expectedParts" INTEGER NOT NULL,
    "expectedLabour" INTEGER NOT NULL,
    "expectedFee" INTEGER NOT NULL,
    "expectedTotal" INTEGER NOT NULL,
    "received" INTEGER NOT NULL,
    "source" "SettlementSource" NOT NULL,
    "partsPaid" INTEGER NOT NULL,
    "labourPaid" INTEGER NOT NULL,
    "feePaid" INTEGER NOT NULL,
    "commission" INTEGER NOT NULL,
    "munafa" INTEGER NOT NULL,
    "shortfall" INTEGER NOT NULL,
    "handygoPays" INTEGER NOT NULL,
    "note" TEXT,
    "settledByUserId" TEXT NOT NULL,
    "settledAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "booking_settlements_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "booking_settlements_supersedesId_key"
    ON "booking_settlements"("supersedesId");
CREATE INDEX "booking_settlements_bookingId_settledAt_idx"
    ON "booking_settlements"("bookingId", "settledAt");
CREATE INDEX "booking_settlements_workerProfileId_settledAt_idx"
    ON "booking_settlements"("workerProfileId", "settledAt");
CREATE INDEX "booking_settlements_settledByUserId_idx"
    ON "booking_settlements"("settledByUserId");

ALTER TABLE "booking_settlements" ADD CONSTRAINT "booking_settlements_bookingId_fkey"
    FOREIGN KEY ("bookingId") REFERENCES "bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "booking_settlements" ADD CONSTRAINT "booking_settlements_workerProfileId_fkey"
    FOREIGN KEY ("workerProfileId") REFERENCES "worker_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "booking_settlements" ADD CONSTRAINT "booking_settlements_supersedesId_fkey"
    FOREIGN KEY ("supersedesId") REFERENCES "booking_settlements"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "booking_settlements" ADD CONSTRAINT "booking_settlements_settledByUserId_fkey"
    FOREIGN KEY ("settledByUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
