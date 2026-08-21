import {
  AdminOperationsScheduler,
  NIGHTLY_COMMISSION_JOB,
  NIGHTLY_COMMISSION_REPEAT_JOB_ID,
} from './admin-operations.processor';

describe('AdminOperationsScheduler', () => {
  const makeQueue = (add: jest.Mock) => ({
    add,
    on: jest.fn(),
    process: jest.fn().mockResolvedValue(undefined),
    close: jest.fn().mockResolvedValue(undefined),
  });

  it('registers one timezone-aware nightly repeatable job', async () => {
    const queue = makeQueue(jest.fn().mockResolvedValue({}));
    const scheduler = new AdminOperationsScheduler(
      { runNightly: jest.fn() } as any,
      {
        get: jest.fn((key: string) =>
          key === 'redis.url' ? 'redis://example.invalid:6379' : 'Asia/Karachi',
        ),
      } as any,
      jest.fn().mockReturnValue(queue) as any,
    );

    scheduler.start();
    await Promise.resolve();

    expect(queue.add).toHaveBeenCalledWith(
      NIGHTLY_COMMISSION_JOB,
      {},
      expect.objectContaining({
        jobId: NIGHTLY_COMMISSION_REPEAT_JOB_ID,
        repeat: { cron: '0 0 * * *', tz: 'Asia/Karachi' },
      }),
    );
  });

  it('does not block module initialization while Redis registration is pending', () => {
    const neverSettles = new Promise(() => undefined);
    const queue = makeQueue(jest.fn().mockReturnValue(neverSettles));
    const scheduler = new AdminOperationsScheduler(
      { runNightly: jest.fn() } as any,
      { get: jest.fn().mockReturnValue('redis://example.invalid:6379') } as any,
      jest.fn().mockReturnValue(queue) as any,
    );

    expect(scheduler.start()).toBeUndefined();
    expect(queue.add).toHaveBeenCalledTimes(1);
  });

  it('does not create a Bull queue during Nest provider initialization', () => {
    const createQueue = jest.fn();

    new AdminOperationsScheduler(
      { runNightly: jest.fn() } as any,
      { get: jest.fn() } as any,
      createQueue,
    );

    expect(createQueue).not.toHaveBeenCalled();
  });

  it('starts and registers the deterministic scheduler only once', () => {
    const queue = makeQueue(jest.fn().mockResolvedValue({}));
    const createQueue = jest.fn().mockReturnValue(queue);
    const scheduler = new AdminOperationsScheduler(
      { runNightly: jest.fn() } as any,
      { get: jest.fn().mockReturnValue('redis://example.invalid:6379') } as any,
      createQueue,
    );

    scheduler.start();
    scheduler.start();

    expect(createQueue).toHaveBeenCalledTimes(1);
    expect(queue.add).toHaveBeenCalledTimes(1);
  });

  it('runs generation as an audited system action', async () => {
    const service = {
      runNightly: jest.fn().mockResolvedValue({
        collectionDate: '2026-08-21',
        workerCount: 1,
        totalAmount: 180,
      }),
    };
    const scheduler = new AdminOperationsScheduler(
      service as any,
      { get: jest.fn() } as any,
      jest.fn() as any,
    );

    await scheduler.generateNightlyCollections({} as any);

    expect(service.runNightly).toHaveBeenCalledWith({}, null);
  });
});
