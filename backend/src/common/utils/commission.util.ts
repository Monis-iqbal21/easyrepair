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
 *   zero. The inspection fee remains a worker earning, but it is not a
 *   commissionable amount.
 *
 * Returns null when there is nothing to base a commission on (e.g. finalPrice
 * was never set) — callers should treat that booking as contributing 0.
 */
export function calculateCommissionBase(
  input: CommissionBaseInput,
): number | null {
  if (input.lane === BookingLane.INSPECTION) {
    if (
      input.inspectionReport?.decisionStatus ===
      InspectionDecisionStatus.ACCEPTED_REPAIR
    ) {
      return input.inspectionReport.labourCost;
    }
    if (
      input.inspectionReport?.decisionStatus ===
      InspectionDecisionStatus.FIND_OTHER_USTAAD
    ) {
      return input.finalPrice;
    }
    // A declined/no-repair inspection earns its fee, but the fee is never
    // commissionable labour.
    return 0;
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
  if (input.lane === BookingLane.INSPECTION) {
    if (
      input.inspectionReport?.decisionStatus ===
      InspectionDecisionStatus.ACCEPTED_REPAIR
    ) {
      return input.inspectionReport.labourCost;
    }
    return input.finalPrice ?? 0;
  }
  return input.finalPrice ?? 0;
}

export type SettlementCaseType =
  | 'SHORT'
  | 'UNPAID_LABOUR'
  | 'UNPAID_FEE'
  | 'AUTO_SETTLE';

export interface SettleBookingInput {
  quoteParts: number;
  quoteLabour: number;
  inspectionFee: number;
  received: number;
  autoSettled?: boolean;
}

export interface BookingSettlementCalculation {
  expectedTotal: number;
  partsPaid: number;
  labourPaid: number;
  feePaid: number;
  commission: number;
  munafa: number;
  shortfall: number;
  handygoPays: number;
  caseTypes: SettlementCaseType[];
}

/**
 * Allocates cash and calculates a booking settlement in whole rupees.
 * Parts are paid first, then labour, then inspection fee. Commission is
 * always 18% of labour actually received; parts and fees are never included.
 */
export function settleBooking(
  input: SettleBookingInput,
): BookingSettlementCalculation {
  const quoteParts = toWholeRupees(input.quoteParts);
  const quoteLabour = toWholeRupees(input.quoteLabour);
  const inspectionFee = toWholeRupees(input.inspectionFee);
  const received = toWholeRupees(input.received);
  const expectedTotal = quoteParts + quoteLabour + inspectionFee;

  if (received > expectedTotal) {
    throw new RangeError('Received cash cannot exceed the payable total');
  }

  let remaining = received;
  const partsPaid = Math.min(quoteParts, remaining);
  remaining -= partsPaid;
  const labourPaid = Math.min(quoteLabour, remaining);
  remaining -= labourPaid;
  const feePaid = Math.min(inspectionFee, remaining);

  const shortfall = Math.max(
    0,
    expectedTotal - partsPaid - labourPaid - feePaid,
  );
  const handygoPays = Math.max(0, inspectionFee - feePaid);
  const commission = Math.round(calculatePlatformFee(labourPaid));
  const munafa = labourPaid - commission + feePaid + handygoPays;
  const caseTypes: SettlementCaseType[] = [];

  if (shortfall > 0) {
    // A settlement can owe more than one kind of money at once. Keep the
    // specific fully-unpaid labour/fee cases, and use SHORT for an unpaid
    // parts balance or a partially-paid labour balance.
    if (
      quoteParts > partsPaid ||
      (labourPaid > 0 && labourPaid < quoteLabour)
    ) {
      caseTypes.push('SHORT');
    }
    if (quoteLabour > 0 && labourPaid === 0) {
      caseTypes.push('UNPAID_LABOUR');
    }
    if (inspectionFee > feePaid) {
      caseTypes.push('UNPAID_FEE');
    }
  }
  if (input.autoSettled) caseTypes.push('AUTO_SETTLE');

  return {
    expectedTotal,
    partsPaid,
    labourPaid,
    feePaid,
    commission,
    munafa,
    shortfall,
    handygoPays,
    caseTypes,
  };
}

function toWholeRupees(value: number): number {
  if (!Number.isFinite(value) || value < 0) {
    throw new RangeError(
      'Settlement money values must be finite and non-negative',
    );
  }
  return Math.round(value);
}
