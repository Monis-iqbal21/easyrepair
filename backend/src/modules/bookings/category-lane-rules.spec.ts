import { BadRequestException } from '@nestjs/common';
import { BookingLane } from '@prisma/client';

import {
  assertLaneAllowed,
  resolveSoleLane,
} from '../categories/category-lanes';

/**
 * Lane-restricted service categories.
 *
 * There are two restriction fields and `soleLane` supersedes `inspectionOnly`
 * WITHOUT replacing it — the legacy boolean is still stored and still returned
 * by /categories so an older APK keeps working. The precedence is:
 *
 *   1. soleLane set        -> that lane, and nothing else.
 *   2. else inspectionOnly -> INSPECTION only (legacy behaviour, verbatim).
 *   3. else                -> unrestricted.
 *
 * The client app renders only the resolved lane, but that is a convenience —
 * the server owns the rule, because an older app build, a replayed request or
 * a direct API call must not be able to open a booking in a lane the category
 * does not offer. `assertLaneAllowed` is the single predicate both write paths
 * call: `createBooking` for a new booking's chosen lane, and `updateBooking`
 * when an edit moves a booking to a different category.
 *
 * These tests exercise the exported predicate directly rather than booting the
 * whole service, so the contract stays legible and cannot drift.
 */

const ALL_LANES: BookingLane[] = [
  BookingLane.STANDARD,
  BookingLane.INSPECTION,
  BookingLane.BIDDING,
];

/** Appliances Repair — BIDDING and nothing else, via soleLane. */
const appliances = {
  name: 'Appliances Repair',
  inspectionOnly: false,
  soleLane: BookingLane.BIDDING,
};

/** An ordinary, unrestricted category. */
const electrician = {
  name: 'Electrician',
  inspectionOnly: false,
  soleLane: null,
};

/** A category still restricted the OLD way: the legacy boolean, no soleLane. */
const legacyInspectionOnly = {
  name: 'Legacy Inspection Only',
  inspectionOnly: true,
  soleLane: null,
};

describe('rule 1 — soleLane wins: Appliances Repair is BIDDING-only', () => {
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

  it('soleLane overrides inspectionOnly even when the legacy flag is still '
    + 'true — a stale row must not resurrect the old restriction', () => {
    const contradictory = {
      name: 'Contradictory',
      inspectionOnly: true,
      soleLane: BookingLane.BIDDING,
    };

    expect(resolveSoleLane(contradictory)).toBe(BookingLane.BIDDING);
    expect(() =>
      assertLaneAllowed(contradictory, BookingLane.BIDDING),
    ).not.toThrow();
    expect(() =>
      assertLaneAllowed(contradictory, BookingLane.INSPECTION),
    ).toThrow(BadRequestException);
  });
});

describe('rule 2 — legacy inspectionOnly categories behave exactly as before', () => {
  it('resolves to INSPECTION', () => {
    expect(resolveSoleLane(legacyInspectionOnly)).toBe(BookingLane.INSPECTION);
  });

  it('accepts the INSPECTION lane', () => {
    expect(() =>
      assertLaneAllowed(legacyInspectionOnly, BookingLane.INSPECTION),
    ).not.toThrow();
  });

  it.each([
    ['STANDARD', BookingLane.STANDARD],
    ['BIDDING', BookingLane.BIDDING],
  ])('rejects %s', (_label, lane) => {
    expect(() => assertLaneAllowed(legacyInspectionOnly, lane)).toThrow(
      BadRequestException,
    );
  });

  it('rejects with the SAME message the legacy guard produced, word for '
    + 'word — an existing client parses or displays this string', () => {
    expect(() =>
      assertLaneAllowed(legacyInspectionOnly, BookingLane.BIDDING),
    ).toThrow(
      '"Legacy Inspection Only" is available for inspection bookings only.',
    );
  });

  it('a missing soleLane property falls through to the legacy flag rather '
    + 'than skipping the restriction', () => {
    // A narrowed `select`, or a row read before the soleLane column existed,
    // hands over a category with no soleLane at all. That must still honour
    // inspectionOnly, or a legacy category would silently gain every lane.
    const partial = { name: 'Legacy Inspection Only', inspectionOnly: true };

    expect(resolveSoleLane(partial)).toBe(BookingLane.INSPECTION);
    expect(() => assertLaneAllowed(partial, BookingLane.BIDDING)).toThrow(
      BadRequestException,
    );
  });

  it('an explicitly null soleLane behaves the same as an absent one', () => {
    expect(resolveSoleLane({ ...legacyInspectionOnly, soleLane: null })).toBe(
      BookingLane.INSPECTION,
    );
  });
});

describe('rule 3 — normal categories remain unchanged', () => {
  it.each([
    ['STANDARD', BookingLane.STANDARD],
    ['INSPECTION', BookingLane.INSPECTION],
    ['BIDDING', BookingLane.BIDDING],
  ])('an unrestricted category still accepts %s', (_label, lane) => {
    expect(() => assertLaneAllowed(electrician, lane)).not.toThrow();
  });

  it('resolves to no restriction at all', () => {
    expect(resolveSoleLane(electrician)).toBeNull();
  });

  it('a record carrying NEITHER field is unrestricted, not restricted to '
    + 'nothing', () => {
    // Reading a missing restriction as a restriction would lock EVERY lane on
    // EVERY category — the worst possible failure — so absent must behave
    // identically to "no restriction".
    const bare = { name: 'Partially Selected' };

    expect(resolveSoleLane(bare)).toBeNull();
    for (const lane of ALL_LANES) {
      expect(() => assertLaneAllowed(bare, lane)).not.toThrow();
    }
  });

  it('inspectionOnly false with a null soleLane restricts nothing, whatever '
    + 'the lane', () => {
    for (const lane of ALL_LANES) {
      expect(() => assertLaneAllowed(electrician, lane)).not.toThrow();
    }
  });
});

describe('the restriction is general, not Appliances-shaped', () => {
  it('any category may be restricted to any lane via soleLane', () => {
    const standardOnly = {
      name: 'Some Future Category',
      inspectionOnly: false,
      soleLane: BookingLane.STANDARD,
    };

    expect(() =>
      assertLaneAllowed(standardOnly, BookingLane.STANDARD),
    ).not.toThrow();
    expect(() => assertLaneAllowed(standardOnly, BookingLane.BIDDING)).toThrow(
      BadRequestException,
    );
    expect(() =>
      assertLaneAllowed(standardOnly, BookingLane.INSPECTION),
    ).toThrow(BadRequestException);
  });

  it('an INSPECTION soleLane and the legacy flag are interchangeable', () => {
    const viaSoleLane = {
      name: 'X',
      inspectionOnly: false,
      soleLane: BookingLane.INSPECTION,
    };
    const viaLegacyFlag = { name: 'X', inspectionOnly: true, soleLane: null };

    for (const lane of ALL_LANES) {
      const soleLaneThrew = (() => {
        try {
          assertLaneAllowed(viaSoleLane, lane);
          return false;
        } catch {
          return true;
        }
      })();
      const legacyThrew = (() => {
        try {
          assertLaneAllowed(viaLegacyFlag, lane);
          return false;
        } catch {
          return true;
        }
      })();

      expect(soleLaneThrew).toBe(legacyThrew);
    }
  });
});
