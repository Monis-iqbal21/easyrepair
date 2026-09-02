import { BadRequestException } from '@nestjs/common';
import { BookingLane } from '@prisma/client';

/**
 * Which booking lanes a service category offers.
 *
 * The server owns this rule. The client app renders only the allowed lanes,
 * but that is a convenience — an older build, a replayed request or a direct
 * API call must not be able to open a booking in a lane the category does not
 * offer, so every write path asserts it here rather than trusting the caller.
 *
 * There are TWO restriction fields, and `soleLane` supersedes `inspectionOnly`
 * without replacing it. `inspectionOnly` is still stored and still returned by
 * /categories, because an older APK knows only that field and must keep
 * working. The resolution order is exactly:
 *
 *   1. `soleLane` set      → that lane, and nothing else.
 *   2. else `inspectionOnly` → INSPECTION only (legacy behaviour, verbatim).
 *   3. else                → unrestricted, exactly as before either field
 *      existed: BIDDING always, INSPECTION only when the category carries an
 *      `inspectionFee` (enforced separately, where the fee is snapshotted),
 *      STANDARD from the category's fixed-price catalog (enforced separately,
 *      by resolving the selected services against the category).
 *
 * Only the restriction half lives here. The fee and catalog rules stay where
 * they already were, next to the data they snapshot, so this file never
 * becomes a second place a lane can be silently allowed or denied.
 */
export interface CategoryLaneRule {
  name: string;
  /**
   * Absent and null both mean "no soleLane restriction — fall through to
   * `inspectionOnly`". Undefined is accepted because a caller may hand over a
   * partial category record — a narrowed `select`, or a row read before this
   * column existed — and a missing restriction must never be read as a
   * restriction to nothing.
   */
  soleLane?: BookingLane | null;
  /**
   * Legacy INSPECTION-only flag. Absent is treated as false, so a record
   * predating it, or one selected without it, stays unrestricted.
   */
  inspectionOnly?: boolean | null;
}

/**
 * The single lane [category] is restricted to, or null when it is not
 * restricted at all.
 *
 * This is the whole precedence rule, in one place, so the server, the tests
 * and the client cannot drift apart about what a category allows.
 */
export function resolveSoleLane(category: CategoryLaneRule): BookingLane | null {
  if (category.soleLane != null) return category.soleLane;
  if (category.inspectionOnly === true) return BookingLane.INSPECTION;
  return null;
}

/**
 * Throws when [lane] is not offered by [category].
 *
 * The category is named in the message so the client can show it verbatim.
 */
export function assertLaneAllowed(
  category: CategoryLaneRule,
  lane: BookingLane,
): void {
  const soleLane = resolveSoleLane(category);
  if (soleLane !== null && lane !== soleLane) {
    throw new BadRequestException(
      `"${category.name}" is available for ${LANE_LABEL[soleLane]} bookings only.`,
    );
  }
}

/** How each lane is named back to the client in a rejection. */
const LANE_LABEL: Record<BookingLane, string> = {
  [BookingLane.STANDARD]: 'fixed-price',
  [BookingLane.INSPECTION]: 'inspection',
  [BookingLane.BIDDING]: 'custom quote',
};
