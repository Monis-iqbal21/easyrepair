import { AvailabilityStatus } from '@prisma/client';
import { WorkersService } from './workers.service';

/**
 * WorkersService.handleWorkerLogout — the authoritative server-side
 * availability cleanup called from AuthService.logout. See CASE 1/CASE 4 in
 * the presence/logout design: logout must force a Worker OFFLINE for new
 * work immediately, persist a forced-offline notification (reason=LOGOUT,
 * never pushed — the caller already cleared this device's FCM token before
 * calling this), and never touch currentlyWorking/the active booking.
 */
describe('WorkersService.handleWorkerLogout', () => {
  let workersRepository: any;
  let notificationsService: any;
  let autoOfflineQueue: any;
  let service: WorkersService;

  function makeService() {
    return new WorkersService(
      workersRepository,
      notificationsService,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      autoOfflineQueue,
      { matchRadiusKm: 7, matchOpenJobsForWorker: jest.fn() } as any,
      { notifyClientJobCompleted: jest.fn() } as any,
    );
  }

  beforeEach(() => {
    notificationsService = { notify: jest.fn().mockResolvedValue(undefined) };
    autoOfflineQueue = {
      getJob: jest.fn().mockResolvedValue(null),
      add: jest.fn().mockResolvedValue(undefined),
    };
  });

  it('is a no-op for a CLIENT userId (no WorkerProfile)', async () => {
    workersRepository = {
      findByUserId: jest.fn().mockResolvedValue(null),
      setOfflineById: jest.fn(),
    };
    service = makeService();

    await service.handleWorkerLogout('client-user-1');

    expect(workersRepository.setOfflineById).not.toHaveBeenCalled();
    expect(notificationsService.notify).not.toHaveBeenCalled();
  });

  it('force-flips an ONLINE worker to OFFLINE and persists a LOGOUT notification', async () => {
    workersRepository = {
      findByUserId: jest.fn().mockResolvedValue({
        id: 'worker-1',
        availabilityStatus: AvailabilityStatus.ONLINE,
      }),
      setOfflineById: jest.fn().mockResolvedValue(undefined),
    };
    service = makeService();

    await service.handleWorkerLogout('worker-user-1');

    expect(workersRepository.setOfflineById).toHaveBeenCalledWith('worker-1');
    expect(notificationsService.notify).toHaveBeenCalledTimes(1);
    const call = notificationsService.notify.mock.calls[0][0];
    expect(call.userId).toBe('worker-user-1');
    expect(call.eventKey).toBe('worker.availability.forced_offline');
    expect(call.payload).toEqual({ reason: 'LOGOUT' });
  });

  it('force-flips a BUSY worker to OFFLINE too (new-work exclusion) and notifies once', async () => {
    workersRepository = {
      findByUserId: jest.fn().mockResolvedValue({
        id: 'worker-1',
        availabilityStatus: AvailabilityStatus.BUSY,
      }),
      setOfflineById: jest.fn().mockResolvedValue(undefined),
    };
    service = makeService();

    await service.handleWorkerLogout('worker-user-1');

    expect(workersRepository.setOfflineById).toHaveBeenCalledWith('worker-1');
    expect(notificationsService.notify).toHaveBeenCalledTimes(1);
  });

  it('never touches currentlyWorking or the active booking', async () => {
    workersRepository = {
      findByUserId: jest.fn().mockResolvedValue({
        id: 'worker-1',
        availabilityStatus: AvailabilityStatus.BUSY,
      }),
      setOfflineById: jest.fn().mockResolvedValue(undefined),
    };
    service = makeService();

    await service.handleWorkerLogout('worker-user-1');

    // setOfflineById is the ONLY repository write this method performs —
    // there is no separate call touching currentlyWorking or the booking.
    const repoMethodsCalled = Object.keys(workersRepository).filter(
      (k) => workersRepository[k].mock?.calls?.length > 0,
    );
    expect(repoMethodsCalled).toEqual(['findByUserId', 'setOfflineById']);
  });

  it('does not create a duplicate forced-offline notification when already OFFLINE', async () => {
    workersRepository = {
      findByUserId: jest.fn().mockResolvedValue({
        id: 'worker-1',
        availabilityStatus: AvailabilityStatus.OFFLINE,
      }),
      setOfflineById: jest.fn().mockResolvedValue(undefined),
    };
    service = makeService();

    await service.handleWorkerLogout('worker-user-1');

    expect(notificationsService.notify).not.toHaveBeenCalled();
  });

  it('cancels any pending auto-offline timer on logout', async () => {
    workersRepository = {
      findByUserId: jest.fn().mockResolvedValue({
        id: 'worker-1',
        availabilityStatus: AvailabilityStatus.ONLINE,
      }),
      setOfflineById: jest.fn().mockResolvedValue(undefined),
    };
    const pendingJob = { remove: jest.fn().mockResolvedValue(undefined) };
    autoOfflineQueue.getJob.mockResolvedValue(pendingJob);
    service = makeService();

    await service.handleWorkerLogout('worker-user-1');
    await new Promise((resolve) => setImmediate(resolve));

    expect(autoOfflineQueue.getJob).toHaveBeenCalledWith('auto-offline-worker-1');
    expect(pendingJob.remove).toHaveBeenCalled();
  });
});
