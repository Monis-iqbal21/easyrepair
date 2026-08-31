import { Type } from 'class-transformer';
import { IsInt, Min } from 'class-validator';

/**
 * "Kam paisa mila" — the Ustaad declares the whole-rupee CASH total they
 * actually received for a completed job.
 *
 * This carries a FACT and nothing else. The app never computes a shortfall,
 * a commission or an earning: `settleBooking` on the server allocates the
 * cash (parts → labour → inspection fee), takes 18% of the labour actually
 * received, and opens the settlement case. `@Min(0)` rejects a negative
 * amount here; an amount larger than the payable total is rejected by
 * `settleBooking` itself, so the two impossible values are refused
 * server-side either way.
 */
export class ReportReceivedPaymentDto {
  @Type(() => Number)
  @IsInt()
  @Min(0)
  receivedCashTotal: number;
}

/** What the Ustaad gets back — every number computed by the server. */
export interface UstaadPaymentReportDto {
  settlementId: string;
  bookingId: string;
  /** The whole payable total: parts + labour + inspection fee. */
  expectedTotal: number;
  /** The cash the Ustaad declared. */
  receivedCashTotal: number;
  /** Server allocation of that cash, in waterfall order. */
  partsPaid: number;
  labourPaid: number;
  feePaid: number;
  /** 18% of `labourPaid` — never of parts, never of the inspection fee. */
  commission: number;
  /** What the Ustaad keeps. */
  munafa: number;
  /** Still owed by the client; 0 when the job was paid in full. */
  shortfall: number;
  recordedAt: Date;
  isCurrent: true;
}
