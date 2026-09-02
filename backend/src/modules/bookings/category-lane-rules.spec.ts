import { BadRequestException } from '@nestjs/common';
import { BookingLane } from '@prisma/client';

import { assertLaneAllowed } from '../categories/category-lanes';

/**
 * Lane-restricted service categories (ServiceCategory.soleLane).
 *
 * The client app renders only the allowed lane, but that is a convenience —
 * the server owns the rule, because an older app build, a replayed request or
 * a direct API call must not be able to open a booking in a lane the category
 * does not offer. `assertLaneAllowed` is the single predicate both write
 * paths call: `createBooking` for a new booking's chosen lane, and
 * `updateBooking` when an edit moves a booking to a different category.
 *
 * These tests exercise that exported predicate directly rather than booting
 * the whole service, so the contract stays legible and cannot drift.
 */

/** Appliances Repair — BIDDING and nothing else. */
const appliances = {
  name: 'Appliances Repair',
  soleLane: BookingLane.BIDDING,
};

/** An ordinary, unrestricted category. */
const electrician = {
  name: 'Electrician',
  soleLane: null,
};

/**
 * A category restricted to INSPECTION — the shape the old `inspectionOnly`
 * boolean used to express, kept covered so generalising it to `soleLane` did
 * not quietly drop that rule.
 */
const inspectionOnly = {
  name: 'Legacy Inspection Only',
  soleLane: BookingLane.INSPECTION,
};

describe('Appliances Repair is BIDDING-only', () => {
  it('accepts the BIDDING lane', () => {
    expect(() =>
      assertLaneAllowed(appliances, BookingLane.BIDDING),
    ).not.toThrow();
  });

  it('rejects a STANDARD booking', () => {
    expect(() => assertLaneAllowed(appliances, BookingLane.STANDARD)).toThrow(
      BadRequestException,
    );
  });

  it('rejects an INSPECTION booking', () => {
    expect(() => assertLaneAllowed(appliances, BookingLane.INSPECTION)).toThrow(
      BadRequestException,
    );
  });

  it('names the category in the rejection so the client can show it', () => {
    expect(() => assertLaneAllowed(appliances, BookingLane.STANDARD)).toThrow(
      /Appliances Repair/,
    );
  });

  it('names the lane it DOES offer, so the message is actionable', () => {
    expect(() => assertLaneAllowed(appliances, BookingLane.INSPECTION)).toThrow(
      /custom quote/,
    );
  });
});

describe('every other category is untouched', () => {
  it.each([
    ['STANDARD', BookingLane.STANDARD],
    ['INSPECTION', BookingLane.INSPECTION],
    ['BIDDING', BookingLane.BIDDING],
  ])('an unrestricted category still accepts %s', (_label, lane) => {
    expect(() => assertLaneAllowed(electrician, lane)).not.toThrow();
  });

  it('a null soleLane never restricts anything, whatever the lane', () => {
    for (const lane of Object.values(BookingLane)) {
      expect(() => assertLaneAllowed(electrician, lane)).not.toThrow();
    }
  });

  it('a record with no soleLane property at all is unrestricted, not '
    + 'restricted to nothing', () => {
    // A narrowed `select`, or a row read before the column existed, hands over
    // a category whose soleLane is `undefined`. Reading that as a restriction
    // would lock EVERY lane on EVERY category — the worst possible failure —
    // so absent and null must behave identically.
    const partial = { name: 'Partially Selected' };

    for (const lane of Object.values(BookingLane)) {
      expect(() => assertLaneAllowed(partial, lane)).not.toThrow();
    }
  });
});

describe('the restriction is general, not Appliances-shaped', () => {
  it('an INSPECTION-only category still accepts INSPECTION', () => {
    expect(() =>
      assertLaneAllowed(inspectionOnly, BookingLane.INSPECTION),
    ).not.toThrow();
  });

  it.each([
    ['STANDARD', BookingLane.STANDARD],
    ['BIDDING', BookingLane.BIDDING],
  ])('an INSPECTION-only category rejects %s', (_label, lane) => {
    expect(() => assertLaneAllowed(inspectionOnly, lane)).toThrow(
      BadRequestException,
    );
  });
});
