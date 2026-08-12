import { BookingLane, InspectionDecisionStatus } from '@prisma/client';

/**
 * HandyGo's platform commission rate. Applies ONLY to the labour/service
 * amount — parts are always a pass-through cost to the customer and must
 * never be counted toward commission or worker earnings.
 */
export const PLATFORM_COMMISSION_RATE = 0.18;

export interface CommissionBaseInput {
  lane: BookingLane;
  finalPrice: number | null;
  inspectionReport?: {
    labourCost: number;
    decisionStatus: InspectionDecisionStatus;
  } | null;
}

/**
 * The labour/service amount commission is computed on — never parts.
 *
 * - STANDARD / BIDDING: `finalPrice` is already labour/service-only (neither
 *   lane has a parts concept), so it's used directly.
 * - INSPECTION with an ACCEPTED_REPAIR report: `labourCost` only — the
 *   report's `partsTotal` is deliberately excluded from this base.
 * - INSPECTION with a CLOSED_AFTER_INSPECTION report (or no report at all):
 *   the customer only ever paid the inspection fee. `finalPrice` at this
 *   point is still `inspectionFeeSnapshot` (untouched since assignment —
 *   only an accepted quote overwrites it), and that fee is itself the
 *   worker's earning base, matching existing business behavior.
 *
 * Returns null when there is nothing to base a commission on (e.g. finalPrice
 * was never set) — callers should treat that booking as contributing 0.
 */
export function calculateCommissionBase(
  input: CommissionBaseInput,
): number | null {
  if (input.lane === BookingLane.INSPECTION && input.inspectionReport) {
    if (
      input.inspectionReport.decisionStatus ===
      InspectionDecisionStatus.ACCEPTED_REPAIR
    ) {
      return input.inspectionReport.labourCost;
    }
    return input.finalPrice;
  }
  return input.finalPrice;
}

/** 18% platform commission on the commission base (labour/service only). */
export function calculatePlatformFee(commissionBase: number): number {
  return Math.round(commissionBase * PLATFORM_COMMISSION_RATE * 100) / 100;
}

/** What the worker actually keeps after HandyGo's commission is deducted. */
export function calculateWorkerEarning(
  commissionBase: number,
  platformFee: number,
): number {
  return Math.max(0, Math.round((commissionBase - platformFee) * 100) / 100);
}

/**
 * The worker-facing gross earning for a completed booking — the full
 * pre-commission amount (same value `calculatePlatformFee`'s 18% is computed
 * from), exposed under a clearer name for earnings/stats/history display.
 *
 * The Worker Earning History screen shows this alongside
 * `calculatePlatformFee` and `calculateWorkerEarning` side by side (Gross /
 * HandyGo Commission / Ustaad Earning) — see
 * `WorkersRepository.getEarningsHistory`. The "today" dashboard tile still
 * shows gross only.
 */
export function calculateGrossWorkerEarning(
  input: CommissionBaseInput,
): number {
  return calculateCommissionBase(input) ?? 0;
}
