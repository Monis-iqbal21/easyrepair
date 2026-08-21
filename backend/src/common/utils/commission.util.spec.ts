import { BookingLane, InspectionDecisionStatus } from '@prisma/client';
import {
  PLATFORM_COMMISSION_RATE,
  calculateCommissionBase,
  calculateGrossWorkerEarning,
  calculatePlatformFee,
  calculateWorkerEarning,
  settleBooking,
} from './commission.util';

describe('commission.util', () => {
  describe('calculateCommissionBase', () => {
    it('STANDARD lane uses finalPrice directly', () => {
      expect(
        calculateCommissionBase({
          lane: BookingLane.STANDARD,
          finalPrice: 1500,
        }),
      ).toBe(1500);
    });

    it('BIDDING lane uses finalPrice directly (the accepted bid amount)', () => {
      expect(
        calculateCommissionBase({
          lane: BookingLane.BIDDING,
          finalPrice: 2200,
        }),
      ).toBe(2200);
    });

    it('INSPECTION + ACCEPTED_REPAIR (same inspecting worker continues) uses labourCost only, excluding parts', () => {
      const base = calculateCommissionBase({
        lane: BookingLane.INSPECTION,
        finalPrice: 5000, // repairQuoteTotal (labour + parts) — must NOT be used
        inspectionReport: {
          labourCost: 3000,
          decisionStatus: InspectionDecisionStatus.ACCEPTED_REPAIR,
        },
      });
      expect(base).toBe(3000);
    });

    it("INSPECTION + FIND_OTHER_USTAAD (different worker hired via bid) uses finalPrice — the accepted bid amount, never the inspector's original quote", () => {
      const base = calculateCommissionBase({
        lane: BookingLane.INSPECTION,
        finalPrice: 1800, // the accepted bid amount set by acceptBid
        inspectionReport: {
          labourCost: 9999, // the ORIGINAL inspector's quote — must be ignored
          decisionStatus: InspectionDecisionStatus.FIND_OTHER_USTAAD,
        },
      });
      expect(base).toBe(1800);
      expect(base).not.toBe(9999);
    });

    it('INSPECTION + CLOSED_AFTER_INSPECTION has zero commissionable labour', () => {
      const base = calculateCommissionBase({
        lane: BookingLane.INSPECTION,
        finalPrice: 500,
        inspectionReport: {
          labourCost: 0,
          decisionStatus: InspectionDecisionStatus.CLOSED_AFTER_INSPECTION,
        },
      });
      expect(base).toBe(0);
    });

    it('INSPECTION with no report has zero commissionable labour', () => {
      expect(
        calculateCommissionBase({
          lane: BookingLane.INSPECTION,
          finalPrice: 500,
          inspectionReport: null,
        }),
      ).toBe(0);
    });

    it('returns null when finalPrice was never set', () => {
      expect(
        calculateCommissionBase({
          lane: BookingLane.STANDARD,
          finalPrice: null,
        }),
      ).toBeNull();
    });
  });

  describe('calculatePlatformFee', () => {
    it('is exactly 18% of the commission base', () => {
      expect(calculatePlatformFee(1000)).toBe(180);
      expect(PLATFORM_COMMISSION_RATE).toBe(0.18);
    });

    it('rounds to 2 decimal places', () => {
      // 100.555 * 0.18 = 18.0999 -> rounds to 18.1
      expect(calculatePlatformFee(100.555)).toBe(18.1);
    });
  });

  describe('calculateWorkerEarning', () => {
    it('is commissionBase minus platformFee', () => {
      expect(calculateWorkerEarning(1000, 180)).toBe(820);
    });

    it('never goes negative even if platformFee somehow exceeds the base', () => {
      expect(calculateWorkerEarning(100, 200)).toBe(0);
    });
  });

  describe('separate worker earnings for inspector vs. work-performing worker (Task 4)', () => {
    it('inspection fee is earned in full and is never commissioned', () => {
      const fee = 500;
      const platformFee = calculatePlatformFee(0);
      const inspectorEarning = calculateWorkerEarning(fee, platformFee);
      expect(platformFee).toBe(0);
      expect(inspectorEarning).toBe(500);
    });

    it("work-performing worker earns 18% commission on the accepted bid only, never the inspection fee or the inspector's quote", () => {
      const acceptedBid = 3000;
      const base = calculateCommissionBase({
        lane: BookingLane.INSPECTION,
        finalPrice: acceptedBid,
        inspectionReport: {
          labourCost: 7777, // inspector's quote — must never leak into this worker's earning
          decisionStatus: InspectionDecisionStatus.FIND_OTHER_USTAAD,
        },
      });
      const platformFee = calculatePlatformFee(base!);
      const workerEarning = calculateWorkerEarning(base!, platformFee);
      expect(base).toBe(acceptedBid);
      expect(platformFee).toBe(540);
      expect(workerEarning).toBe(2460);
    });
  });

  describe('settleBooking acceptance rows', () => {
    const calculate = (
      quoteParts: number,
      quoteLabour: number,
      inspectionFee: number,
      received: number,
      autoSettled = false,
    ) =>
      settleBooking({
        quoteParts,
        quoteLabour,
        inspectionFee,
        received,
        autoSettled,
      });

    it('STANDARD Rs 2,100', () => {
      expect(calculate(0, 2100, 0, 2100)).toMatchObject({
        expectedTotal: 2100,
        commission: 378,
        munafa: 1722,
      });
    });

    it('INSPECTION repair paid in full', () => {
      expect(calculate(4200, 1500, 0, 5700)).toMatchObject({
        partsPaid: 4200,
        labourPaid: 1500,
        commission: 270,
        munafa: 1230,
      });
    });

    it('INSPECTION repair short payment', () => {
      expect(calculate(4200, 1500, 0, 5000)).toMatchObject({
        partsPaid: 4200,
        labourPaid: 800,
        commission: 144,
        munafa: 656,
        shortfall: 700,
        caseTypes: ['SHORT'],
      });
    });

    it('allocates a Rs 3,000 short payment to parts before labour', () => {
      expect(calculate(2000, 1500, 0, 3000)).toMatchObject({
        partsPaid: 2000,
        labourPaid: 1000,
        commission: 180,
        munafa: 820,
        shortfall: 500,
        caseTypes: ['SHORT'],
      });
    });

    it('declined inspection fee paid', () => {
      expect(calculate(0, 0, 500, 500)).toMatchObject({
        feePaid: 500,
        commission: 0,
        munafa: 500,
      });
    });

    it('inspection fee unpaid is covered by HandyGo', () => {
      expect(calculate(0, 0, 500, 0)).toMatchObject({
        commission: 0,
        munafa: 500,
        shortfall: 500,
        handygoPays: 500,
        caseTypes: ['UNPAID_FEE'],
      });
    });

    it('partially paid inspection fee is covered by HandyGo', () => {
      expect(calculate(0, 0, 500, 200)).toMatchObject({
        feePaid: 200,
        commission: 0,
        munafa: 500,
        shortfall: 300,
        handygoPays: 300,
        caseTypes: ['UNPAID_FEE'],
      });
    });

    it('fully unpaid STANDARD labour', () => {
      expect(calculate(0, 2100, 0, 0)).toMatchObject({
        labourPaid: 0,
        commission: 0,
        munafa: 0,
        shortfall: 2100,
        caseTypes: ['UNPAID_LABOUR'],
      });
    });

    it('opens separate labour and fee cases when both debts exist', () => {
      expect(calculate(0, 2100, 500, 0)).toMatchObject({
        shortfall: 2600,
        caseTypes: ['UNPAID_LABOUR', 'UNPAID_FEE'],
      });
    });

    it('keeps a partial labour shortage and unpaid fee as separate cases', () => {
      expect(calculate(0, 2100, 500, 1000)).toMatchObject({
        shortfall: 1600,
        caseTypes: ['SHORT', 'UNPAID_FEE'],
      });
    });

    it('rejects received cash above the payable total', () => {
      expect(() => calculate(0, 2100, 0, 2101)).toThrow(
        'Received cash cannot exceed the payable total',
      );
    });

    it('BIDDING paid in full', () => {
      expect(calculate(1900, 1400, 0, 3300)).toMatchObject({
        partsPaid: 1900,
        labourPaid: 1400,
        commission: 252,
        munafa: 1148,
      });
    });

    it('BIDDING auto-settle adds its case marker without changing money', () => {
      expect(calculate(1900, 1400, 0, 3300, true)).toMatchObject({
        commission: 252,
        munafa: 1148,
        caseTypes: ['AUTO_SETTLE'],
      });
    });
  });

  describe('calculateGrossWorkerEarning', () => {
    // Worker-facing earnings (home dashboard, job detail, earning history)
    // must show the full gross amount, never the commission-deducted net.
    it('returns the full finalPrice for STANDARD, not the net amount', () => {
      const gross = calculateGrossWorkerEarning({
        lane: BookingLane.STANDARD,
        finalPrice: 1000,
      });
      expect(gross).toBe(1000);
      expect(gross).not.toBe(
        calculateWorkerEarning(1000, calculatePlatformFee(1000)),
      );
    });

    it('returns the full accepted bid amount for BIDDING', () => {
      expect(
        calculateGrossWorkerEarning({
          lane: BookingLane.BIDDING,
          finalPrice: 2500,
        }),
      ).toBe(2500);
    });

    it('excludes parts and returns only labourCost for an accepted INSPECTION repair', () => {
      expect(
        calculateGrossWorkerEarning({
          lane: BookingLane.INSPECTION,
          finalPrice: 3000,
          inspectionReport: {
            labourCost: 1800,
            decisionStatus: InspectionDecisionStatus.ACCEPTED_REPAIR,
          },
        }),
      ).toBe(1800);
    });

    it('returns the inspection fee itself when closed after inspection', () => {
      expect(
        calculateGrossWorkerEarning({
          lane: BookingLane.INSPECTION,
          finalPrice: 800,
          inspectionReport: null,
        }),
      ).toBe(800);
    });

    it('returns 0 (never null) when finalPrice was never set', () => {
      expect(
        calculateGrossWorkerEarning({
          lane: BookingLane.STANDARD,
          finalPrice: null,
        }),
      ).toBe(0);
    });
  });
});
