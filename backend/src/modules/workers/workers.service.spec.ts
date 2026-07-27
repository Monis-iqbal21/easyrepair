import { WorkersService } from './workers.service';

describe('WorkersService.updateAvailability', () => {
  let workersRepository: any;
  let notificationsService: any;
  let storageService: any;
  let agreementsService: any;
  let autoOfflineQueue: any;
  let service: WorkersService;

  const APPROVED_ONLINE_READY_PROFILE = {
    id: 'worker-1',
    onboardingStatus: 'APPROVED',
    profileCompleted: true,
    availabilityStatus: 'OFFLINE',
    skills: [{ categoryId: 'cat-1' }],
  };

  beforeEach(() => {
    workersRepository = {
      findByUserId: jest.fn().mockResolvedValue(APPROVED_ONLINE_READY_PROFILE),
      updateAvailability: jest.fn().mockResolvedValue({
        availabilityStatus: 'ONLINE',
        currentLat: 24.86,
        currentLng: 67.0,
        locationUpdatedAt: new Date(),
      }),
    };
    notificationsService = {};
    storageService = {};
    agreementsService = {};
    // Never resolves — simulates a slow/unreachable Redis. If
    // updateAvailability's response depended on this, the test below would
    // time out; it must not.
    autoOfflineQueue = {
      getJob: jest.fn().mockReturnValue(new Promise(() => {})),
      add: jest.fn().mockReturnValue(new Promise(() => {})),
    };
    service = new WorkersService(
      workersRepository,
      notificationsService,
      storageService,
      agreementsService,
      autoOfflineQueue,
    );
  });

  // ── #12 Online availability responds without waiting on background work ─
  it('resolves the ONLINE request without waiting for the auto-offline queue sync', async () => {
    const result = await Promise.race([
      service.updateAvailability('user-1', {
        status: 'ONLINE' as const,
        lat: 24.86,
        lng: 67.0,
      }),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('updateAvailability hung')), 2000),
      ),
    ]);

    expect(workersRepository.updateAvailability).toHaveBeenCalledWith(
      'worker-1',
      'ONLINE',
      24.86,
      67.0,
    );
    expect((result as any).availabilityStatus).toBe('ONLINE');
  });

  it('rejects going online without a location', async () => {
    await expect(
      service.updateAvailability('user-1', { status: 'ONLINE' as const }),
    ).rejects.toThrow('Location is required when going online');
  });

  it('still requires an approved, profile-completed worker to go online', async () => {
    workersRepository.findByUserId.mockResolvedValue({
      ...APPROVED_ONLINE_READY_PROFILE,
      onboardingStatus: 'SUBMITTED_FOR_REVIEW',
    });

    await expect(
      service.updateAvailability('user-1', {
        status: 'ONLINE' as const,
        lat: 24.86,
        lng: 67.0,
      }),
    ).rejects.toThrow('Profile approval required before receiving jobs.');
  });

  it('going offline also resolves without waiting on the auto-offline queue', async () => {
    const result = await Promise.race([
      service.updateAvailability('user-1', { status: 'OFFLINE' as const }),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('updateAvailability hung')), 2000),
      ),
    ]);
    expect(result).toBeDefined();
  });
});
