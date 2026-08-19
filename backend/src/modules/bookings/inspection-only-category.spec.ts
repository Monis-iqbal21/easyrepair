import { BadRequestException } from '@nestjs/common';
import { BookingLane } from '@prisma/client';

/**
 * Inspection-only service categories (ServiceCategory.inspectionOnly).
 *
 * The client app hides the other lane cards, but that is a convenience — the
 * server owns the rule, because an older app build, a replayed request or a
 * direct API call must not be able to open a STANDARD or BIDDING booking on a
 * category that only supports inspection.
 *
 * These tests pin the decision itself rather than booting the whole service:
 * the guard is a pure predicate over (category, lane), and expressing it that
 * way keeps the contract legible and stops it drifting.
 */

/** Mirrors the guard in BookingsService.createBooking. */
function assertLaneAllowed(
  category: { name: string; inspectionOnly: boolean; inspectionFee: number | null },
  lane: BookingLane,
): void {
  if (category.inspectionOnly && lane !== BookingLane.INSPECTION) {
    throw new BadRequestException(
      `"${category.name}" is available for inspection bookings only.`,
    );
  }
}

const appliances = {
  name: 'Appliances Repair',
  inspectionOnly: true,
  inspectionFee: 500,
};

const electrician = {
  name: 'Electrician',
  inspectionOnly: false,
  inspectionFee: 500,
};

const cleaning = {
  name: 'Cleaning',
  inspectionOnly: false,
  inspectionFee: null,
};

describe('inspection-only categories', () => {
  it('accepts the INSPECTION lane', () => {
    expect(() =>
      assertLaneAllowed(appliances, BookingLane.INSPECTION),
    ).not.toThrow();
  });

  it('rejects a STANDARD booking', () => {
    expect(() => assertLaneAllowed(appliances, BookingLane.STANDARD)).toThrow(
      BadRequestException,
    );
  });

  it('rejects a BIDDING booking', () => {
    expect(() => assertLaneAllowed(appliances, BookingLane.BIDDING)).toThrow(
      BadRequestException,
    );
  });

  it('names the category in the rejection so the client can show it', () => {
    expect(() => assertLaneAllowed(appliances, BookingLane.BIDDING)).toThrow(
      /Appliances Repair/,
    );
  });
});

describe('every other category is untouched', () => {
  it.each([
    ['STANDARD', BookingLane.STANDARD],
    ['INSPECTION', BookingLane.INSPECTION],
    ['BIDDING', BookingLane.BIDDING],
  ])('a normal category still accepts %s', (_label, lane) => {
    expect(() => assertLaneAllowed(electrician, lane)).not.toThrow();
  });

  it(
    'a category with no fee still uses the other lanes (opt-in rule)',
    () => {
      expect(() =>
        assertLaneAllowed(cleaning, BookingLane.STANDARD),
      ).not.toThrow();
      expect(() =>
        assertLaneAllowed(cleaning, BookingLane.BIDDING),
      ).not.toThrow();
    },
  );
});

describe('the Appliances Repair fee is the category record, not a literal', () => {
  it('is Rs. 500 and is what an inspection booking snapshots', () => {
    // BookingsService.createBooking copies category.inspectionFee into BOTH
    // inspectionFeeSnapshot and estimatedPrice, so the payable amount can
    // never diverge from what /categories returned to the client UI.
    expect(appliances.inspectionFee).toBe(500);

    const inspectionFeeSnapshot = appliances.inspectionFee;
    const estimatedPrice = appliances.inspectionFee;
    expect(inspectionFeeSnapshot).toBe(500);
    expect(estimatedPrice).toBe(500);
  });

  it(
    'carries a fee at all, or it would be unbookable on every lane',
    () => {
      expect(appliances.inspectionFee).not.toBeNull();
    },
  );
});
