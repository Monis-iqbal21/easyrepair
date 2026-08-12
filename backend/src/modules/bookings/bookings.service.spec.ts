import { BadRequestException, ConflictException } from '@nestjs/common';
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
  let jobBroadcastService: any;
  let jobCompletionNotifier: any;
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
    jobBroadcastService = {
      matchRadiusKm: 7,
      broadcastJob: jest.fn().mockResolvedValue(undefined),
      matchOpenJobsForWorker: jest.fn().mockResolvedValue(undefined),
      reconcileVisibleJobs: jest.fn(),
    };
    jobCompletionNotifier = {
      notifyClientJobCompleted: jest.fn().mockResolvedValue(undefined),
    };
    service = new BookingsService(
      bookingsRepository,
      storageService,
      notificationsService,
      chatService,
      bookingsQueue,
      jobBroadcastService,
      jobCompletionNotifier,
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
  let jobBroadcastService: any;
  let jobCompletionNotifier: any;
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
    jobBroadcastService = {
      matchRadiusKm: 7,
      broadcastJob: jest.fn().mockResolvedValue(undefined),
      matchOpenJobsForWorker: jest.fn().mockResolvedValue(undefined),
      reconcileVisibleJobs: jest.fn(),
    };
    jobCompletionNotifier = {
      notifyClientJobCompleted: jest.fn().mockResolvedValue(undefined),
    };
    service = new BookingsService(
      bookingsRepository,
      storageService,
      notificationsService,
      chatService,
      bookingsQueue,
      jobBroadcastService,
      jobCompletionNotifier,
    );
  });

  // Must match BookingEntity.canWorkerCancel in the Flutter app exactly —
  // ACCEPTED/EN_ROUTE/ARRIVED only, never IN_PROGRESS, for any lane.
  it.each(['ACCEPTED', 'EN_ROUTE', 'ARRIVED'])(
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

  it('rejects cancelling a job that is already IN_PROGRESS, for any lane', async () => {
    bookingsRepository.findBookingById.mockResolvedValue(
      makeAssignedBooking('IN_PROGRESS'),
    );

    await expect(
      service.workerCancelBooking('worker-user-1', 'booking-1', 'too busy'),
    ).rejects.toThrow('Cannot cancel a job with status IN_PROGRESS.');
    expect(bookingsRepository.workerCancelBooking).not.toHaveBeenCalled();
  });

  it('notifies the client in Roman Urdu when the worker cancels an ARRIVED job', async () => {
    bookingsRepository.findBookingById.mockResolvedValue(
      makeAssignedBooking('ARRIVED'),
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

describe('BookingsService.closeInspectionAndOpenRepairBidding', () => {
  let bookingsRepository: any;
  let storageService: any;
  let notificationsService: any;
  let chatService: any;
  let bookingsQueue: any;
  let jobBroadcastService: any;
  let jobCompletionNotifier: any;
  let service: BookingsService;

  const PARAMS = {
    reportId: 'report-1',
    originalBookingId: 'booking-1',
    inspectingWorkerProfileId: 'worker-1',
    clientProfileId: 'client-1',
    categoryId: 'cat-1',
    title: 'AC repair',
    description: 'Compressor kharab hai',
    addressLine: '123 Street',
    city: 'Karachi',
    latitude: 24.86,
    longitude: 67.0,
  };

  beforeEach(() => {
    bookingsRepository = {
      closeInspectionAndOpenRepairBidding: jest.fn().mockResolvedValue({
        outcome: 'CREATED',
        childBooking: { id: 'child-1' },
      }),
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
    jobBroadcastService = {
      matchRadiusKm: 7,
      broadcastJob: jest.fn().mockResolvedValue(undefined),
      matchOpenJobsForWorker: jest.fn().mockResolvedValue(undefined),
      reconcileVisibleJobs: jest.fn(),
    };
    jobCompletionNotifier = {
      notifyClientJobCompleted: jest.fn().mockResolvedValue(undefined),
    };
    service = new BookingsService(
      bookingsRepository,
      storageService,
      notificationsService,
      chatService,
      bookingsQueue,
      jobBroadcastService,
      jobCompletionNotifier,
    );
  });

  // #1/#5 — one atomic repository call closes the inspection and creates the
  // linked child; the service returns the child's id.
  it('delegates to the single atomic repository transaction and returns the linked repair booking id', async () => {
    const childId = await service.closeInspectionAndOpenRepairBidding(PARAMS);

    expect(childId).toBe('child-1');
    expect(
      bookingsRepository.closeInspectionAndOpenRepairBidding,
    ).toHaveBeenCalledTimes(1);
    expect(
      bookingsRepository.closeInspectionAndOpenRepairBidding,
    ).toHaveBeenCalledWith(
      expect.objectContaining({
        ...PARAMS,
        now: expect.any(Date),
        expiresAt: expect.any(Date),
      }),
    );
  });

  // The broadcast targets the CHILD booking and runs through the single
  // JobBroadcastService path (which owns eligibility + per-cycle dedup).
  it('broadcasts the CHILD booking to nearby workers via the shared broadcast path', async () => {
    await service.closeInspectionAndOpenRepairBidding(PARAMS);
    await flushPromises();

    expect(jobBroadcastService.broadcastJob).toHaveBeenCalledTimes(1);
    expect(jobBroadcastService.broadcastJob).toHaveBeenCalledWith('child-1');
  });

  // The completed work unit is the ORIGINAL inspection — that is what the
  // client must be prompted to review, never the child repair booking.
  it('sends the completion notice for the ORIGINAL inspection booking, not the child', async () => {
    await service.closeInspectionAndOpenRepairBidding(PARAMS);
    await flushPromises();

    expect(
      jobCompletionNotifier.notifyClientJobCompleted,
    ).toHaveBeenCalledTimes(1);
    expect(jobCompletionNotifier.notifyClientJobCompleted).toHaveBeenCalledWith(
      'booking-1',
      'INSPECTION_BEFORE_SWITCH',
      expect.objectContaining({ role: 'CLIENT' }),
    );
  });

  // #6 — idempotent replay: same id returned as a success, and delivery is
  // re-attempted (the underlying dedup makes repeats harmless).
  it('ALREADY_DONE replay returns the same child id and re-attempts delivery', async () => {
    bookingsRepository.closeInspectionAndOpenRepairBidding.mockResolvedValue({
      outcome: 'ALREADY_DONE',
      childBooking: { id: 'child-1' },
    });

    const childId = await service.closeInspectionAndOpenRepairBidding(PARAMS);
    await flushPromises();

    expect(childId).toBe('child-1');
    expect(jobBroadcastService.broadcastJob).toHaveBeenCalledWith('child-1');
    expect(jobCompletionNotifier.notifyClientJobCompleted).toHaveBeenCalledWith(
      'booking-1',
      'INSPECTION_BEFORE_SWITCH',
      expect.objectContaining({ role: 'CLIENT' }),
    );
  });

  it('rejects a genuinely different decision (CONFLICTING_DECISION) with the standard already-decided error', async () => {
    bookingsRepository.closeInspectionAndOpenRepairBidding.mockResolvedValue({
      outcome: 'CONFLICTING_DECISION',
      decisionStatus: 'ACCEPTED_REPAIR',
    });

    await expect(
      service.closeInspectionAndOpenRepairBidding(PARAMS),
    ).rejects.toThrow('This report has already been decided (ACCEPTED_REPAIR).');
    expect(jobBroadcastService.broadcastJob).not.toHaveBeenCalled();
    expect(
      jobCompletionNotifier.notifyClientJobCompleted,
    ).not.toHaveBeenCalled();
  });

  it('surfaces a controlled INSPECTION_LINK_MISSING integrity error instead of creating duplicate data', async () => {
    bookingsRepository.closeInspectionAndOpenRepairBidding.mockResolvedValue({
      outcome: 'LINK_MISSING',
    });

    await expect(
      service.closeInspectionAndOpenRepairBidding(PARAMS),
    ).rejects.toMatchObject({
      response: expect.objectContaining({ error: 'INSPECTION_LINK_MISSING' }),
    });
  });

  it('maps a rolled-back close (booking no longer IN_PROGRESS) to a conflict, with nothing notified', async () => {
    bookingsRepository.closeInspectionAndOpenRepairBidding.mockResolvedValue({
      outcome: 'BOOKING_STATE_CHANGED',
    });

    await expect(
      service.closeInspectionAndOpenRepairBidding(PARAMS),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(jobBroadcastService.broadcastJob).not.toHaveBeenCalled();
    expect(
      jobCompletionNotifier.notifyClientJobCompleted,
    ).not.toHaveBeenCalled();
  });
});

describe('BookingsService.rehireInspectingWorker (INSPECTOR_BUSY)', () => {
  let bookingsRepository: any;
  let storageService: any;
  let notificationsService: any;
  let chatService: any;
  let bookingsQueue: any;
  let jobBroadcastService: any;
  let jobCompletionNotifier: any;
  let service: BookingsService;

  function makeAssignedChildBooking() {
    return {
      id: 'child-1',
      clientProfileId: 'client-1',
      workerProfileId: 'worker-1',
      status: 'ACCEPTED',
      category: { name: 'AC Repair' },
      title: null,
      description: 'Compressor kharab hai',
      urgency: 'NORMAL',
      timeSlot: null,
      urgentWindow: null,
      scheduledAt: null,
      createdAt: new Date(),
      inspection: false,
      lane: 'BIDDING',
      standardServiceId: null,
      standardServiceNameSnapshot: null,
      standardServicePriceSnapshot: null,
      standardServiceItems: [],
      inspectionFeeSnapshot: null,
      estimatedPrice: null,
      finalPrice: 5000,
      addressLine: '123 Street',
      city: 'Karachi',
      latitude: 24.86,
      longitude: 67.0,
      acceptedAt: new Date(),
      enRouteAt: null,
      arrivedAt: null,
      startedAt: null,
      completedAt: null,
      cancellationReason: null,
      cancelledByRole: null,
      expiresAt: null,
      liveStartedAt: new Date(),
      relistedAt: null,
      sourceInspectionBookingId: 'booking-1',
      repairBooking: null,
      sourceInspectionBooking: null,
      clientProfile: { userId: 'client-user-1' },
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

  beforeEach(() => {
    bookingsRepository = {
      findWorkerProfileById: jest.fn().mockResolvedValue({
        id: 'worker-1',
        userId: 'worker-user-1',
        availabilityStatus: 'ONLINE',
        profileCompleted: true,
        currentlyWorking: false,
        status: 'ACTIVE',
        onboardingStatus: 'APPROVED',
      }),
      rehireInspectingWorker: jest
        .fn()
        .mockResolvedValue(makeAssignedChildBooking()),
    };
    storageService = {};
    notificationsService = { notify: jest.fn().mockResolvedValue(undefined) };
    chatService = {
      ensureConversationForBooking: jest.fn().mockResolvedValue(undefined),
    };
    bookingsQueue = { getJob: jest.fn(), add: jest.fn() };
    jobBroadcastService = {
      matchRadiusKm: 7,
      broadcastJob: jest.fn().mockResolvedValue(undefined),
      matchOpenJobsForWorker: jest.fn().mockResolvedValue(undefined),
      reconcileVisibleJobs: jest.fn(),
    };
    jobCompletionNotifier = {
      notifyClientJobCompleted: jest.fn().mockResolvedValue(undefined),
    };
    service = new BookingsService(
      bookingsRepository,
      storageService,
      notificationsService,
      chatService,
      bookingsQueue,
      jobBroadcastService,
      jobCompletionNotifier,
    );
  });

  // #11/#12 — busy inspector: controlled INSPECTOR_BUSY error, Roman Urdu
  // message, and NO write of any kind (booking stays open, nobody hired).
  it('returns INSPECTOR_BUSY with the Roman Urdu message and performs no hire when the inspector is currently working', async () => {
    bookingsRepository.findWorkerProfileById.mockResolvedValue({
      id: 'worker-1',
      currentlyWorking: true,
      status: 'ACTIVE',
      onboardingStatus: 'APPROVED',
      availabilityStatus: 'ONLINE',
      profileCompleted: true,
    });

    await expect(
      service.rehireInspectingWorker(
        'client-user-1',
        'child-1',
        'worker-1',
        5000,
        3000,
      ),
    ).rejects.toMatchObject({
      response: expect.objectContaining({
        error: 'INSPECTOR_BUSY',
        message:
          'Inspection karne wala Ustaad abhi doosre kaam mein masroof hai. Neeche se koi aur Ustaad choose karein.',
      }),
    });

    // Nothing was hired/closed — the bidding job and its bids are untouched,
    // so another Ustaad can still be hired afterwards (#13).
    expect(bookingsRepository.rehireInspectingWorker).not.toHaveBeenCalled();
    expect(notificationsService.notify).not.toHaveBeenCalled();
  });

  it('maps a lost atomic-guard race to the existing generic unavailable conflict (not INSPECTOR_BUSY)', async () => {
    const { WorkerUnavailableError } = jest.requireActual(
      '../../common/errors/worker-unavailable.error',
    );
    bookingsRepository.rehireInspectingWorker.mockRejectedValue(
      new WorkerUnavailableError(),
    );

    await expect(
      service.rehireInspectingWorker(
        'client-user-1',
        'child-1',
        'worker-1',
        5000,
        3000,
      ),
    ).rejects.toThrow(
      'This Ustaad is no longer available. Please choose another option.',
    );
  });

  it('rehires the available inspector onto the target booking with labour-only commission', async () => {
    const result = await service.rehireInspectingWorker(
      'client-user-1',
      'child-1',
      'worker-1',
      5000,
      3000,
    );

    // platformFee = 18% of labour (3000), never of the parts-inclusive total.
    expect(bookingsRepository.rehireInspectingWorker).toHaveBeenCalledWith(
      'child-1',
      'worker-1',
      5000,
      540,
    );
    expect(result.id).toBe('child-1');
    expect(notificationsService.notify).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'worker-user-1',
        eventKey: 'booking.assigned',
        route: '/worker/job/child-1',
      }),
    );
    expect(chatService.ensureConversationForBooking).toHaveBeenCalledWith(
      'client-user-1',
      'worker-user-1',
    );
  });
});

describe('BookingsService.reopenAfterWorkerCancellation', () => {
  let bookingsRepository: any;
  let storageService: any;
  let notificationsService: any;
  let chatService: any;
  let bookingsQueue: any;
  let jobBroadcastService: any;
  let jobCompletionNotifier: any;
  let service: BookingsService;

  function makeCancelledBooking(overrides: Partial<any> = {}) {
    return {
      id: 'booking-1',
      clientProfileId: 'client-1',
      workerProfileId: 'worker-1',
      status: 'CANCELLED',
      cancelledByRole: 'WORKER',
      cancellationReason: 'Vehicle broke down',
      lane: 'STANDARD',
      categoryId: 'cat-1',
      latitude: 24.86,
      longitude: 67.0,
      inspectionReport: null,
      ...overrides,
    };
  }

  function makeReopenedBooking(overrides: Partial<any> = {}) {
    return {
      id: 'booking-1',
      status: 'PENDING',
      workerProfileId: null,
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
      categoryId: 'cat-1',
      standardServiceId: null,
      standardServiceNameSnapshot: null,
      standardServicePriceSnapshot: null,
      standardServiceItems: [],
      inspectionFeeSnapshot: null,
      estimatedPrice: 1500,
      finalPrice: null,
      addressLine: '123 Street',
      city: 'Karachi',
      latitude: 24.86,
      longitude: 67.0,
      acceptedAt: null,
      enRouteAt: null,
      arrivedAt: null,
      startedAt: null,
      completedAt: null,
      cancellationReason: null,
      cancelledByRole: null,
      expiresAt: new Date(),
      liveStartedAt: new Date(),
      relistedAt: null,
      clientProfile: { id: 'client-1', userId: 'client-user-1' },
      workerProfile: null,
      inspectionReport: null,
      review: null,
      attachments: [],
      bids: [],
      workerExclusions: [
        {
          workerProfileId: 'worker-1',
          reason: 'Vehicle broke down',
          createdAt: new Date(),
          workerProfile: { firstName: 'Ali', lastName: 'Khan' },
        },
      ],
      ...overrides,
    };
  }

  beforeEach(() => {
    bookingsRepository = {
      findClientProfileByUserId: jest
        .fn()
        .mockResolvedValue({ id: 'client-1' }),
      findBookingById: jest.fn().mockResolvedValue(makeCancelledBooking()),
      reopenAfterWorkerCancellation: jest
        .fn()
        .mockResolvedValue(makeReopenedBooking()),
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
    jobBroadcastService = {
      matchRadiusKm: 7,
      broadcastJob: jest.fn().mockResolvedValue(undefined),
      matchOpenJobsForWorker: jest.fn().mockResolvedValue(undefined),
      reconcileVisibleJobs: jest.fn(),
    };
    jobCompletionNotifier = {
      notifyClientJobCompleted: jest.fn().mockResolvedValue(undefined),
    };
    service = new BookingsService(
      bookingsRepository,
      storageService,
      notificationsService,
      chatService,
      bookingsQueue,
      jobBroadcastService,
      jobCompletionNotifier,
    );
  });

  it('rejects reopening a booking that is not CANCELLED-by-worker', async () => {
    bookingsRepository.findBookingById.mockResolvedValue(
      makeCancelledBooking({ status: 'ACCEPTED' }),
    );
    await expect(
      service.reopenAfterWorkerCancellation('client-user-1', 'booking-1'),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(bookingsRepository.reopenAfterWorkerCancellation).not.toHaveBeenCalled();
  });

  it('rejects reopening a booking the CLIENT (not the worker) cancelled', async () => {
    bookingsRepository.findBookingById.mockResolvedValue(
      makeCancelledBooking({ cancelledByRole: 'CLIENT' }),
    );
    await expect(
      service.reopenAfterWorkerCancellation('client-user-1', 'booking-1'),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(bookingsRepository.reopenAfterWorkerCancellation).not.toHaveBeenCalled();
  });

  it('excludes the cancelling worker and reopens to PENDING', async () => {
    await service.reopenAfterWorkerCancellation('client-user-1', 'booking-1');

    expect(bookingsRepository.reopenAfterWorkerCancellation).toHaveBeenCalledWith(
      'booking-1',
      'worker-1',
      'Vehicle broke down',
      expect.any(Date),
      expect.any(Date),
    );
  });

  // Reopening resets `liveStartedAt`, which starts a NEW broadcast cycle —
  // so every lane re-broadcasts once, including workers notified during the
  // previous cycle. Per-lane conditionals are gone: one path, every lane.
  it.each([['STANDARD'], ['BIDDING'], ['INSPECTION']])(
    're-broadcasts a reopened %s booking through the shared broadcast path',
    async (lane) => {
      bookingsRepository.findBookingById.mockResolvedValue(
        makeCancelledBooking({ lane }),
      );
      bookingsRepository.reopenAfterWorkerCancellation.mockResolvedValue(
        makeReopenedBooking({ lane }),
      );

      await service.reopenAfterWorkerCancellation('client-user-1', 'booking-1');
      await flushPromises();

      expect(jobBroadcastService.broadcastJob).toHaveBeenCalledTimes(1);
      expect(jobBroadcastService.broadcastJob).toHaveBeenCalledWith('booking-1');
    },
  );

  // The cancelling worker is kept out by the exclusion row the reopen writes,
  // not by a special-case argument at the call site.
  it('relies on the booking exclusion (not a call-site argument) to keep the cancelling worker out', async () => {
    await service.reopenAfterWorkerCancellation('client-user-1', 'booking-1');
    await flushPromises();

    expect(bookingsRepository.reopenAfterWorkerCancellation).toHaveBeenCalledWith(
      'booking-1',
      'worker-1',
      'Vehicle broke down',
      expect.any(Date),
      expect.any(Date),
    );
    expect(jobBroadcastService.broadcastJob).toHaveBeenCalledWith('booking-1');
  });
});

// ── Chunk 3: launch-hardening idempotency ─────────────────────────────────
describe('BookingsService idempotency', () => {
  let bookingsRepository: any;
  let storageService: any;
  let notificationsService: any;
  let chatService: any;
  let bookingsQueue: any;
  let jobBroadcastService: any;
  let jobCompletionNotifier: any;
  let service: BookingsService;

  function makeBooking(status: string, overrides: Partial<any> = {}) {
    return {
      id: 'booking-1',
      clientProfileId: 'client-1',
      workerProfileId: overrides.workerProfileId ?? 'worker-1',
      status,
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
      enRouteAt: null,
      arrivedAt: null,
      startedAt: null,
      completedAt: null,
      cancellationReason: null,
      cancelledByRole: null,
      expiresAt: null,
      liveStartedAt: new Date(),
      relistedAt: null,
      idempotencyKey: null,
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
      ...overrides,
    };
  }

  beforeEach(() => {
    bookingsRepository = {
      findClientProfileByUserId: jest
        .fn()
        .mockResolvedValue({ id: 'client-1' }),
      findBookingByIdempotencyKey: jest.fn().mockResolvedValue(null),
      findCategoryByName: jest
        .fn()
        .mockResolvedValue({ id: 'cat-1', name: 'Plumbing', inspectionFee: 500 }),
      createBooking: jest.fn().mockResolvedValue(makeBooking('PENDING')),
      findBookingById: jest.fn(),
      findWorkerProfileById: jest.fn(),
      findWorkerProfileByUserId: jest
        .fn()
        .mockResolvedValue({ id: 'worker-1' }),
      cancelBooking: jest.fn(),
      assignWorkerToBooking: jest.fn(),
      markEnRoute: jest.fn(),
      completeBookingLifecycle: jest.fn(),
    };
    storageService = {};
    notificationsService = { notify: jest.fn().mockResolvedValue(undefined) };
    chatService = { ensureConversationForBooking: jest.fn() };
    bookingsQueue = { getJob: jest.fn(), add: jest.fn() };
    jobBroadcastService = {
      matchRadiusKm: 7,
      broadcastJob: jest.fn().mockResolvedValue(undefined),
      matchOpenJobsForWorker: jest.fn().mockResolvedValue(undefined),
      reconcileVisibleJobs: jest.fn(),
    };
    jobCompletionNotifier = {
      notifyClientJobCompleted: jest.fn().mockResolvedValue(undefined),
    };
    service = new BookingsService(
      bookingsRepository,
      storageService,
      notificationsService,
      chatService,
      bookingsQueue,
      jobBroadcastService,
      jobCompletionNotifier,
    );
  });

  const CREATE_DTO = {
    serviceCategory: 'Plumbing',
    urgency: 'NORMAL',
    timeSlot: 'MORNING',
    addressLine: '123 Street',
    city: 'Karachi',
    latitude: 24.86,
    longitude: 67.0,
  } as any;

  it('createBooking: replaying the same idempotencyKey returns the existing booking without creating a new one', async () => {
    bookingsRepository.findBookingByIdempotencyKey.mockResolvedValue(
      makeBooking('PENDING'),
    );

    const result = await service.createBooking('client-user-1', {
      ...CREATE_DTO,
      idempotencyKey: 'req-1',
    });

    expect(result.id).toBe('booking-1');
    expect(bookingsRepository.findCategoryByName).not.toHaveBeenCalled();
    expect(bookingsRepository.createBooking).not.toHaveBeenCalled();
    expect(jobBroadcastService.broadcastJob).not.toHaveBeenCalled();
  });

  it('createBooking: a different idempotencyKey creates a genuinely new booking', async () => {
    await service.createBooking('client-user-1', {
      ...CREATE_DTO,
      idempotencyKey: 'req-2',
    });

    expect(bookingsRepository.createBooking).toHaveBeenCalledWith(
      expect.objectContaining({ idempotencyKey: 'req-2' }),
    );
  });

  it('createBooking: an idempotencyKey belonging to a different client is rejected', async () => {
    bookingsRepository.findBookingByIdempotencyKey.mockResolvedValue(
      makeBooking('PENDING', { clientProfileId: 'someone-else' }),
    );

    await expect(
      service.createBooking('client-user-1', {
        ...CREATE_DTO,
        idempotencyKey: 'req-3',
      }),
    ).rejects.toThrow();
  });

  it('cancelBooking: retrying an already-cancelled booking returns success instead of a conflict error', async () => {
    bookingsRepository.findBookingById.mockResolvedValue(
      makeBooking('CANCELLED'),
    );

    const result = await service.cancelBooking(
      'client-user-1',
      'booking-1',
      'Changed my mind',
    );

    expect(result.status).toBe('CANCELLED');
    expect(bookingsRepository.cancelBooking).not.toHaveBeenCalled();
    expect(notificationsService.notify).not.toHaveBeenCalled();
  });

  it('cancelBooking: losing the race to a concurrent cancel still returns success, no duplicate notification', async () => {
    bookingsRepository.findBookingById.mockResolvedValue(
      makeBooking('PENDING'),
    );
    bookingsRepository.cancelBooking.mockResolvedValue({
      booking: makeBooking('CANCELLED'),
      changed: false,
    });

    const result = await service.cancelBooking(
      'client-user-1',
      'booking-1',
      'Changed my mind',
    );

    expect(result.status).toBe('CANCELLED');
    expect(notificationsService.notify).not.toHaveBeenCalled();
  });

  it('cancelBooking: a genuinely non-cancellable status still throws', async () => {
    bookingsRepository.findBookingById.mockResolvedValue(
      makeBooking('IN_PROGRESS'),
    );

    await expect(
      service.cancelBooking('client-user-1', 'booking-1', 'reason'),
    ).rejects.toThrow(BadRequestException);
    expect(bookingsRepository.cancelBooking).not.toHaveBeenCalled();
  });

  it('markOnMyWay: retrying after it already succeeded returns success without a duplicate notification', async () => {
    bookingsRepository.findWorkerProfileByUserId.mockResolvedValue({
      id: 'worker-1',
    });
    bookingsRepository.findBookingById.mockResolvedValue(
      makeBooking('EN_ROUTE'),
    );

    const result = await service.markOnMyWay('worker-user-1', 'booking-1');

    expect(result.status).toBe('EN_ROUTE');
    expect(bookingsRepository.markEnRoute).not.toHaveBeenCalled();
    expect(notificationsService.notify).not.toHaveBeenCalled();
  });

  it('assignWorker: retrying a hire to the same worker returns success without a second write', async () => {
    bookingsRepository.findBookingById.mockResolvedValue(
      makeBooking('ACCEPTED', { workerProfileId: 'worker-1' }),
    );

    const result = await service.assignWorker(
      'client-user-1',
      'booking-1',
      'worker-1',
    );

    expect(result.status).toBe('ACCEPTED');
    expect(bookingsRepository.assignWorkerToBooking).not.toHaveBeenCalled();
  });

  it('assignWorker: hiring a booking already assigned to a DIFFERENT worker still conflicts', async () => {
    bookingsRepository.findBookingById.mockResolvedValue(
      makeBooking('ACCEPTED', { workerProfileId: 'worker-1' }),
    );

    await expect(
      service.assignWorker('client-user-1', 'booking-1', 'worker-2'),
    ).rejects.toThrow(BadRequestException);
    expect(bookingsRepository.assignWorkerToBooking).not.toHaveBeenCalled();
  });

  it('completeJob: retrying after it already succeeded returns success without duplicate earnings/notification', async () => {
    bookingsRepository.findWorkerProfileByUserId.mockResolvedValue({
      id: 'worker-1',
    });
    bookingsRepository.findBookingById.mockResolvedValue(
      makeBooking('COMPLETED'),
    );

    const result = await service.completeJob('worker-user-1', 'booking-1');

    expect(result.status).toBe('COMPLETED');
    expect(bookingsRepository.completeBookingLifecycle).not.toHaveBeenCalled();
    expect(
      jobCompletionNotifier.notifyClientJobCompleted,
    ).not.toHaveBeenCalled();
    expect(notificationsService.notify).not.toHaveBeenCalled();
  });
});
