-- FIX 6: the AC Technician inspection fee was Rs 1000 while every other
-- inspection category charges Rs 500. The authoritative source is
-- ServiceCategory.inspectionFee (BookingsService.createBooking snapshots it
-- into Booking.inspectionFeeSnapshot, and every screen renders the snapshot),
-- so correcting the row here corrects every surface at once.
--
-- Deliberately scoped to the category row only. Existing bookings keep their
-- inspectionFeeSnapshot exactly as taken — the money already quoted to, and in
-- some cases already collected from, a client is never rewritten.
UPDATE "service_categories"
SET "inspectionFee" = 500
WHERE "name" = 'AC Technician'
  AND "inspectionFee" = 1000;
