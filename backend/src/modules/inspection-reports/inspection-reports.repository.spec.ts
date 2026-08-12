import { InspectionReportsRepository } from './inspection-reports.repository';

/**
 * Chunk 5 commission-accounting hardening: markAcceptedAndFinalizeRepairPrice
 * is what closes the atomicity gap between the report transition and the
 * booking's finalPrice/platformFee finalize — see its doc comment for the
 * exact bug this prevents (a crash between two separate writes leaving the
 * booking permanently priced on the stale inspection fee instead of the
 * accepted labour-only repair quote).
 */
describe('InspectionReportsRepository.markAcceptedAndFinalizeRepairPrice', () => {
  let tx: any;
  let prisma: any;
  let repo: InspectionReportsRepository;

  beforeEach(() => {
    tx = {
      inspectionReport: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      booking: {
        update: jest.fn().mockResolvedValue({}),
      },
    };
    prisma = {
      $transaction: jest.fn(async (cb: any) => cb(tx)),
      inspectionReport: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          id: 'report-1',
          decisionStatus: 'ACCEPTED_REPAIR',
        }),
      },
    };
    repo = new InspectionReportsRepository(prisma);
  });

  it('flips the report AND finalizes the booking price together when the guard matches (changed: true)', async () => {
    const result = await repo.markAcceptedAndFinalizeRepairPrice(
      'report-1',
      'booking-1',
      2500,
      360,
    );

    expect(result.changed).toBe(true);
    expect(tx.inspectionReport.updateMany).toHaveBeenCalledWith({
      where: { id: 'report-1', decisionStatus: 'PENDING_CLIENT_DECISION' },
      data: { decisionStatus: 'ACCEPTED_REPAIR', acceptedAt: expect.any(Date) },
    });
    expect(tx.booking.update).toHaveBeenCalledWith({
      where: { id: 'booking-1' },
      data: { finalPrice: 2500, platformFee: 360 },
    });
  });

  it('never touches the booking price when the report guard already lost the race (changed: false)', async () => {
    tx.inspectionReport.updateMany.mockResolvedValue({ count: 0 });

    const result = await repo.markAcceptedAndFinalizeRepairPrice(
      'report-1',
      'booking-1',
      2500,
      360,
    );

    expect(result.changed).toBe(false);
    expect(tx.booking.update).not.toHaveBeenCalled();
  });

  it('both writes happen inside the same transaction — no window where one succeeds without the other', async () => {
    await repo.markAcceptedAndFinalizeRepairPrice(
      'report-1',
      'booking-1',
      2500,
      360,
    );

    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    // Both writes ran against the SAME tx handle passed into the callback.
    expect(tx.inspectionReport.updateMany).toHaveBeenCalled();
    expect(tx.booking.update).toHaveBeenCalled();
  });
});
