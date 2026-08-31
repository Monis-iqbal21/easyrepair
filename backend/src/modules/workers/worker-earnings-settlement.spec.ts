import { WorkersRepository } from './workers.repository';

/**
 * FIX 1, second half — Earning History used to split the QUOTE 82/18 even
 * when the settlement recorded that less cash arrived, so the Ustaad was
 * shown an earning larger than the money they were handed. Once a settlement
 * exists it is the answer; nothing is recomputed here.
 */
describe('WorkersRepository.getEarningsHistory — settlement wins over the quote', () => {
  let prisma: any;
  let repo: WorkersRepository;

  beforeEach(() => {
    prisma = {
      booking: { findMany: jest.fn().mockResolvedValue([]) },
      inspectionReport: { findMany: jest.fn().mockResolvedValue([]) },
    };
    repo = new WorkersRepository(prisma);
  });

  function completedJob(overrides: Partial<any> = {}) {
    return {
      id: 'job-A',
      lane: 'BIDDING',
      finalPrice: 2700,
      completedAt: new Date('2026-08-30T10:00:00Z'),
      commissionStatus: 'PENDING',
      category: { name: 'AC Technician' },
      inspectionReport: null,
      sourceInspectionBooking: null,
      settlements: [],
      ...overrides,
    };
  }

  it('asks the database for the one current settlement per job', async () => {
    await repo.getEarningsHistory('worker-1');

    const call = prisma.booking.findMany.mock.calls[0][0];
    expect(call.select.settlements).toEqual(
      expect.objectContaining({
        where: { isCurrent: true },
        take: 1,
      }),
    );
  });

  it('reports the settlement commission and munafa, not the quote split', async () => {
    prisma.booking.findMany.mockResolvedValue([
      completedJob({
        settlements: [
          {
            received: 2500,
            commission: 144,
            munafa: 656,
            shortfall: 200,
          },
        ],
      }),
    ]);

    const job = (await repo.getEarningsHistory('worker-1'))[0].jobs[0];

    // 18% of the 2700 QUOTE would have been 486 / 2214 — the old, wrong pair.
    expect(job.commissionAmount).toBe(144);
    expect(job.ustaadEarning).toBe(656);
    expect(job.receivedAmount).toBe(2500);
    expect(job.shortfall).toBe(200);
    // The quote stays visible so the Ustaad can see both sides of the gap.
    expect(job.grossEarning).toBe(2700);
  });

  it('falls back to the quote split while a job is still unsettled', async () => {
    prisma.booking.findMany.mockResolvedValue([completedJob()]);

    const job = (await repo.getEarningsHistory('worker-1'))[0].jobs[0];

    expect(job.commissionAmount).toBe(486);
    expect(job.ustaadEarning).toBe(2214);
    // Null, never 0 — "not settled yet" is not the same as "nothing owed".
    expect(job.receivedAmount).toBeNull();
    expect(job.shortfall).toBeNull();
  });

  it('applies the same rule to an inspection-fee-only job', async () => {
    prisma.inspectionReport.findMany.mockResolvedValue([
      {
        booking: {
          id: 'inspection-1',
          completedAt: new Date('2026-08-30T09:00:00Z'),
          inspectionFeeSnapshot: 500,
          commissionStatus: 'PENDING',
          category: { name: 'Electrician' },
          settlements: [
            { received: 0, commission: 0, munafa: 500, shortfall: 500 },
          ],
        },
      },
    ]);

    const job = (await repo.getEarningsHistory('inspector-1'))[0].jobs[0];

    expect(job.grossEarning).toBe(500);
    expect(job.receivedAmount).toBe(0);
    expect(job.shortfall).toBe(500);
    // HandyGo covers an unpaid inspection fee — munafa stays whole.
    expect(job.ustaadEarning).toBe(500);
    expect(job.commissionAmount).toBe(0);
  });
});
