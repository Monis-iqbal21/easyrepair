export type PaymentDisplayStatus = 'UNPAID' | 'PARTIAL' | 'PAID';

export interface PaymentDisplaySummary {
  paymentDisplayStatus: PaymentDisplayStatus;
  receivedAmount: number | null;
  expectedAmount: number | null;
  remainingAmount: number | null;
}

/**
 * Converts the current immutable settlement snapshot into the small,
 * client-safe payment summary used by booking presentation surfaces.
 *
 * A missing settlement is intentionally UNPAID with no amounts: before the
 * job completes there is no authoritative received-cash record to expose.
 * Commission allocation never enters this summary.
 */
export function derivePaymentDisplay(
  settlement: { expectedTotal: number; received: number } | null | undefined,
): PaymentDisplaySummary {
  if (!settlement) {
    return {
      paymentDisplayStatus: 'UNPAID',
      receivedAmount: null,
      expectedAmount: null,
      remainingAmount: null,
    };
  }

  const expectedAmount = settlement.expectedTotal;
  const receivedAmount = settlement.received;
  const remainingAmount = Math.max(expectedAmount - receivedAmount, 0);
  const paymentDisplayStatus: PaymentDisplayStatus =
    expectedAmount > 0 && receivedAmount >= expectedAmount
      ? 'PAID'
      : receivedAmount > 0
        ? 'PARTIAL'
        : 'UNPAID';

  return {
    paymentDisplayStatus,
    receivedAmount,
    expectedAmount,
    remainingAmount,
  };
}
