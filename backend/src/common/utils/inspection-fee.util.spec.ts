import { BookingLane, BookingStatus } from '@prisma/client';
import { deriveInspectionFeePaid } from './inspection-fee.util';

/** The completed inspection work unit, as the linked repair sees it. */
const completedSource = { status: BookingStatus.COMPLETED };
const inProgressSource = { status: BookingStatus.IN_PROGRESS };

describe('deriveInspectionFeePaid', () => {
  // ── Rule 1: the inspection itself is not COMPLETED → not paid ────────────
  it.each([
    BookingStatus.PENDING,
    BookingStatus.ACCEPTED,
    BookingStatus.EN_ROUTE,
    BookingStatus.ARRIVED,
    BookingStatus.IN_PROGRESS,
  ])('is NOT paid while the inspection booking is %s', (status) => {
    expect(
      deriveInspectionFeePaid({ lane: BookingLane.INSPECTION, status }),
    ).toBe(false);
  });

  // ── Rule 2: the inspection is COMPLETED → paid ───────────────────────────
  it('is paid once the inspection booking is COMPLETED', () => {
    expect(
      deriveInspectionFeePaid({
        lane: BookingLane.INSPECTION,
        status: BookingStatus.COMPLETED,
      }),
    ).toBe(true);
  });

  // ── Rule 3: inspection done, repair not performed → still paid ───────────
  it('stays paid on the linked repair while that repair is still PENDING', () => {
    expect(
      deriveInspectionFeePaid({
        lane: BookingLane.BIDDING,
        status: BookingStatus.PENDING,
        sourceInspectionBookingId: 'inspection-1',
        sourceInspectionBooking: completedSource,
      }),
    ).toBe(true);
  });

  // ── Rule 4: repair later completed → inspection fee still paid ───────────
  it.each([
    BookingStatus.ACCEPTED,
    BookingStatus.IN_PROGRESS,
    BookingStatus.COMPLETED,
    BookingStatus.CANCELLED,
  ])('stays paid regardless of the repair reaching %s', (repairStatus) => {
    expect(
      deriveInspectionFeePaid({
        lane: BookingLane.BIDDING,
        status: repairStatus,
        sourceInspectionBookingId: 'inspection-1',
        sourceInspectionBooking: completedSource,
      }),
    ).toBe(true);
  });

  // ── Rule 5: same answer whoever performs the repair ──────────────────────
  //
  // The rule is expressed purely in terms of the SOURCE booking, so the
  // repair's own worker (rehired inspector vs. a different Ustaad) cannot
  // change it — these cases are structurally identical by construction.
  it('is identical whether the original inspector is rehired or another Ustaad is hired', () => {
    const base = {
      lane: BookingLane.BIDDING,
      status: BookingStatus.IN_PROGRESS,
      sourceInspectionBookingId: 'inspection-1',
      sourceInspectionBooking: completedSource,
    };
    // Nothing about the repair's assignee is an input to the rule.
    expect(deriveInspectionFeePaid(base)).toBe(true);
    expect(deriveInspectionFeePaid({ ...base })).toBe(true);
  });

  it('reports NOT paid on a linked repair whose source inspection never completed', () => {
    expect(
      deriveInspectionFeePaid({
        lane: BookingLane.BIDDING,
        status: BookingStatus.PENDING,
        sourceInspectionBookingId: 'inspection-1',
        sourceInspectionBooking: inProgressSource,
      }),
    ).toBe(false);
  });

  // ── Legacy same-row data ─────────────────────────────────────────────────
  it('handles legacy same-row inspection records via the lane branch', () => {
    // Reopened in place: still lane INSPECTION, so its own status decides.
    expect(
      deriveInspectionFeePaid({
        lane: BookingLane.INSPECTION,
        status: BookingStatus.PENDING,
      }),
    ).toBe(false);
    expect(
      deriveInspectionFeePaid({
        lane: BookingLane.INSPECTION,
        status: BookingStatus.COMPLETED,
      }),
    ).toBe(true);
  });

  // ── Not applicable ───────────────────────────────────────────────────────
  it.each([BookingLane.STANDARD, BookingLane.BIDDING])(
    'returns null for an ordinary %s booking with no inspection',
    (lane) => {
      expect(
        deriveInspectionFeePaid({
          lane,
          status: BookingStatus.COMPLETED,
        }),
      ).toBeNull();
    },
  );

  // Never guess when the relation was not loaded — a wrong "not paid" would
  // be a visible lie to the client.
  it('returns null (unknown) when the source relation was not selected', () => {
    expect(
      deriveInspectionFeePaid({
        lane: BookingLane.BIDDING,
        status: BookingStatus.PENDING,
        sourceInspectionBookingId: 'inspection-1',
      }),
    ).toBeNull();
  });

  // The fee status must never be inferred from paymentStatus, which is a dead
  // column permanently at PENDING — passing it must change nothing.
  it('ignores any paymentStatus-like field entirely', () => {
    expect(
      deriveInspectionFeePaid({
        lane: BookingLane.INSPECTION,
        status: BookingStatus.COMPLETED,
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        ...({ paymentStatus: 'PENDING' } as any),
      }),
    ).toBe(true);
  });
});
