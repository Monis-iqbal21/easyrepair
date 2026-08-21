import {
  AdminOperationsProcessor,
  NIGHTLY_COMMISSION_JOB,
  NIGHTLY_COMMISSION_REPEAT_JOB_ID,
} from './admin-operations.processor';

describe('AdminOperationsProcessor', () => {
  it('registers one timezone-aware nightly repeatable job', async () => {
    const queue = { add: jest.fn().mockResolvedValue({}) };
    const processor = new AdminOperationsProcessor(
      { runNightly: jest.fn() } as any,
      { get: jest.fn().mockReturnValue('Asia/Karachi') } as any,
      queue as any,
    );

    await processor.onModuleInit();

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
    const queue = { add: jest.fn().mockReturnValue(neverSettles) };
    const processor = new AdminOperationsProcessor(
      { runNightly: jest.fn() } as any,
      { get: jest.fn().mockReturnValue('Asia/Karachi') } as any,
      queue as any,
    );

    expect(processor.onModuleInit()).toBeUndefined();
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
    const processor = new AdminOperationsProcessor(
      service as any,
      { get: jest.fn() } as any,
      { add: jest.fn() } as any,
    );

    await processor.generateNightlyCollections({} as any);

    expect(service.runNightly).toHaveBeenCalledWith({}, null);
  });
});
