import { AvailabilityStatus } from '@prisma/client';
import {
  AUTO_OFFLINE_JOB,
  STALE_PRESENCE_CLEANUP_JOB,
  WorkersProcessor,
} from './workers.processor';

describe('WorkersProcessor', () => {
  let workersRepository: any;
  let notificationsService: any;
  let queue: any;
  let processor: WorkersProcessor;

  beforeEach(() => {
    workersRepository = {
      findById: jest.fn(),
      setOfflineById: jest.fn().mockResolvedValue(undefined),
      findStaleOnlineWorkers: jest.fn().mockResolvedValue([]),
      setOfflineIfStillOnline: jest.fn().mockResolvedValue(true),
    };
    notificationsService = { notify: jest.fn().mockResolvedValue(undefined) };
    queue = {
      add: jest.fn().mockResolvedValue(undefined),
      getJob: jest.fn().mockResolvedValue(null),
    };
    processor = new WorkersProcessor(
      workersRepository,
      notificationsService,
      queue,
    );
  });

  describe('onModuleInit', () => {
    it('registers the stale-presence cleanup as a repeatable job', async () => {
      await processor.onModuleInit();

      expect(queue.add).toHaveBeenCalledWith(
        STALE_PRESENCE_CLEANUP_JOB,
        {},
        expect.objectContaining({
          repeat: expect.objectContaining({ every: expect.any(Number) }),
        }),
      );
    });

    it('does not throw if Redis/the queue is unreachable at boot', async () => {
      queue.add.mockRejectedValue(new Error('redis down'));

      await expect(processor.onModuleInit()).resolves.toBeUndefined();
    });
  });

  describe('handleAutoOffline (existing 7h fixed-delay timer, unchanged)', () => {
    it('sets the worker offline and notifies when still ONLINE', async () => {
      workersRepository.findById.mockResolvedValue({
        id: 'worker-1',
        userId: 'worker-user-1',
        availabilityStatus: AvailabilityStatus.ONLINE,
      });

      await processor.handleAutoOffline({
        data: { workerProfileId: 'worker-1', userId: 'worker-user-1' },
      } as any);

      expect(workersRepository.setOfflineById).toHaveBeenCalledWith(
        'worker-1',
      );
      expect(notificationsService.notify).toHaveBeenCalledTimes(1);
    });

    it('skips a worker who already went offline manually', async () => {
      workersRepository.findById.mockResolvedValue({
        id: 'worker-1',
        userId: 'worker-user-1',
        availabilityStatus: AvailabilityStatus.OFFLINE,
      });

      await processor.handleAutoOffline({
        data: { workerProfileId: 'worker-1', userId: 'worker-user-1' },
      } as any);

      expect(workersRepository.setOfflineById).not.toHaveBeenCalled();
      expect(notificationsService.notify).not.toHaveBeenCalled();
    });
  });

  describe('handleStalePresenceCleanup', () => {
    it('does nothing when there are no stale ONLINE workers', async () => {
      workersRepository.findStaleOnlineWorkers.mockResolvedValue([]);

      await processor.handleStalePresenceCleanup();

      expect(workersRepository.setOfflineIfStillOnline).not.toHaveBeenCalled();
      expect(notificationsService.notify).not.toHaveBeenCalled();
    });

    it('transitions a stale worker to OFFLINE and persists exactly one INACTIVITY notification', async () => {
      workersRepository.findStaleOnlineWorkers.mockResolvedValue([
        { id: 'worker-1', userId: 'worker-user-1' },
      ]);
      workersRepository.setOfflineIfStillOnline.mockResolvedValue(true);

      await processor.handleStalePresenceCleanup();

      expect(workersRepository.setOfflineIfStillOnline).toHaveBeenCalledWith(
        'worker-1',
      );
      expect(notificationsService.notify).toHaveBeenCalledTimes(1);
      const call = notificationsService.notify.mock.calls[0][0];
      expect(call.userId).toBe('worker-user-1');
      expect(call.eventKey).toBe('worker.availability.forced_offline');
      expect(call.payload).toEqual({ reason: 'INACTIVITY' });
    });

    it('cancels the 7h auto-offline timer for a worker it transitions', async () => {
      workersRepository.findStaleOnlineWorkers.mockResolvedValue([
        { id: 'worker-1', userId: 'worker-user-1' },
      ]);
      const pendingJob = { remove: jest.fn().mockResolvedValue(undefined) };
      queue.getJob.mockResolvedValue(pendingJob);

      await processor.handleStalePresenceCleanup();

      expect(queue.getJob).toHaveBeenCalledWith('auto-offline-worker-1');
      expect(pendingJob.remove).toHaveBeenCalled();
    });

    // Race safety: a worker who manually went offline (or was already
    // handled by a concurrent/overlapping cleanup pass) between the
    // candidate SELECT and this row's conditional UPDATE must never be
    // notified — setOfflineIfStillOnline's atomic WHERE guards this.
    it('does not notify a worker who raced this cleanup with a manual Go Offline', async () => {
      workersRepository.findStaleOnlineWorkers.mockResolvedValue([
        { id: 'worker-1', userId: 'worker-user-1' },
      ]);
      workersRepository.setOfflineIfStillOnline.mockResolvedValue(false);

      await processor.handleStalePresenceCleanup();

      expect(notificationsService.notify).not.toHaveBeenCalled();
    });

    it('notifies only the workers that actually transitioned, out of several candidates', async () => {
      workersRepository.findStaleOnlineWorkers.mockResolvedValue([
        { id: 'worker-1', userId: 'worker-user-1' },
        { id: 'worker-2', userId: 'worker-user-2' },
      ]);
      workersRepository.setOfflineIfStillOnline
        .mockResolvedValueOnce(true) // worker-1 transitions
        .mockResolvedValueOnce(false); // worker-2 raced a manual offline

      await processor.handleStalePresenceCleanup();

      expect(notificationsService.notify).toHaveBeenCalledTimes(1);
      expect(notificationsService.notify.mock.calls[0][0].userId).toBe(
        'worker-user-1',
      );
    });
  });
});
