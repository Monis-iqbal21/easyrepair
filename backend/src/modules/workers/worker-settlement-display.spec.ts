import { BookingStatus } from '@prisma/client';
import { WorkersService } from './workers.service';

/**
 * FIX 1 — the Ustaad must see what the client ACTUALLY paid, not the number
 * the job was quoted at. Every amount below is the server's: nothing here is
 * recomputed on the device, and nothing is derived from `finalPrice`.
 */
describe('WorkersService job detail — settlement truth', () => {
  const PROFILE = { id: 'worker-1', userId: 'worker-user-1' };

  /** parts 1700 + labour 1000 = 2700 expected, 2500 received. */
  const SETTLEMENT = {
    expectedTotal: 2700,
    received: 2500,
    partsPaid: 1700,
    labourPaid: 800,
    feePaid: 0,
    commission: 144,
    munafa: 656,
    shortfall: 200,
  };

  function makeJob(overrides: Partial<any> = {}) {
    return {
      id: 'booking-1',
      workerProfileId: PROFILE.id,
      category: { name: 'AC Technician' },
      title: null,
      description: 'AC not cooling',
      status: BookingStatus.COMPLETED,
      urgency: 'NORMAL',
      timeSlot: null,
      urgentWindow: null,
      scheduledAt: null,
      createdAt: new Date(),
      inspection: true,
      lane: 'INSPECTION',
      standardServiceItems: [],
      inspectionFeeSnapshot: 500,
      estimatedPrice: null,
      finalPrice: 2700,
      addressLine: '123 Street',
      city: 'Karachi',
      latitude: 24.86,
      longitude: 67.0,
      acceptedAt: null,
      enRouteAt: null,
      arrivedAt: null,
      startedAt: null,
      completedAt: new Date(),
      cancellationReason: null,
      cancelledByRole: null,
      clientProfile: null,
      inspectionReport: null,
      sourceInspectionBooking: null,
      sourceInspectionBookingId: null,
      review: null,
      attachments: [],
      statusHistory: [],
      settlements: [SETTLEMENT],
      ...overrides,
    };
  }

  let workersRepository: any;
  let service: WorkersService;

  beforeEach(() => {
    workersRepository = {
      findByUserId: jest.fn().mockResolvedValue(PROFILE),
      findJobByIdForWorker: jest.fn(),
      findJobByIdVisibleToWorker: jest.fn(),
    };
    service = new WorkersService(
      workersRepository,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
    );
  });

  /** `_toJobDto` is private; exercise it the way the route does. */
  function toDto(job: any) {
    return (service as any)._toJobDto(job, PROFILE.id);
  }

  it('shows the received amount, the expected amount and the shortfall', () => {
    const dto = toDto(makeJob());

    expect(dto.paymentDisplayStatus).toBe('PARTIAL');
    expect(dto.receivedAmount).toBe(2500);
    expect(dto.expectedAmount).toBe(2700);
    expect(dto.remainingAmount).toBe(200);
  });

  it("passes through the server's commission and munafa untouched", () => {
    const dto = toDto(makeJob());

    expect(dto.settlementCommission).toBe(144);
    expect(dto.settlementMunafa).toBe(656);
    expect(dto.settlementPartsPaid).toBe(1700);
    expect(dto.settlementLabourPaid).toBe(800);
    expect(dto.settlementFeePaid).toBe(0);
  });

  it('never dresses the quoted price up as a received amount', () => {
    const dto = toDto(makeJob({ settlements: [] }));

    expect(dto.paymentDisplayStatus).toBe('UNPAID');
    expect(dto.receivedAmount).toBeNull();
    expect(dto.expectedAmount).toBeNull();
    expect(dto.remainingAmount).toBeNull();
    expect(dto.settlementCommission).toBeNull();
    expect(dto.settlementMunafa).toBeNull();
    // The quote is still there, just never confused with money received.
    expect(dto.finalPrice).toBe(2700);
  });

  it('reports PAID with no remainder when the client paid in full', () => {
    const dto = toDto(
      makeJob({
        settlements: [
          {
            ...SETTLEMENT,
            received: 2700,
            labourPaid: 1000,
            commission: 180,
            munafa: 820,
            shortfall: 0,
          },
        ],
      }),
    );

    expect(dto.paymentDisplayStatus).toBe('PAID');
    expect(dto.receivedAmount).toBe(2700);
    expect(dto.remainingAmount).toBe(0);
  });

  it("hides another Ustaad's money from a browsing bidder", () => {
    const dto = toDto(makeJob({ workerProfileId: 'someone-else' }));

    expect(dto.paymentDisplayStatus).toBe('UNPAID');
    expect(dto.receivedAmount).toBeNull();
    expect(dto.settlementCommission).toBeNull();
    expect(dto.settlementMunafa).toBeNull();
  });
});
