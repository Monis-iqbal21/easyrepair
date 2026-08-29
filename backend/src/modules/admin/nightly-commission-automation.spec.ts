import { AdminOperationsService } from './admin-operations.service';
import { AdminOperationsScheduler } from './admin-operations.processor';

/**
 * Issue 2: the nightly commission run must happen on its own, through the SAME
 * generator the Admin "Generate Nightly Commission" button uses — and the two
 * must be safe to run together.
 */
describe('nightly commission automation', () => {
  const karachiConfig = {
    get: jest.fn((key: string) =>
      key === 'business.timezone' ? 'Asia/Karachi' : undefined,
    ),
  } as any;

  const buildRepository = () => {
    // Stands in for the (workerProfileId, collectionDate) unique constraint +
    // the "settlement already in a PENDING/COLLECTED collection" exclusion the
    // real repository enforces under row locks.
    const collectionsByKey = new Map<string, any>();
    const claimedSettlements = new Set<string>();

    return {
      collectionsByKey,
      findCollectionsForDate: jest.fn(async (date: Date) =>
        [...collectionsByKey.values()].filter(
          (c) => c.collectionDate.getTime() === date.getTime(),
        ),
      ),
      findEligibleSettlements: jest.fn(async () =>
        [{ id: 's1', workerProfileId: 'w1', commission: 180 }].filter(
          (s) => !claimedSettlements.has(s.id),
        ),
      ),
      createNightlyCollections: jest.fn(
        async (collectionDate: Date, actorUserId: string | null, groups: any) => {
          const created: any[] = [];
          for (const [workerProfileId, items] of groups) {
            const fresh = items.filter(
              (i: any) => !claimedSettlements.has(i.settlementId),
            );
            if (fresh.length === 0) continue;
            const key = `${workerProfileId}|${collectionDate.toISOString()}`;
            if (collectionsByKey.has(key)) continue;
            fresh.forEach((i: any) => claimedSettlements.add(i.settlementId));
            const collection = {
              id: `collection-${collectionsByKey.size + 1}`,
              workerProfileId,
              collectionDate,
              automated: actorUserId === null,
              amount: fresh.reduce((sum: number, i: any) => sum + i.amount, 0),
              items: fresh,
            };
            collectionsByKey.set(key, collection);
            created.push(collection);
          }
          return created;
        },
      ),
    };
  };

  it('the scheduler invokes the existing generator as an unattended system run', async () => {
    const repository = buildRepository();
    const service = new AdminOperationsService(repository as any, karachiConfig);
    const runNightly = jest.spyOn(service, 'runNightly');

    const scheduler = new AdminOperationsScheduler(
      service,
      karachiConfig,
      jest.fn() as any,
    );
    await scheduler.generateNightlyCollections({} as any);

    // No second engine: the automatic path calls the very method the Admin
    // controller calls, with a null actor marking it as automated.
    expect(runNightly).toHaveBeenCalledWith({}, null);
    expect(repository.createNightlyCollections).toHaveBeenCalledTimes(1);
    expect(
      repository.createNightlyCollections.mock.calls[0][1],
    ).toBeNull();
  });

  it('derives the collection date from the Karachi business date', async () => {
    const repository = buildRepository();
    const service = new AdminOperationsService(repository as any, karachiConfig);

    // 2026-08-29T20:30Z is already 2026-08-30 in Karachi (UTC+5), which is the
    // business date the post-midnight run must settle under.
    jest.useFakeTimers().setSystemTime(new Date('2026-08-29T20:30:00.000Z'));
    try {
      const result = await service.runNightly({}, null);
      expect(result.collectionDate).toBe('2026-08-30');
      expect(
        (repository.createNightlyCollections.mock.calls[0][0] as Date).toISOString(),
      ).toBe('2026-08-30T00:00:00.000Z');
    } finally {
      jest.useRealTimers();
    }
  });

  it('a duplicate nightly invocation for the same date creates nothing new', async () => {
    const repository = buildRepository();
    const service = new AdminOperationsService(repository as any, karachiConfig);

    const first = await service.runNightly({ collectionDate: '2026-08-30' }, null);
    const second = await service.runNightly({ collectionDate: '2026-08-30' }, null);

    expect(first).toMatchObject({ workerCount: 1, totalAmount: 180 });
    expect(second).toMatchObject({ workerCount: 1, totalAmount: 180 });
    expect(repository.collectionsByKey.size).toBe(1);
  });

  it('the manual Admin button after an automatic run does not duplicate anything', async () => {
    const repository = buildRepository();
    const service = new AdminOperationsService(repository as any, karachiConfig);

    await service.runNightly({ collectionDate: '2026-08-30' }, null);
    // Recovery path: an admin presses "Generate Nightly Commission" anyway.
    const manual = await service.runNightly(
      { collectionDate: '2026-08-30' },
      'admin-1',
    );

    expect(manual).toMatchObject({ workerCount: 1, totalAmount: 180 });
    expect(repository.collectionsByKey.size).toBe(1);
    expect([...repository.collectionsByKey.values()][0].automated).toBe(true);
  });

  it('the manual Admin action still works on its own', async () => {
    const repository = buildRepository();
    const service = new AdminOperationsService(repository as any, karachiConfig);

    const result = await service.runNightly(
      { collectionDate: '2026-08-30' },
      'admin-1',
    );

    expect(result).toMatchObject({
      collectionDate: '2026-08-30',
      workerCount: 1,
      totalAmount: 180,
    });
    expect([...repository.collectionsByKey.values()][0].automated).toBe(false);
  });
});
