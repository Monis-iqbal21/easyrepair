import {
  BadRequestException,
  ForbiddenException,
  HttpException,
} from '@nestjs/common';
import {
  AvailabilityStatus,
  BookingLane,
  BookingStatus,
  WorkerOnboardingStatus,
  WorkerStatus,
} from '@prisma/client';
import { BidsService } from './bids.service';
import { WorkerUnavailableError } from '../../common/errors/worker-unavailable.error';

describe('BidsService', () => {
  let bidsRepository: any;
  let notificationsService: any;
  let chatService: any;
  let jobBroadcastService: any;
  let service: BidsService;

  /** The configured match radius all lanes now share. */
  const MATCH_RADIUS_KM = 7;

  const APPROVED_WORKER = {
    id: 'worker-1',
    firstName: 'Ali',
    lastName: 'Khan',
    status: WorkerStatus.ACTIVE,
    onboardingStatus: WorkerOnboardingStatus.APPROVED,
    profileCompleted: true,
    availabilityStatus: AvailabilityStatus.ONLINE,
    currentLat: 24.86,
    currentLng: 67.0,
    locationUpdatedAt: new Date(),
    skills: [{ categoryId: 'cat-1' }],
  };

  const BIDDING_BOOKING = {
    id: 'booking-1',
    status: BookingStatus.PENDING,
    lane: BookingLane.BIDDING,
    clientProfileId: 'client-1',
    categoryId: 'cat-1',
    latitude: 24.86,
    longitude: 67.0,
    clientProfile: { userId: 'client-user-1' },
    inspectionReport: null,
  };

  beforeEach(() => {
    bidsRepository = {
      findWorkerProfileByUserId: jest.fn().mockResolvedValue(APPROVED_WORKER),
      findBookingById: jest.fn().mockResolvedValue(BIDDING_BOOKING),
      findExistingBid: jest.fn().mockResolvedValue(null),
      createBid: jest.fn().mockResolvedValue({ id: 'bid-1' }),
      updateBidAmountAndMessage: jest
        .fn()
        .mockResolvedValue({ id: 'bid-1', amount: 999 }),
      findBidById: jest.fn(),
      updateBid: jest.fn(),
      acceptBid: jest.fn(),
    };
    notificationsService = { notify: jest.fn().mockResolvedValue(undefined) };
    chatService = {
      ensureConversationForBooking: jest.fn().mockResolvedValue(undefined),
    };
    jobBroadcastService = {
      matchRadiusKm: MATCH_RADIUS_KM,
      reconcileVisibleJobs: jest.fn(),
    };
    service = new BidsService(
      bidsRepository,
      notificationsService,
      chatService,
      jobBroadcastService,
    );
  });

  // ── #14 Normal Bidding Lane regression ──────────────────────────────────
  it('allows a bid on a normal BIDDING-lane booking (regression)', async () => {
    await expect(
      service.createBid('user-1', 'booking-1', 1500, 'hello'),
    ).resolves.toEqual({ id: 'bid-1' });
    expect(bidsRepository.createBid).toHaveBeenCalledWith({
      bookingId: 'booking-1',
      workerProfileId: 'worker-1',
      amount: 1500,
      message: 'hello',
    });
  });

  // ── #13 Standard Lane regression — no bidding allowed ───────────────────
  it('rejects a bid on a STANDARD-lane booking', async () => {
    bidsRepository.findBookingById.mockResolvedValue({
      ...BIDDING_BOOKING,
      lane: BookingLane.STANDARD,
    });
    await expect(
      service.createBid('user-1', 'booking-1', 1500),
    ).rejects.toThrow(BadRequestException);
  });

  it('rejects a bid on an ordinary (not reopened) INSPECTION booking', async () => {
    bidsRepository.findBookingById.mockResolvedValue({
      ...BIDDING_BOOKING,
      lane: BookingLane.INSPECTION,
      inspectionReport: {
        decisionStatus: 'PENDING_CLIENT_DECISION',
        workerProfileId: 'inspector-1',
      },
    });
    await expect(
      service.createBid('user-1', 'booking-1', 1500),
    ).rejects.toThrow(BadRequestException);
  });

  // ── #3 Inspecting worker excluded from bidding on their own reopened job ─
  it('rejects the original inspecting worker bidding on their own reopened job', async () => {
    bidsRepository.findBookingById.mockResolvedValue({
      ...BIDDING_BOOKING,
      lane: BookingLane.INSPECTION,
      inspectionReport: {
        decisionStatus: 'FIND_OTHER_USTAAD',
        workerProfileId: 'worker-1',
      },
    });
    await expect(
      service.createBid('user-1', 'booking-1', 1500),
    ).rejects.toThrow(ForbiddenException);
  });

  // ── #4 Offline worker cannot bid on a reopened INSPECTION job ───────────
  it('rejects an offline worker bidding on a reopened INSPECTION job', async () => {
    bidsRepository.findWorkerProfileByUserId.mockResolvedValue({
      ...APPROVED_WORKER,
      availabilityStatus: AvailabilityStatus.OFFLINE,
    });
    bidsRepository.findBookingById.mockResolvedValue({
      ...BIDDING_BOOKING,
      lane: BookingLane.INSPECTION,
      inspectionReport: {
        decisionStatus: 'FIND_OTHER_USTAAD',
        workerProfileId: 'inspector-1',
      },
    });
    await expect(
      service.createBid('user-1', 'booking-1', 1500),
    ).rejects.toThrow(ForbiddenException);
  });

  it('allows an eligible worker to bid on a reopened INSPECTION job', async () => {
    bidsRepository.findBookingById.mockResolvedValue({
      ...BIDDING_BOOKING,
      lane: BookingLane.INSPECTION,
      inspectionReport: {
        decisionStatus: 'FIND_OTHER_USTAAD',
        workerProfileId: 'inspector-1',
      },
    });
    await expect(
      service.createBid('user-1', 'booking-1', 1500),
    ).resolves.toEqual({
      id: 'bid-1',
    });
  });

  // ── #7 POST bid cooldown ─────────────────────────────────────────────────
  it('rejects a re-submit within 60 seconds of the previous update (POST cooldown)', async () => {
    bidsRepository.findExistingBid.mockResolvedValue({
      id: 'bid-1',
      updatedAt: new Date(Date.now() - 10_000), // 10s ago
      status: 'PENDING',
    });
    await expect(
      service.createBid('user-1', 'booking-1', 1600),
    ).rejects.toThrow(HttpException);
    expect(bidsRepository.updateBidAmountAndMessage).not.toHaveBeenCalled();
  });

  it('allows a re-submit once 60 seconds have elapsed', async () => {
    bidsRepository.findExistingBid.mockResolvedValue({
      id: 'bid-1',
      updatedAt: new Date(Date.now() - 61_000), // 61s ago
      status: 'PENDING',
    });
    await expect(
      service.createBid('user-1', 'booking-1', 1600),
    ).resolves.toBeDefined();
    expect(bidsRepository.updateBidAmountAndMessage).toHaveBeenCalledWith(
      'bid-1',
      1600,
      undefined,
    );
  });

  // ── #8 PATCH bid cooldown — the bypass this audit specifically closes ──
  it("rejects PATCH /bids/:id within 60 seconds of the bid's last update", async () => {
    bidsRepository.findBidById.mockResolvedValue({
      id: 'bid-1',
      editCount: 0,
      status: 'PENDING',
      updatedAt: new Date(Date.now() - 5_000), // 5s ago
      workerProfile: { id: 'worker-1' },
      booking: { id: 'booking-1', status: BookingStatus.PENDING },
    });
    await expect(service.editBid('user-1', 'bid-1', 1700)).rejects.toThrow(
      HttpException,
    );
    expect(bidsRepository.updateBid).not.toHaveBeenCalled();
  });

  it("allows PATCH /bids/:id once 60 seconds have elapsed since the bid's last update", async () => {
    bidsRepository.findBidById.mockResolvedValue({
      id: 'bid-1',
      editCount: 0,
      status: 'PENDING',
      updatedAt: new Date(Date.now() - 61_000),
      workerProfile: { id: 'worker-1' },
      booking: { id: 'booking-1', status: BookingStatus.PENDING },
    });
    bidsRepository.updateBid.mockResolvedValue({ id: 'bid-1', amount: 1700 });
    await expect(service.editBid('user-1', 'bid-1', 1700)).resolves.toEqual({
      id: 'bid-1',
      amount: 1700,
    });
  });

  // ── #9 Double-hire race — acceptBid maps a lost race to a friendly 409 ──
  it('maps a lost accept-bid race (WorkerUnavailableError) to ConflictException', async () => {
    const clientProfileRepo = {
      findClientProfileByUserId: jest
        .fn()
        .mockResolvedValue({ id: 'client-1' }),
      findBidById: jest.fn().mockResolvedValue({
        id: 'bid-1',
        status: 'PENDING',
        amount: 2000,
        workerProfile: { id: 'worker-1', userId: 'worker-user-1' },
        booking: {
          id: 'booking-1',
          status: BookingStatus.PENDING,
          clientProfileId: 'client-1',
        },
      }),
      acceptBid: jest.fn().mockRejectedValue(new WorkerUnavailableError()),
    };
    const svc = new BidsService(
      clientProfileRepo as any,
      notificationsService,
      chatService,
      jobBroadcastService,
    );
    await expect(svc.acceptBid('client-user-1', 'bid-1')).rejects.toThrow(
      'This Ustaad just got another job. Please choose another Ustaad.',
    );
  });

  // ── #11 Different worker hired via bid on a reopened INSPECTION job ────
  it('accepts a bid from a different (non-inspecting) worker on a reopened INSPECTION job and notifies/chats', async () => {
    const repo = {
      findClientProfileByUserId: jest
        .fn()
        .mockResolvedValue({ id: 'client-1' }),
      findBidById: jest.fn().mockResolvedValue({
        id: 'bid-2',
        status: 'PENDING',
        amount: 2500,
        workerProfile: { id: 'worker-2', userId: 'worker-user-2' },
        booking: {
          id: 'booking-1',
          status: BookingStatus.PENDING,
          clientProfileId: 'client-1',
        },
      }),
      acceptBid: jest.fn().mockResolvedValue({
        id: 'booking-1',
        clientProfile: { userId: 'client-user-1' },
        workerProfile: { userId: 'worker-user-2' },
      }),
    };
    const svc = new BidsService(
      repo as any,
      notificationsService,
      chatService,
      jobBroadcastService,
    );
    const result = await svc.acceptBid('client-user-1', 'bid-2');
    expect(result).toEqual({
      success: true,
      message: 'Bid accepted',
      bookingId: 'booking-1',
    });
    expect(repo.acceptBid).toHaveBeenCalledWith(
      'bid-2',
      'booking-1',
      'worker-2',
      2500,
      450,
    );
    expect(chatService.ensureConversationForBooking).toHaveBeenCalledWith(
      'client-user-1',
      'worker-user-2',
    );
  });

  // ── Hired-worker lifecycle: root cause of "hired worker still sees Bid
  // Now" was the Flutter app never refreshing its cached job-detail state
  // after acceptance — these tests pin down the exact notification the
  // client (app.dart's _refreshForEventKey) relies on to do that refresh.
  it('notifies the winning worker with a bid.accepted event routed to their job detail', async () => {
    const repo = {
      findClientProfileByUserId: jest
        .fn()
        .mockResolvedValue({ id: 'client-1' }),
      findBidById: jest.fn().mockResolvedValue({
        id: 'bid-3',
        status: 'PENDING',
        amount: 3000,
        workerProfile: { id: 'worker-3', userId: 'worker-user-3' },
        booking: {
          id: 'booking-2',
          status: BookingStatus.PENDING,
          clientProfileId: 'client-1',
        },
      }),
      acceptBid: jest.fn().mockResolvedValue({
        id: 'booking-2',
        status: BookingStatus.ACCEPTED,
        workerProfileId: 'worker-3',
        finalPrice: 3000,
        clientProfile: { userId: 'client-user-1' },
        workerProfile: { userId: 'worker-user-3' },
      }),
    };
    const svc = new BidsService(
      repo as any,
      notificationsService,
      chatService,
      jobBroadcastService,
    );

    await svc.acceptBid('client-user-1', 'bid-3');

    expect(notificationsService.notify).toHaveBeenCalledTimes(1);
    const call = notificationsService.notify.mock.calls[0][0];
    expect(call.userId).toBe('worker-user-3');
    expect(call.eventKey).toBe('bid.accepted');
    expect(call.route).toBe('/worker/job/booking-2');
    expect(call.bookingId).toBe('booking-2');
  });

  it('rejects accepting a bid on a booking that is no longer PENDING', async () => {
    const repo = {
      findClientProfileByUserId: jest
        .fn()
        .mockResolvedValue({ id: 'client-1' }),
      findBidById: jest.fn().mockResolvedValue({
        id: 'bid-4',
        status: 'PENDING',
        amount: 1800,
        workerProfile: { id: 'worker-4', userId: 'worker-user-4' },
        booking: {
          id: 'booking-3',
          status: BookingStatus.ACCEPTED,
          clientProfileId: 'client-1',
        },
      }),
      acceptBid: jest.fn(),
    };
    const svc = new BidsService(
      repo as any,
      notificationsService,
      chatService,
      jobBroadcastService,
    );

    await expect(
      svc.acceptBid('client-user-1', 'bid-4'),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(repo.acceptBid).not.toHaveBeenCalled();
  });

  // ── Linked repair booking (new "Find Other Ustaad" child) ────────────────
  describe('linked post-inspection repair booking (BIDDING child)', () => {
    const LINKED_CHILD_BOOKING = {
      ...BIDDING_BOOKING,
      id: 'child-1',
      sourceInspectionBookingId: 'booking-1',
      sourceInspectionBooking: {
        inspectionReport: {
          decisionStatus: 'FIND_OTHER_USTAAD',
          workerProfileId: 'inspector-1',
        },
      },
      workerExclusions: [],
    };

    // #10 — the original inspector may not bid on their own linked repair job.
    it('rejects the original inspector bidding on the linked child booking', async () => {
      bidsRepository.findWorkerProfileByUserId.mockResolvedValue({
        ...APPROVED_WORKER,
        id: 'inspector-1',
      });
      bidsRepository.findBookingById.mockResolvedValue(LINKED_CHILD_BOOKING);
      await expect(
        service.createBid('inspector-user-1', 'child-1', 1500),
      ).rejects.toThrow(ForbiddenException);
      expect(bidsRepository.createBid).not.toHaveBeenCalled();
    });

    it('rejects an offline worker bidding on the linked child booking', async () => {
      bidsRepository.findWorkerProfileByUserId.mockResolvedValue({
        ...APPROVED_WORKER,
        availabilityStatus: AvailabilityStatus.OFFLINE,
      });
      bidsRepository.findBookingById.mockResolvedValue(LINKED_CHILD_BOOKING);
      await expect(
        service.createBid('user-1', 'child-1', 1500),
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects a worker outside the radius bidding on the linked child booking', async () => {
      bidsRepository.findWorkerProfileByUserId.mockResolvedValue({
        ...APPROVED_WORKER,
        currentLat: 31.5204, // Lahore vs Karachi job
        currentLng: 74.3587,
      });
      bidsRepository.findBookingById.mockResolvedValue(LINKED_CHILD_BOOKING);
      await expect(
        service.createBid('user-1', 'child-1', 1500),
      ).rejects.toThrow(ForbiddenException);
    });

    it('allows an eligible nearby online worker to bid on the linked child booking', async () => {
      bidsRepository.findBookingById.mockResolvedValue(LINKED_CHILD_BOOKING);
      await expect(
        service.createBid('user-1', 'child-1', 1500),
      ).resolves.toEqual({ id: 'bid-1' });
    });

    // #16 — once hired/closed, the child stops accepting bids entirely.
    it('rejects a bid once the linked child booking is no longer PENDING', async () => {
      bidsRepository.findBookingById.mockResolvedValue({
        ...LINKED_CHILD_BOOKING,
        status: BookingStatus.ACCEPTED,
      });
      await expect(
        service.createBid('user-1', 'child-1', 1500),
      ).rejects.toThrow(BadRequestException);
    });
  });

  // ── New Jobs feed: dynamic (re-evaluated) visibility of the linked child ─
  describe('getNewJobsForWorker with a linked repair booking in the feed', () => {
    const FEED_CHILD_ROW = {
      id: 'child-1',
      title: null,
      description: 'Compressor kharab hai',
      status: BookingStatus.PENDING,
      urgency: 'NORMAL',
      timeSlot: null,
      city: 'Karachi',
      scheduledAt: null,
      createdAt: new Date(),
      inspection: false,
      lane: 'BIDDING',
      categoryId: 'cat-1',
      latitude: 24.86,
      longitude: 67.0,
      workerProfileId: null,
      workerExclusions: [],
      sourceInspectionBookingId: 'booking-1',
      sourceInspectionBooking: {
        inspectionReport: {
          decisionStatus: 'FIND_OTHER_USTAAD',
          workerProfileId: 'inspector-1',
        },
      },
      inspectionReport: null,
      standardServiceItems: [],
      category: { id: 'cat-1', name: 'AC Repair', iconUrl: null },
      clientProfile: {
        id: 'client-1',
        firstName: 'Sara',
        lastName: 'Ahmed',
        avatarUrl: null,
      },
      _count: { bids: 0 },
      bids: [],
    };

    beforeEach(() => {
      bidsRepository.findAvailableJobsForWorker = jest
        .fn()
        .mockResolvedValue([FEED_CHILD_ROW]);
    });

    // #14 — the check is live: a worker who was far away at creation time
    // sees the already-open job as soon as their fresh location is in radius.
    it('shows the open linked child to a worker whose CURRENT fresh location is inside the radius (late entry)', async () => {
      const jobs = await service.getNewJobsForWorker('user-1');
      expect(jobs).toHaveLength(1);
      expect(jobs[0].id).toBe('child-1');
      expect(jobs[0].isOpenForBidding).toBe(true);
    });

    // #15 — and hides it while the worker is outside the radius.
    it('hides the linked child from a worker outside the discovery radius', async () => {
      bidsRepository.findWorkerProfileByUserId.mockResolvedValue({
        ...APPROVED_WORKER,
        currentLat: 31.5204,
        currentLng: 74.3587,
      });
      const jobs = await service.getNewJobsForWorker('user-1');
      expect(jobs).toHaveLength(0);
    });

    it('hides the linked child from an offline worker and from one with a stale location', async () => {
      bidsRepository.findWorkerProfileByUserId.mockResolvedValue({
        ...APPROVED_WORKER,
        availabilityStatus: AvailabilityStatus.OFFLINE,
      });
      expect(await service.getNewJobsForWorker('user-1')).toHaveLength(0);

      bidsRepository.findWorkerProfileByUserId.mockResolvedValue({
        ...APPROVED_WORKER,
        locationUpdatedAt: new Date(Date.now() - 31 * 60 * 1000), // 31 min old
      });
      expect(await service.getNewJobsForWorker('user-1')).toHaveLength(0);
    });

    // #10 — the original inspector never sees their own linked repair job.
    it('hides the linked child from the original inspector', async () => {
      bidsRepository.findWorkerProfileByUserId.mockResolvedValue({
        ...APPROVED_WORKER,
        id: 'inspector-1',
      });
      const jobs = await service.getNewJobsForWorker('user-1');
      expect(jobs).toHaveLength(0);
    });

    // Direct Bidding is now radius-gated too — a live job is only visible to
    // nearby eligible Ustaads, whatever the lane. `sourceInspectionBookingId
    // == null` means "no inspector to exclude", NOT "skip matching".
    const DIRECT_BIDDING_ROW = {
      ...FEED_CHILD_ROW,
      id: 'normal-1',
      sourceInspectionBookingId: null,
      sourceInspectionBooking: null,
      inspectionReport: null,
    };

    it('shows a Direct-Bidding job (no InspectionReport) to a nearby eligible worker', async () => {
      bidsRepository.findAvailableJobsForWorker.mockResolvedValue([
        DIRECT_BIDDING_ROW,
      ]);
      const jobs = await service.getNewJobsForWorker('user-1');
      expect(jobs).toHaveLength(1);
      expect(jobs[0].id).toBe('normal-1');
      expect(jobs[0].isOpenForBidding).toBe(true);
    });

    it.each([
      [
        'outside the radius',
        { currentLat: 31.5204, currentLng: 74.3587 },
      ],
      ['offline', { availabilityStatus: AvailabilityStatus.OFFLINE }],
      [
        'stale location',
        { locationUpdatedAt: new Date(Date.now() - 31 * 60 * 1000) },
      ],
      ['busy on another job', { currentlyWorking: true }],
    ])(
      'hides a Direct-Bidding job from a worker %s (null inspector never bypasses matching)',
      async (_label, override) => {
        bidsRepository.findAvailableJobsForWorker.mockResolvedValue([
          DIRECT_BIDDING_ROW,
        ]);
        bidsRepository.findWorkerProfileByUserId.mockResolvedValue({
          ...APPROVED_WORKER,
          ...override,
        });
        expect(await service.getNewJobsForWorker('user-1')).toHaveLength(0);
      },
    );

    it('hides any job that has already been assigned', async () => {
      bidsRepository.findAvailableJobsForWorker.mockResolvedValue([
        { ...DIRECT_BIDDING_ROW, workerProfileId: 'worker-9' },
      ]);
      expect(await service.getNewJobsForWorker('user-1')).toHaveLength(0);
    });

    // STANDARD stays visible-but-direct-assign-only: never bid-actionable.
    it('keeps a nearby STANDARD job visible but never bid-actionable', async () => {
      bidsRepository.findAvailableJobsForWorker.mockResolvedValue([
        { ...DIRECT_BIDDING_ROW, id: 'standard-1', lane: 'STANDARD' },
      ]);
      const jobs = await service.getNewJobsForWorker('user-1');
      expect(jobs).toHaveLength(1);
      expect(jobs[0].isOpenForBidding).toBe(false);
    });

    // An ordinary INSPECTION job keeps its own lane action (direct-assign) —
    // it only becomes biddable after FIND_OTHER_USTAAD.
    it('keeps an ordinary INSPECTION job visible but not bid-actionable', async () => {
      bidsRepository.findAvailableJobsForWorker.mockResolvedValue([
        {
          ...DIRECT_BIDDING_ROW,
          id: 'inspection-1',
          lane: 'INSPECTION',
          inspectionReport: {
            decisionStatus: 'PENDING_CLIENT_DECISION',
            workerProfileId: 'inspector-1',
          },
        },
      ]);
      const jobs = await service.getNewJobsForWorker('user-1');
      expect(jobs).toHaveLength(1);
      expect(jobs[0].isOpenForBidding).toBe(false);
    });

    // Refreshing recovers pushes missed while the app was closed, without
    // blocking the response.
    it('kicks off a non-blocking reconciliation for the visible jobs', async () => {
      bidsRepository.findAvailableJobsForWorker.mockResolvedValue([
        DIRECT_BIDDING_ROW,
      ]);
      await service.getNewJobsForWorker('user-1');

      expect(jobBroadcastService.reconcileVisibleJobs).toHaveBeenCalledWith(
        'worker-1',
        ['normal-1'],
      );
    });
  });
});
