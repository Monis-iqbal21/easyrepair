import { WorkersRepository } from './workers.repository';

/**
 * Focused tests for the "exactly once" inspector stats/earnings behaviour:
 * the historical FIND_OTHER_USTAAD workaround queries must be null-safe
 * narrowed to pre-fix records only (booking reassigned away OR left
 * unassigned/null), and a rehired-inspector repair on a linked BIDDING
 * child must earn labour-only (parts are pass-through).
 */
describe('WorkersRepository.getJobStats / getEarningsHistory narrowing', () => {
  let prisma: any;
  let repo: WorkersRepository;

  beforeEach(() => {
    prisma = {
      booking: {
        count: jest.fn().mockResolvedValue(0),
        findMany: jest.fn().mockResolvedValue([]),
      },
      inspectionReport: {
        count: jest.fn().mockResolvedValue(0),
        findMany: jest.fn().mockResolvedValue([]),
      },
    };
    repo = new WorkersRepository(prisma);
  });

  it('narrows the completed-count workaround with the null-safe OR (null OR reassigned-away)', async () => {
    await repo.getJobStats('inspector-1');

    expect(prisma.inspectionReport.count).toHaveBeenCalledWith({
      where: {
        workerProfileId: 'inspector-1',
        decisionStatus: 'FIND_OTHER_USTAAD',
        booking: {
          status: 'COMPLETED',
          OR: [
            { workerProfileId: null },
            { workerProfileId: { not: 'inspector-1' } },
          ],
        },
      },
    });
  });

  it("narrows today's inspection-fee workaround the same null-safe way", async () => {
    await repo.getJobStats('inspector-1');

    const feeQuery = prisma.inspectionReport.findMany.mock.calls.find(
      (c: any[]) => c[0]?.where?.decisionStatus === 'FIND_OTHER_USTAAD',
    );
    expect(feeQuery).toBeDefined();
    expect(feeQuery[0].where.booking.OR).toEqual([
      { workerProfileId: null },
      { workerProfileId: { not: 'inspector-1' } },
    ]);
  });

  it('narrows the earnings-history workaround the same null-safe way', async () => {
    await repo.getEarningsHistory('inspector-1');

    const historyQuery = prisma.inspectionReport.findMany.mock.calls.find(
      (c: any[]) => c[0]?.where?.decisionStatus === 'FIND_OTHER_USTAAD',
    );
    expect(historyQuery).toBeDefined();
    expect(historyQuery[0].where.booking.OR).toEqual([
      { workerProfileId: null },
      { workerProfileId: { not: 'inspector-1' } },
    ]);
  });

  // #2/#3 exactly-once: a NEW-style completed inspection is counted by the
  // primary queries; the workaround (narrowed above) skips it, and the
  // inspection fee is the earning exactly once.
  it('counts a new-style completed inspection exactly once with its fee as the earning', async () => {
    // Primary completed count (computeCompletedJobs) sees the booking...
    prisma.booking.count
      .mockResolvedValueOnce(1) // completedJobsAssigned
      .mockResolvedValue(0); // activeJobs + cancellation-rate counts
    // ...while the narrowed workaround sees nothing (workerProfileId is
    // still the inspector, excluded by the OR).
    prisma.inspectionReport.count.mockResolvedValue(0);
    prisma.booking.findMany.mockImplementation(({ where }: any) =>
      Promise.resolve(
        where?.completedAt
          ? [
              {
                lane: 'INSPECTION',
                finalPrice: 500, // inspectionFeeSnapshot, untouched
                platformFee: 90,
                inspectionReport: {
                  labourCost: 3000,
                  decisionStatus: 'FIND_OTHER_USTAAD',
                },
                sourceInspectionBooking: null,
              },
            ]
          : [],
      ),
    );

    const stats = await repo.getJobStats('inspector-1');

    expect(stats.completedJobs).toBe(1);
    // Fee-based earning (finalPrice), NOT the report's labourCost — the
    // repair was never this worker's work.
    expect(stats.todayEarnings).toBe(500);
  });

  // Historical pre-fix record with an UNASSIGNED booking (workerProfileId
  // null) must still be counted by the workaround — a bare `not` filter
  // would silently drop it (SQL NULL comparison), which is exactly what the
  // null-safe OR guards against.
  it('still counts a pre-fix record whose booking has workerProfileId null', async () => {
    prisma.booking.count.mockResolvedValue(0);
    prisma.inspectionReport.count.mockResolvedValue(1);
    prisma.inspectionReport.findMany.mockImplementation(({ where }: any) =>
      Promise.resolve(
        where?.booking?.completedAt
          ? [{ booking: { inspectionFeeSnapshot: 500 } }]
          : [],
      ),
    );

    const stats = await repo.getJobStats('inspector-1');

    expect(stats.completedJobs).toBe(1);
    expect(stats.todayEarnings).toBe(500);
  });

  // #7 — rehired-inspector repair on the linked child: labour-only earning,
  // never the parts-inclusive finalPrice.
  it('uses labour-only earnings for a rehired-inspector repair on a linked BIDDING child', async () => {
    prisma.booking.count.mockResolvedValue(0);
    prisma.booking.findMany.mockImplementation(({ where }: any) =>
      Promise.resolve(
        where?.completedAt
          ? [
              {
                lane: 'BIDDING',
                finalPrice: 5000, // labour 3000 + parts 2000
                platformFee: 540,
                inspectionReport: null,
                sourceInspectionBooking: {
                  inspectionReport: {
                    labourCost: 3000,
                    workerProfileId: 'inspector-1',
                  },
                },
              },
            ]
          : [],
      ),
    );

    const stats = await repo.getJobStats('inspector-1');

    expect(stats.todayEarnings).toBe(3000);
  });

  // A DIFFERENT worker hired on the linked child earns their bid amount
  // (finalPrice) — the source report's labour belongs to the inspector only.
  it("keeps a different hired worker's earning as their own bid amount on the linked child", async () => {
    prisma.booking.count.mockResolvedValue(0);
    prisma.booking.findMany.mockImplementation(({ where }: any) =>
      Promise.resolve(
        where?.completedAt
          ? [
              {
                lane: 'BIDDING',
                finalPrice: 4200, // their accepted bid
                platformFee: 756,
                inspectionReport: null,
                sourceInspectionBooking: {
                  inspectionReport: {
                    labourCost: 3000,
                    workerProfileId: 'inspector-1', // someone else inspected
                  },
                },
              },
            ]
          : [],
      ),
    );

    const stats = await repo.getJobStats('worker-2');

    expect(stats.todayEarnings).toBe(4200);
  });

  it('applies the same labour-only rule in getEarningsHistory for the rehired inspector', async () => {
    prisma.booking.findMany.mockResolvedValue([
      {
        id: 'child-1',
        lane: 'BIDDING',
        finalPrice: 5000,
        completedAt: new Date('2026-07-30T09:00:00Z'),
        category: { name: 'AC Repair' },
        inspectionReport: null,
        sourceInspectionBooking: {
          inspectionReport: {
            labourCost: 3000,
            workerProfileId: 'inspector-1',
          },
        },
      },
    ]);

    const history = await repo.getEarningsHistory('inspector-1');

    expect(history).toHaveLength(1);
    expect(history[0].jobs[0].grossEarning).toBe(3000);
    expect(history[0].grossTotal).toBe(3000);
  });
});

