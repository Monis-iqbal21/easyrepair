import { BookingLane } from '@prisma/client';
import { BookingsService } from './bookings.service';

/** Flushes the microtask queue so a fire-and-forget notification call
 * (started via `void this._notify...(...)`, never awaited by the caller)
 * has a chance to run before assertions. */
function flushPromises(): Promise<void> {
  return new Promise((resolve) => setImmediate(resolve));
}

describe('BookingsService.submitReview', () => {
  let bookingsRepository: any;
  let storageService: any;
  let notificationsService: any;
  let chatService: any;
  let bookingsQueue: any;
  let service: BookingsService;

  const CLIENT_PROFILE = {
    id: 'client-1',
    firstName: 'Sara',
    lastName: 'Ahmed',
  };

  function makeCompletedBooking(overrides: Partial<any> = {}) {
    return {
      id: 'booking-1',
      clientProfileId: 'client-1',
      workerProfileId: 'worker-1',
      status: 'COMPLETED',
      review: null,
      category: { name: 'Plumbing' },
      title: null,
      description: 'Fix the sink',
      urgency: 'NORMAL',
      timeSlot: null,
      urgentWindow: null,
      scheduledAt: null,
      createdAt: new Date(),
      inspection: false,
      lane: 'STANDARD',
      standardServiceId: null,
      standardServiceNameSnapshot: null,
      standardServicePriceSnapshot: null,
      standardServiceItems: [],
      inspectionFeeSnapshot: null,
      estimatedPrice: 1500,
      finalPrice: 1500,
      addressLine: '123 Street',
      city: 'Karachi',
      latitude: 24.86,
      longitude: 67.0,
      acceptedAt: new Date(),
      enRouteAt: new Date(),
      arrivedAt: new Date(),
      startedAt: new Date(),
      completedAt: new Date(),
      cancellationReason: null,
      cancelledByRole: null,
      expiresAt: null,
      liveStartedAt: new Date(),
      relistedAt: null,
      workerProfile: {
        id: 'worker-1',
        userId: 'worker-user-1',
        firstName: 'Ali',
        lastName: 'Khan',
        avatarUrl: null,
        rating: 4.5,
        currentLat: null,
        currentLng: null,
        user: { phone: '+923001234567' },
      },
      inspectionReport: null,
      attachments: [],
      bids: [],
      workerExclusions: [],
      ...overrides,
    };
  }

  beforeEach(() => {
    bookingsRepository = {
      findClientProfileByUserId: jest.fn().mockResolvedValue(CLIENT_PROFILE),
      findBookingById: jest.fn().mockResolvedValue(makeCompletedBooking()),
      createReview: jest.fn().mockResolvedValue(
        makeCompletedBooking({
          review: {
            id: 'review-1',
            rating: 5,
            comment: 'Great work',
            createdAt: new Date(),
          },
        }),
      ),
    };
    storageService = {};
    notificationsService = { notify: jest.fn().mockResolvedValue(undefined) };
    chatService = {};
    bookingsQueue = { getJob: jest.fn(), add: jest.fn() };
    service = new BookingsService(
      bookingsRepository,
      storageService,
      notificationsService,
      chatService,
      bookingsQueue,
    );
  });

  // ── #11 Worker review notification uses Roman Urdu ──────────────────────
  it('notifies the worker in Roman Urdu with the client name when a review is submitted', async () => {
    await service.submitReview('client-user-1', 'booking-1', {
      rating: 5,
      comment: 'Great work',
    });

    expect(notificationsService.notify).toHaveBeenCalledTimes(1);
    const call = notificationsService.notify.mock.calls[0][0];
    expect(call.userId).toBe('worker-user-1');
    expect(call.eventKey).toBe('booking.review.created');
    expect(call.title).toBe('Aapko naya review mila hai');
    expect(call.body).toBe(
      'Sara Ahmed ne aapke kaam ka review diya hai. App mein check karein.',
    );
  });

  it('falls back to a generic label when the client has no name on file', async () => {
    bookingsRepository.findClientProfileByUserId.mockResolvedValue({
      id: 'client-1',
      firstName: '',
      lastName: '',
    });

    await service.submitReview('client-user-1', 'booking-1', {
      rating: 4,
      comment: undefined,
    });

    const call = notificationsService.notify.mock.calls[0][0];
    expect(call.body).toBe(
      'Client ne aapke kaam ka review diya hai. App mein check karein.',
    );
  });

  it('applies the same Roman Urdu wording for an INSPECTION-lane booking (all lanes)', async () => {
    bookingsRepository.findBookingById.mockResolvedValue(
      makeCompletedBooking({ lane: 'INSPECTION' }),
    );
    bookingsRepository.createReview.mockResolvedValue(
      makeCompletedBooking({
        lane: 'INSPECTION',
        review: { id: 'review-2', rating: 5, comment: undefined, createdAt: new Date() },
      }),
    );

    await service.submitReview('client-user-1', 'booking-1', {
      rating: 5,
      comment: undefined,
    });

    const call = notificationsService.notify.mock.calls[0][0];
    expect(call.title).toBe('Aapko naya review mila hai');
  });
});

