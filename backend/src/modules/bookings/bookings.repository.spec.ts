import { BookingsRepository } from './bookings.repository';

/**
 * Focused tests for the atomic "Find Other Ustaad" close-and-spawn
 * transaction — the report flip is the authoritative idempotency guard, the
 * original-booking close is itself guarded, and every non-happy path must
 * resolve without creating duplicate data.
 */
describe('BookingsRepository.closeInspectionAndOpenRepairBidding', () => {
  const NOW = new Date('2026-07-30T10:00:00Z');
  const EXPIRES = new Date('2026-08-02T10:00:00Z');

  const PARAMS = {
    reportId: 'report-1',
    originalBookingId: 'booking-1',
    inspectingWorkerProfileId: 'inspector-1',
    clientProfileId: 'client-1',
    categoryId: 'cat-1',
    title: 'AC repair',
    description: 'Compressor kharab hai',
    addressLine: '123 Street',
    city: 'Karachi',
    latitude: 24.86,
    longitude: 67.0,
    now: NOW,
    expiresAt: EXPIRES,
  };

  let tx: any;
  let prisma: any;
  let repo: BookingsRepository;

  beforeEach(() => {
    tx = {
      inspectionReport: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      booking: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        create: jest.fn().mockResolvedValue({ id: 'child-1' }),
      },
      bookingStatusHistory: { create: jest.fn().mockResolvedValue({}) },
      workerProfile: { update: jest.fn().mockResolvedValue({}) },
    };
    prisma = {
      $transaction: jest.fn(async (cb: any) => cb(tx)),
      booking: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'child-1' }),
        findUnique: jest.fn(),
      },
      inspectionReport: { findUnique: jest.fn() },
    };
    const config = { get: jest.fn().mockReturnValue(false) };
    repo = new BookingsRepository(prisma, config as any);
  });

  // #1/#2/#3/#4/#5 — the happy path writes everything exactly once, atomically.
  it('flips the report, completes the guarded original, releases the inspector, and creates ONE linked child', async () => {
    const result = await repo.closeInspectionAndOpenRepairBidding(PARAMS);

    expect(result.outcome).toBe('CREATED');
    if (result.outcome !== 'CREATED') return;
    expect(result.childBooking.id).toBe('child-1');

    // Guard is the FIRST write and is conditional on PENDING_CLIENT_DECISION.
    expect(tx.inspectionReport.updateMany).toHaveBeenCalledWith({
      where: { id: 'report-1', decisionStatus: 'PENDING_CLIENT_DECISION' },
      data: { decisionStatus: 'FIND_OTHER_USTAAD' },
    });

    // Original close is guarded on IN_PROGRESS + inspector + INSPECTION lane.
    expect(tx.booking.updateMany).toHaveBeenCalledWith({
      where: {
        id: 'booking-1',
        status: 'IN_PROGRESS',
        workerProfileId: 'inspector-1',
        lane: 'INSPECTION',
      },
      data: { status: 'COMPLETED', completedAt: NOW },
    });

    // Inspector released.
    expect(tx.workerProfile.update).toHaveBeenCalledWith({
      where: { id: 'inspector-1' },
      data: { currentlyWorking: false },
    });

    // Exactly one child created, linked back, price-free.
    expect(tx.booking.create).toHaveBeenCalledTimes(1);
    const createData = tx.booking.create.mock.calls[0][0].data;
    expect(createData).toMatchObject({
      clientProfileId: 'client-1',
      categoryId: 'cat-1',
      lane: 'BIDDING',
      status: 'PENDING',
      inspection: false,
      description: 'Compressor kharab hai',
      addressLine: '123 Street',
      city: 'Karachi',
      latitude: 24.86,
      longitude: 67.0,
      sourceInspectionBookingId: 'booking-1',
      liveStartedAt: NOW,
      expiresAt: EXPIRES,
    });
    // The inspection fee accounting stays on the original booking only.
    expect(createData).not.toHaveProperty('finalPrice');
    expect(createData).not.toHaveProperty('inspectionFeeSnapshot');

    // History rows for both sides.
    expect(tx.bookingStatusHistory.create).toHaveBeenCalledTimes(2);
  });

  // User-required edge case #2 — the close guard aborts the WHOLE transaction.
  it('rolls back everything (incl. the report flip) when the original booking is not IN_PROGRESS anymore', async () => {
    tx.booking.updateMany.mockResolvedValue({ count: 0 });

    const result = await repo.closeInspectionAndOpenRepairBidding(PARAMS);

    expect(result.outcome).toBe('BOOKING_STATE_CHANGED');
    // The sentinel escaped the transaction callback → Prisma rolls back, so
    // nothing after the failed close may have been written.
    expect(tx.booking.create).not.toHaveBeenCalled();
    expect(tx.workerProfile.update).not.toHaveBeenCalled();
    expect(tx.bookingStatusHistory.create).not.toHaveBeenCalled();
  });

  // User-required edge case #1 — count===0 re-reads the decision, never assumes.
  describe('guard lost (count === 0): re-reads decisionStatus and branches', () => {
    beforeEach(() => {
      tx.inspectionReport.updateMany.mockResolvedValue({ count: 0 });
    });

    it('FIND_OTHER_USTAAD with an existing child → ALREADY_DONE with the same child, zero new writes', async () => {
      prisma.inspectionReport.findUnique.mockResolvedValue({
        decisionStatus: 'FIND_OTHER_USTAAD',
      });
      prisma.booking.findUnique.mockResolvedValue({ id: 'child-1' });

      const result = await repo.closeInspectionAndOpenRepairBidding(PARAMS);

      expect(result).toMatchObject({
        outcome: 'ALREADY_DONE',
        childBooking: { id: 'child-1' },
      });
      expect(prisma.booking.findUnique).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { sourceInspectionBookingId: 'booking-1' },
        }),
      );
      expect(tx.booking.updateMany).not.toHaveBeenCalled();
      expect(tx.booking.create).not.toHaveBeenCalled();
      expect(tx.bookingStatusHistory.create).not.toHaveBeenCalled();
      expect(tx.workerProfile.update).not.toHaveBeenCalled();
    });

    it.each(['ACCEPTED_REPAIR', 'CLOSED_AFTER_INSPECTION'])(
      '%s → CONFLICTING_DECISION carrying the actual status',
      async (decisionStatus) => {
        prisma.inspectionReport.findUnique.mockResolvedValue({
          decisionStatus,
        });

        const result = await repo.closeInspectionAndOpenRepairBidding(PARAMS);

        expect(result).toEqual({
          outcome: 'CONFLICTING_DECISION',
          decisionStatus,
        });
        expect(tx.booking.create).not.toHaveBeenCalled();
      },
    );

    it('FIND_OTHER_USTAAD with NO linked child → LINK_MISSING, and never creates a duplicate', async () => {
      prisma.inspectionReport.findUnique.mockResolvedValue({
        decisionStatus: 'FIND_OTHER_USTAAD',
      });
      prisma.booking.findUnique.mockResolvedValue(null);

      const result = await repo.closeInspectionAndOpenRepairBidding(PARAMS);

      expect(result).toEqual({ outcome: 'LINK_MISSING' });
      expect(tx.booking.create).not.toHaveBeenCalled();
    });
  });
});