/**
 * The Home dashboard's "Active Job" card and the activeJobs stat must agree
 * on what "active" means. They used to be written out separately and
 * findOngoingJob omitted ARRIVED, so an Ustaad who had tapped "Arrived"
 * disappeared from the dashboard while still showing under My Jobs.
 */
describe('WorkersRepository.findOngoingJob', () => {
  let prisma: any;
  let repo: WorkersRepository;

  beforeEach(() => {
    prisma = {
      booking: {
        findFirst: jest.fn().mockResolvedValue(null),
        count: jest.fn().mockResolvedValue(0),
        findMany: jest.fn().mockResolvedValue([]),
      },
      inspectionReport: {
        count: jest.fn().mockResolvedValue(0),
        findMany: jest.fn().mockResolvedValue([]),
      },
    };
    repo = new WorkersRepository(prisma);
  });

  it('treats every assigned-but-unfinished status as active, including ARRIVED', async () => {
    await repo.findOngoingJob('worker-1');

    const where = prisma.booking.findFirst.mock.calls[0][0].where;
    expect(where.workerProfileId).toBe('worker-1');
    expect([...where.status.in].sort()).toEqual(
      ['ACCEPTED', 'ARRIVED', 'EN_ROUTE', 'IN_PROGRESS'].sort(),
    );
  });

  it('never surfaces a finished or abandoned job', async () => {
    await repo.findOngoingJob('worker-1');

    const statuses: string[] = prisma.booking.findFirst.mock.calls[0][0].where
      .status.in;
    for (const terminal of ['COMPLETED', 'CANCELLED', 'REJECTED', 'EXPIRED', 'PENDING']) {
      expect(statuses).not.toContain(terminal);
    }
  });

  it('is lane-agnostic, so inspection and rehired assignments surface too', async () => {
    await repo.findOngoingJob('worker-1');

    const where = prisma.booking.findFirst.mock.calls[0][0].where;
    expect(where).not.toHaveProperty('lane');
    expect(where).not.toHaveProperty('sourceInspectionBookingId');
  });

  it('agrees with the activeJobs stat on the definition of active', async () => {
    await repo.findOngoingJob('worker-1');
    const dashboard: string[] = prisma.booking.findFirst.mock.calls[0][0].where
      .status.in;

    prisma.booking.count.mockClear();
    await repo.getJobStats('worker-1');
    const statCall = prisma.booking.count.mock.calls.find(
      (c: any[]) =>
        Array.isArray(c[0]?.where?.status?.in) &&
        c[0].where.status.in.includes('IN_PROGRESS') &&
        !c[0].where.status.in.includes('COMPLETED'),
    );

    expect(statCall).toBeDefined();
    expect([...statCall![0].where.status.in].sort()).toEqual(
      [...dashboard].sort(),
    );
  });
});