describe('BookingsService.workerCancelBooking', () => {
  let bookingsRepository: any;
  let storageService: any;
  let notificationsService: any;
  let chatService: any;
  let bookingsQueue: any;
  let service: BookingsService;

  function makeAssignedBooking(status: string) {
    return {
      id: 'booking-1',
      workerProfileId: 'worker-1',
      status,
      category: { name: 'Electrician' },
      title: null,
      description: 'Fix the wiring',
      urgency: 'NORMAL',
      timeSlot: null,
      urgentWindow: null,
      scheduledAt: null,
      createdAt: new Date(),
      inspection: false,
      lane: 'STANDARD',
      standardServiceId: null,
      standardServiceNameSnapshot: null,
      standardServicePriceSnapshot: null,
      standardServiceItems: [],
      inspectionFeeSnapshot: null,
      estimatedPrice: 1500,
      finalPrice: 1500,
      addressLine: '123 Street',
      city: 'Karachi',
      latitude: 24.86,
      longitude: 67.0,
      acceptedAt: new Date(),
      enRouteAt: new Date(),
      arrivedAt: new Date(),
      startedAt: new Date(),
      completedAt: null,
      cancellationReason: null,
      cancelledByRole: null,
      expiresAt: null,
      liveStartedAt: new Date(),
      relistedAt: null,
      clientProfile: { id: 'client-1', userId: 'client-user-1' },
      workerProfile: {
        id: 'worker-1',
        userId: 'worker-user-1',
        firstName: 'Ali',
        lastName: 'Khan',
        avatarUrl: null,
        rating: 4.5,
        currentLat: null,
        currentLng: null,
        user: { phone: '+923001234567' },
      },
      inspectionReport: null,
      review: null,
      attachments: [],
      bids: [],
      workerExclusions: [],
    };
  }

  function makeCancelledBooking(reason: string) {
    return {
      ...makeAssignedBooking('CANCELLED'),
      cancellationReason: reason,
      cancelledByRole: 'WORKER',
    };
  }

  beforeEach(() => {
    bookingsRepository = {
      findWorkerProfileByUserId: jest
        .fn()
        .mockResolvedValue({ id: 'worker-1' }),
      findBookingById: jest.fn(),
      workerCancelBooking: jest.fn(),
    };
    storageService = {};
    notificationsService = { notify: jest.fn().mockResolvedValue(undefined) };
    chatService = {};
    bookingsQueue = { getJob: jest.fn(), add: jest.fn() };
    service = new BookingsService(
      bookingsRepository,
      storageService,
      notificationsService,
      chatService,
      bookingsQueue,
    );
  });

  // Must match BookingEntity.canWorkerCancel in the Flutter app exactly.
  it.each(['ACCEPTED', 'EN_ROUTE', 'ARRIVED', 'IN_PROGRESS'])(
    'allows the worker to cancel a job with status %s',
    async (status) => {
      bookingsRepository.findBookingById.mockResolvedValue(
        makeAssignedBooking(status),
      );
      bookingsRepository.workerCancelBooking.mockResolvedValue(
        makeCancelledBooking('Family emergency'),
      );

      const result = await service.workerCancelBooking(
        'worker-user-1',
        'booking-1',
        'Family emergency',
      );

      expect(bookingsRepository.workerCancelBooking).toHaveBeenCalledWith(
        'booking-1',
        'worker-1',
        'Family emergency',
      );
      expect(result.status).toBe('CANCELLED');
      expect(result.cancelledByRole).toBe('WORKER');
      expect(result.cancellationReason).toBe('Family emergency');
    },
  );

  it('rejects cancelling a job that is already COMPLETED', async () => {
    bookingsRepository.findBookingById.mockResolvedValue(
      makeAssignedBooking('COMPLETED'),
    );

    await expect(
      service.workerCancelBooking('worker-user-1', 'booking-1', 'too late'),
    ).rejects.toThrow('Cannot cancel a job with status COMPLETED.');
    expect(bookingsRepository.workerCancelBooking).not.toHaveBeenCalled();
  });

  it('notifies the client in Roman Urdu when the worker cancels an IN_PROGRESS job', async () => {
    bookingsRepository.findBookingById.mockResolvedValue(
      makeAssignedBooking('IN_PROGRESS'),
    );
    bookingsRepository.workerCancelBooking.mockResolvedValue(
      makeCancelledBooking('Vehicle broke down'),
    );

    await service.workerCancelBooking(
      'worker-user-1',
      'booking-1',
      'Vehicle broke down',
    );

    expect(notificationsService.notify).toHaveBeenCalledTimes(1);
    const call = notificationsService.notify.mock.calls[0][0];
    expect(call.userId).toBe('client-user-1');
    expect(call.eventKey).toBe('booking.cancelled.by_worker');
    expect(call.actorRole).toBe('WORKER');
    expect(call.body).toContain('Vehicle broke down');
  });
});

