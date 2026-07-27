import { BookingsService } from './bookings.service';

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
