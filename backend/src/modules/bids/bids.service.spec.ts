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
  let service: BidsService;

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
    service = new BidsService(
      bidsRepository,
      notificationsService,
      chatService,
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
    const svc = new BidsService(repo as any, notificationsService, chatService);
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
    const svc = new BidsService(repo as any, notificationsService, chatService);

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
    const svc = new BidsService(repo as any, notificationsService, chatService);

    await expect(
      svc.acceptBid('client-user-1', 'bid-4'),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(repo.acceptBid).not.toHaveBeenCalled();
  });
});