describe('BookingsService.reopenInspectionForBidding', () => {
  let bookingsRepository: any;
  let storageService: any;
  let notificationsService: any;
  let chatService: any;
  let bookingsQueue: any;
  let service: BookingsService;

  beforeEach(() => {
    bookingsRepository = {
      reopenForFindOtherUstaad: jest.fn().mockResolvedValue({}),
      findNearbyWorkers: jest.fn().mockResolvedValue({ workers: [] }),
      findUserIdsByWorkerProfileIds: jest.fn().mockResolvedValue(new Map()),
    };
    storageService = {};
    notificationsService = {
      wasAlreadyNotified: jest.fn().mockResolvedValue(false),
      notify: jest.fn().mockResolvedValue(undefined),
    };
    chatService = {};
    bookingsQueue = { getJob: jest.fn(), add: jest.fn() };
    service = new BookingsService(
      bookingsRepository,
      storageService,
      notificationsService,
      chatService,
      bookingsQueue,
    );
  });

  // Root cause of "Find Other Ustaad" notifications/listing not reaching
  // workers: this nearby-worker search was passing lane: INSPECTION, which
  // makes findNearbyWorkers use the tight 5→7km direct-assign radius ladder
  // instead of the wide legacy ladder (up to 20km) that
  // MAX_INSPECTION_BID_RADIUS_KM (used by New Jobs listing/bid eligibility)
  // actually matches — silently under-reaching eligible workers beyond 7km.
  it('searches for nearby workers using the wide BIDDING radius ladder, not the tight direct-assign ladder', async () => {
    await service.reopenInspectionForBidding(
      'booking-1',
      'worker-1',
      'cat-1',
      24.86,
      67.0,
    );
    await flushPromises();

    expect(bookingsRepository.findNearbyWorkers).toHaveBeenCalledWith(
      expect.objectContaining({
        categoryId: 'cat-1',
        lat: 24.86,
        lng: 67.0,
        lane: BookingLane.BIDDING,
        excludedWorkerIds: ['worker-1'],
      }),
    );
  });

  it('notifies each eligible nearby worker with the find-other-ustaad event, excluding the inspector', async () => {
    bookingsRepository.findNearbyWorkers.mockResolvedValue({
      workers: [{ id: 'worker-2' }, { id: 'worker-3' }],
    });
    bookingsRepository.findUserIdsByWorkerProfileIds.mockResolvedValue(
      new Map([
        ['worker-2', 'worker-2-user'],
        ['worker-3', 'worker-3-user'],
      ]),
    );

    await service.reopenInspectionForBidding(
      'booking-1',
      'worker-1',
      'cat-1',
      24.86,
      67.0,
    );
    await flushPromises();

    expect(bookingsRepository.findNearbyWorkers).toHaveBeenCalledWith(
      expect.objectContaining({ excludedWorkerIds: ['worker-1'] }),
    );
    expect(notificationsService.notify).toHaveBeenCalledTimes(2);
    const userIds = notificationsService.notify.mock.calls.map(
      (c: any[]) => c[0].userId,
    );
    expect(userIds).toEqual(['worker-2-user', 'worker-3-user']);
    expect(notificationsService.notify.mock.calls[0][0].eventKey).toBe(
      'booking.inspection.find_other_ustaad_available',
    );
  });

  it('does not re-notify a worker already notified for this booking/event', async () => {
    bookingsRepository.findNearbyWorkers.mockResolvedValue({
      workers: [{ id: 'worker-2' }],
    });
    bookingsRepository.findUserIdsByWorkerProfileIds.mockResolvedValue(
      new Map([['worker-2', 'worker-2-user']]),
    );
    notificationsService.wasAlreadyNotified.mockResolvedValue(true);

    await service.reopenInspectionForBidding(
      'booking-1',
      'worker-1',
      'cat-1',
      24.86,
      67.0,
    );
    await flushPromises();

    expect(notificationsService.notify).not.toHaveBeenCalled();
  });
});
