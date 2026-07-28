import { BadRequestException } from '@nestjs/common';
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

/** Minimal booking shape satisfying WorkersService._toJobDto's field reads. */
function makeCancelJobFixture(status: string, workerProfileId = 'worker-1') {
  return {
    id: 'booking-1',
    workerProfileId,
    category: { name: 'Electrician' },
    title: null,
    description: 'Fix the socket',
    status,
    urgency: 'NORMAL',
    timeSlot: null,
    scheduledAt: null,
    createdAt: new Date(),
    inspection: false,
    lane: 'STANDARD',
    standardServiceItems: [],
    urgentWindow: null,
    acceptedAt: new Date(),
    enRouteAt: null,
    arrivedAt: null,
    startedAt: null,
    completedAt: null,
    cancellationReason: null,
    cancelledByRole: null,
    estimatedPrice: null,
    finalPrice: null,
    inspectionFeeSnapshot: null,
    addressLine: 'House 1',
    city: 'Karachi',
    latitude: 24.86,
    longitude: 67.0,
    clientProfile: {
      firstName: 'Ali',
      lastName: 'Khan',
      user: { phone: '+923001234567' },
    },
    attachments: [],
    statusHistory: [],
    review: null,
    inspectionReport: null,
  };
}

describe('WorkersService.cancelJob', () => {
  let workersRepository: any;
  let notificationsService: any;
  let service: WorkersService;

  beforeEach(() => {
    workersRepository = {
      findByUserId: jest.fn().mockResolvedValue({ id: 'worker-1' }),
      findJobByIdAndWorkerProfileId: jest.fn(),
      cancelJobByWorker: jest.fn(),
    };
    notificationsService = { notify: jest.fn().mockResolvedValue(undefined) };
    service = new WorkersService(
      workersRepository,
      notificationsService,
      {} as any,
      {} as any,
      {} as any,
    );
  });

  // Must match BookingEntity.canWorkerCancel in the Flutter app — ACCEPTED,
  // EN_ROUTE, or ARRIVED. A mismatch here means the Flutter UI shows a
  // Cancel button the backend then silently rejects, so the job never
  // actually reaches CANCELLED (and so never shows up in the worker's
  // Cancelled tab).
  it.each(['ACCEPTED', 'EN_ROUTE', 'ARRIVED'])(
    'allows cancelling a job with status %s',
    async (status) => {
      workersRepository.findJobByIdAndWorkerProfileId.mockResolvedValue(
        makeCancelJobFixture(status),
      );
      workersRepository.cancelJobByWorker.mockResolvedValue(
        makeCancelJobFixture('CANCELLED'),
      );

      await expect(
        service.cancelJob('user-1', 'booking-1', 'changed my mind'),
      ).resolves.toBeDefined();
      expect(workersRepository.cancelJobByWorker).toHaveBeenCalledWith(
        'booking-1',
        'worker-1',
        'changed my mind',
      );
    },
  );

  it('rejects cancelling a job that is already IN_PROGRESS', async () => {
    workersRepository.findJobByIdAndWorkerProfileId.mockResolvedValue(
      makeCancelJobFixture('IN_PROGRESS'),
    );

    await expect(
      service.cancelJob('user-1', 'booking-1'),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(workersRepository.cancelJobByWorker).not.toHaveBeenCalled();
  });

  it('notifies the client when the worker cancels', async () => {
    workersRepository.findJobByIdAndWorkerProfileId.mockResolvedValue(
      makeCancelJobFixture('ARRIVED'),
    );
    workersRepository.cancelJobByWorker.mockResolvedValue({
      ...makeCancelJobFixture('CANCELLED'),
      clientProfile: {
        ...makeCancelJobFixture('CANCELLED').clientProfile,
        userId: 'client-user-1',
      },
    });

    await service.cancelJob('user-1', 'booking-1');

    expect(notificationsService.notify).toHaveBeenCalledTimes(1);
    const call = notificationsService.notify.mock.calls[0][0];
    expect(call.userId).toBe('client-user-1');
    expect(call.eventKey).toBe('booking.cancelled.by_worker');
  });
});

describe('WorkersService.getWorkerJobById — inspection role detection', () => {
  let workersRepository: any;
  let notificationsService: any;
  let service: WorkersService;

  function makeInspectionJobFixture(overrides: Partial<any> = {}) {
    return {
      ...makeCancelJobFixture('IN_PROGRESS'),
      lane: 'INSPECTION',
      inspectionReport: null,
      ...overrides,
    };
  }

  beforeEach(() => {
    workersRepository = {
      findByUserId: jest
        .fn()
        .mockResolvedValue({ id: 'worker-1', skills: [], currentLat: null, currentLng: null }),
      findJobByIdAndWorkerProfileId: jest.fn(),
      findAvailablePendingJobById: jest.fn().mockResolvedValue(null),
      findInspectionOnlyCompletedJobById: jest.fn().mockResolvedValue(null),
    };
    notificationsService = { notify: jest.fn().mockResolvedValue(undefined) };
    service = new WorkersService(
      workersRepository,
      notificationsService,
      {} as any,
      {} as any,
      {} as any,
    );
  });

  // Root cause of "Start Inspection shown to the wrong worker": the
  // worker-facing DTO never told the caller who actually inspected, so
  // BookingEntity.isDifferentWorkerPerformingWork (which compares
  // assignedWorker.id vs inspectingWorker.id) could never detect a repair
  // worker hired after an existing report — it always fell back to the
  // original-inspector branch.
  it('the original inspector (no report submitted yet) gets no inspectingWorker — still resolves to Start Inspection client-side', async () => {
    workersRepository.findByUserId.mockResolvedValue({
      id: 'inspector-1',
      skills: [],
      currentLat: null,
      currentLng: null,
    });
    workersRepository.findJobByIdAndWorkerProfileId.mockResolvedValue(
      makeInspectionJobFixture({ workerProfileId: 'inspector-1' }),
    );

    const dto = await service.getWorkerJobById('inspector-user-1', 'booking-1');

    expect(dto.inspectingWorker).toBeNull();
  });

  it('the original inspector, once their own report exists, sees themselves as the inspector (not a different worker)', async () => {
    workersRepository.findByUserId.mockResolvedValue({
      id: 'inspector-1',
      skills: [],
      currentLat: null,
      currentLng: null,
    });
    workersRepository.findJobByIdAndWorkerProfileId.mockResolvedValue(
      makeInspectionJobFixture({
        workerProfileId: 'inspector-1',
        inspectionReport: {
          decisionStatus: 'ACCEPTED_REPAIR',
          createdAt: new Date(),
          workerProfileId: 'inspector-1',
          workerProfile: {
            id: 'inspector-1',
            firstName: 'Ali',
            lastName: 'Khan',
            avatarUrl: null,
            rating: 4.5,
            currentLat: null,
            currentLng: null,
            user: { phone: '+923001234567' },
          },
        },
      }),
    );

    const dto = await service.getWorkerJobById('inspector-user-1', 'booking-1');

    expect(dto.inspectingWorker?.id).toBe('inspector-1');
  });

  // The actual fix: a different worker hired via "Find Other Ustaad" bidding
  // now correctly receives the original inspector's id as inspectingWorker,
  // which differs from their own — this is what lets
  // BookingEntity.isDifferentWorkerPerformingWork resolve to true and show
  // On My Way → Arrived → In Progress → Completed instead of Start
  // Inspection / Submit Inspection Report.
  it('a new repair worker hired after an existing report receives the original inspector as inspectingWorker (different from themselves)', async () => {
    workersRepository.findByUserId.mockResolvedValue({
      id: 'worker-2',
      skills: [],
      currentLat: null,
      currentLng: null,
    });
    workersRepository.findJobByIdAndWorkerProfileId.mockResolvedValue(
      makeInspectionJobFixture({
        workerProfileId: 'worker-2', // repair worker now hired
        status: 'ARRIVED',
        inspectionReport: {
          decisionStatus: 'FIND_OTHER_USTAAD',
          createdAt: new Date(),
          workerProfileId: 'inspector-1',
          workerProfile: {
            id: 'inspector-1',
            firstName: 'Ali',
            lastName: 'Khan',
            avatarUrl: null,
            rating: 4.5,
            currentLat: null,
            currentLng: null,
            user: { phone: '+923001234567' },
          },
        },
      }),
    );

    const dto = await service.getWorkerJobById('worker-2-user', 'booking-1');

    expect(dto.inspectingWorker?.id).toBe('inspector-1');
    expect(dto.inspectingWorker?.id).not.toBe('worker-2');
  });

  // Privacy: a not-yet-hired bidder browsing this job (New Job detail
  // fallback) must never receive the inspector's phone/details.
  it('does not expose the inspector to a not-yet-hired bidder browsing the reopened job', async () => {
    workersRepository.findByUserId.mockResolvedValue({
      id: 'bidder-1',
      skills: [{ categoryId: 'cat-1' }],
      currentLat: 24.86,
      currentLng: 67.0,
    });
    workersRepository.findJobByIdAndWorkerProfileId.mockResolvedValue(null);
    workersRepository.findAvailablePendingJobById.mockResolvedValue(
      makeInspectionJobFixture({
        workerProfileId: null,
        status: 'PENDING',
        inspectionReport: {
          decisionStatus: 'FIND_OTHER_USTAAD',
          createdAt: new Date(),
          workerProfileId: 'inspector-1',
          workerProfile: {
            id: 'inspector-1',
            firstName: 'Ali',
            lastName: 'Khan',
            avatarUrl: null,
            rating: 4.5,
            currentLat: null,
            currentLng: null,
            user: { phone: '+923001234567' },
          },
        },
      }),
    );

    const dto = await service.getWorkerJobById('bidder-user-1', 'booking-1');

    expect(dto.inspectingWorker).toBeNull();
  });
});
