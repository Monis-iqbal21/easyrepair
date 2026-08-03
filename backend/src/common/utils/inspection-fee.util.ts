import { BookingLane, BookingStatus } from '@prisma/client';

/**
 * THE single rule for "has the client paid the inspection fee?".
 *
 * The answer is derived ONLY from the original inspection work unit reaching
 * COMPLETED — never from the existence of an InspectionReport, never from a
 * linked repair booking, and never from `Booking.paymentStatus` (which is a
 * dead column: nothing in the backend has ever written to it, so every row
 * sits at its PENDING default).
 *
 * Consequences that fall out of that one rule:
 *   - inspection still in progress            → false ("not paid")
 *   - inspection COMPLETED, no repair yet     → true  ("paid")
 *   - repair later completed                  → still true
 *   - original inspector rehired for repair   → still true
 *   - a different Ustaad performs the repair  → still true
 *   - legacy same-row inspection data         → handled by the lane branch
 *
 * The inspection fee and the repair are separate work units financially; this
 * never merges them.
 */
export interface InspectionFeeBooking {
  lane: BookingLane | string;
  status: BookingStatus | string;
  /** Set on a repair booking spawned by "Find Other Ustaad". */
  sourceInspectionBookingId?: string | null;
  /** The source inspection booking — only its status is needed. */
  sourceInspectionBooking?: { status: BookingStatus | string } | null;
}

/**
 * `true` = fee paid, `false` = not paid yet, `null` = no inspection is
 * involved in this booking at all (so no fee status should be shown).
 */
export function deriveInspectionFeePaid(
  booking: InspectionFeeBooking,
): boolean | null {
  // The inspection work unit itself — including legacy same-row records where
  // the repair was reopened in place.
  if (booking.lane === BookingLane.INSPECTION) {
    return booking.status === BookingStatus.COMPLETED;
  }

  // A repair booking linked back to a completed inspection. The fee belongs
  // to that SOURCE inspection, never to this repair's own status.
  if (booking.sourceInspectionBookingId != null) {
    const sourceStatus = booking.sourceInspectionBooking?.status;
    // Relation not loaded — report "unknown" rather than guessing "not paid",
    // which would be a visible lie to the client.
    if (sourceStatus == null) return null;
    return sourceStatus === BookingStatus.COMPLETED;
  }

  // Standard / ordinary bidding booking — no inspection fee concept.
  return null;
}
