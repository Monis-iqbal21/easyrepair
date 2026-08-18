-- Adds Booking.attachedInspectionBookingId — an optional, purely
-- INFORMATIONAL reference to a previously COMPLETED inspection booking whose
-- report a client manually attached while independently posting a new
-- BIDDING job. Read-only supporting context for bidders; it carries no
-- business behavior of its own.
--
-- Deliberately SEPARATE from the existing "sourceInspectionBookingId" column,
-- which means "this repair job was SPAWNED from that inspection" and drives
-- the worker labour-cost earnings override, the inspection-fee-paid
-- derivation, original-inspector bidding exclusion, BIDDING_LINKED
-- notification copy, and Find-Other-Ustaad idempotency. None of those apply
-- to a manual attachment: the original inspection was already closed and
-- paid, and the original inspecting Ustaad remains free to bid on the new job.
--
-- Intentionally NOT UNIQUE (unlike sourceInspectionBookingId): one historical
-- inspection may be attached to any number of later bidding jobs.
--
-- Additive and non-destructive: one nullable column plus an index. Every
-- existing row keeps NULL, no data is read, written, backfilled or deleted,
-- and no existing constraint is altered. ON DELETE SET NULL guarantees that
-- removing either side never mutates or cascades into the other.
--
-- NOT applied to the live database by this change — apply with
-- `prisma migrate deploy` when ready.

ALTER TABLE "bookings" ADD COLUMN "attachedInspectionBookingId" TEXT;

CREATE INDEX "bookings_attachedInspectionBookingId_idx"
  ON "bookings" ("attachedInspectionBookingId");

ALTER TABLE "bookings"
  ADD CONSTRAINT "bookings_attachedInspectionBookingId_fkey"
  FOREIGN KEY ("attachedInspectionBookingId")
  REFERENCES "bookings" ("id")
  ON DELETE SET NULL
  ON UPDATE CASCADE;
