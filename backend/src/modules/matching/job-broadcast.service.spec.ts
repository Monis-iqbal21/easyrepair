import {
  AvailabilityStatus,
  BookingStatus,
  WorkerOnboardingStatus,
  WorkerStatus,
} from '@prisma/client';
import { JobBroadcastService } from './job-broadcast.service';

/** Flushes microtasks so fire-and-forget work runs before assertions. */
function flushPromises(): Promise<void> {
  return new Promise((resolve) => setImmediate(resolve));
}

const JOB_LAT = 24.86;
const JOB_LNG = 67.0;
const CYCLE_START = new Date('2026-07-30T10:00:00Z');

function latOffsetFor(km: number): number {
  return JOB_LAT + km / 111;
}

function makeBooking(overrides: Partial<any> = {}) {
  return {
    id: 'booking-1',
    status: BookingStatus.PENDING,
    lane: 'BIDDING',
    categoryId: 'cat-1',
    latitude: JOB_LAT,
    longitude: JOB_LNG,
    workerProfileId: null,
    liveStartedAt: CYCLE_START,
    sourceInspectionBookingId: null,
    clientProfile: { userId: 'client-user-1' },
    workerExclusions: [],
    inspectionReport: null,
    sourceInspectionBooking: null,
    ...overrides,
  };
}

function makeWorker(overrides: Partial<any> = {}) {
  return {
    id: 'worker-1',
    userId: 'worker-user-1',
    status: WorkerStatus.ACTIVE,
    onboardingStatus: WorkerOnboardingStatus.APPROVED,
    profileCompleted: true,
    availabilityStatus: AvailabilityStatus.ONLINE,
    currentlyWorking: false,
    currentLat: JOB_LAT,
    currentLng: JOB_LNG,
    locationUpdatedAt: new Date(),
    lastSeenAt: new Date(),
    skills: [{ categoryId: 'cat-1' }],
    ...overrides,
  };
}

describe('JobBroadcastService', () => {
  let matchingRepository: any;
  let notificationsService: any;
  let redisService: any;
  let config: any;
  let service: JobBroadcastService;

  beforeEach(() => {
    matchingRepository = {
      findBookingForMatching: jest.fn().mockResolvedValue(makeBooking()),
      findWorkerForMatching: jest.fn().mockResolvedValue(makeWorker()),
      findCandidateWorkers: jest.fn().mockResolvedValue([makeWorker()]),
      findOpenBookingsForCategories: jest.fn().mockResolvedValue([]),
      // Batched pre-push rechecks — default to echoing whatever the
      // single-row doubles above return, so each test can keep overriding
      // just findWorkerForMatching / findBookingForMatching.
      findWorkersForMatching: jest.fn(async (ids: string[]) => {
        const worker = await matchingRepository.findWorkerForMatching(ids[0]);
        return worker ? [worker] : [];
      }),
      findBookingsForMatching: jest.fn(async (ids: string[]) => {
        const bookings = await Promise.all(
          ids.map((id: string) =>
            matchingRepository.findBookingForMatching(id),
          ),
        );
        return bookings.filter(Boolean);
      }),
    };
    notificationsService = {
      notify: jest.fn().mockResolvedValue(undefined),
      wasAlreadyNotifiedThisCycle: jest.fn().mockResolvedValue(false),
      wasAlreadyNotified: jest.fn().mockResolvedValue(false),
      findAlreadyNotifiedThisCycle: jest.fn().mockResolvedValue(new Set()),
      findAlreadyNotifiedBookingIds: jest.fn().mockResolvedValue(new Set()),
    };
    redisService = { tryAcquire: jest.fn().mockResolvedValue(true) };
    config = {
      get: jest.fn((key: string) =>
        key === 'matching.radiusKm'
          ? 7
          : key === 'matching.locationCooldownSeconds'
            ? 60
            : undefined,
      ),
    };
    service = new JobBroadcastService(
      matchingRepository,
      notificationsService,
      redisService,
      config,
    );
  });

  // ── Per-lane Roman Urdu copy ──────────────────────────────────────────────
  describe('lane copy', () => {
    it.each([
      [
        'STANDARD',
        {},
        'booking.standard.worker_listed',
        'Naya Standard Kaam Aapke Qareeb Hai',
        'App khol kar job ki tafseel dekhein.',
      ],
      [
        'INSPECTION',
        {},
        'booking.inspection.available',
        'Nayi Inspection Job Aapke Qareeb Hai',
        'Inspection ki tafseel dekhne ke liye New Jobs kholen.',
      ],
      [
        'BIDDING',
        {},
        'booking.bidding.available',
        'Naya Bidding Kaam Aapke Qareeb Hai',
        'Apni offer bhejne ke liye New Jobs kholen.',
      ],
      [
        'BIDDING',
        { sourceInspectionBookingId: 'inspection-1' },
        'booking.inspection.find_other_ustaad_available',
        'Naya Bidding Kaam Aapke Qareeb Hai',
        'Apni offer bhejne ke liye New Jobs kholen.',
      ],
    ])(
      '%s uses the right Roman Urdu copy and event key',
      async (lane, extra, eventKey, title, body) => {
        matchingRepository.findBookingForMatching.mockResolvedValue(
          makeBooking({ lane, ...(extra as object) }),
        );

        await service.broadcastJob('booking-1');
        await flushPromises();

        expect(notificationsService.notify).toHaveBeenCalledTimes(1);
        const call = notificationsService.notify.mock.calls[0][0];
        expect(call.eventKey).toBe(eventKey);
        expect(call.title).toBe(title);
        expect(call.body).toBe(body);
        expect(call.userId).toBe('worker-user-1');
        expect(call.bookingId).toBe('booking-1');
      },
    );
  });

  // ── Hire-during-fan-out race ──────────────────────────────────────────────
  describe('race guards', () => {
    it('sends nothing once the booking has been hired mid-fan-out', async () => {
      // Candidate list was built while the job was open; by the time we get
      // to the push it has been assigned.
      matchingRepository.findBookingForMatching
        .mockResolvedValueOnce(makeBooking())
        .mockResolvedValue(makeBooking({ workerProfileId: 'someone-else' }));

      await service.broadcastJob('booking-1');
      await flushPromises();

      expect(notificationsService.notify).not.toHaveBeenCalled();
    });

    it('sends nothing once the booking is no longer PENDING', async () => {
      matchingRepository.findBookingForMatching
        .mockResolvedValueOnce(makeBooking())
        .mockResolvedValue(makeBooking({ status: BookingStatus.CANCELLED }));

      await service.broadcastJob('booking-1');
      await flushPromises();

      expect(notificationsService.notify).not.toHaveBeenCalled();
    });

    // The candidate query is only a coarse filter — the authoritative check
    // is isEligibleForJob on a FRESH read of the worker.
    it('sends nothing to a worker who moved outside 7 km during fan-out', async () => {
      matchingRepository.findCandidateWorkers.mockResolvedValue([makeWorker()]);
      matchingRepository.findWorkerForMatching.mockResolvedValue(
        makeWorker({ currentLat: latOffsetFor(25) }),
      );

      await service.broadcastJob('booking-1');
      await flushPromises();

      expect(notificationsService.notify).not.toHaveBeenCalled();
    });

    it.each([
      ['went offline', { availabilityStatus: AvailabilityStatus.OFFLINE }],
      ['got busy', { currentlyWorking: true }],
      [
        'went stale',
        { locationUpdatedAt: new Date(Date.now() - 31 * 60 * 1000) },
      ],
    ])('sends nothing to a worker who %s during fan-out', async (_l, o) => {
      matchingRepository.findWorkerForMatching.mockResolvedValue(
        makeWorker(o as object),
      );

      await service.broadcastJob('booking-1');
      await flushPromises();

      expect(notificationsService.notify).not.toHaveBeenCalled();
    });
  });

  // ── Per-live-cycle deduplication ──────────────────────────────────────────
  describe('per-live-cycle dedup', () => {
    it('checks dedup scoped to the booking’s current liveStartedAt', async () => {
      await service.broadcastJob('booking-1');
      await flushPromises();

      expect(
        notificationsService.findAlreadyNotifiedThisCycle,
      ).toHaveBeenCalledWith(
        ['worker-user-1'],
        'booking-1',
        'booking.bidding.available',
        CYCLE_START,
      );
    });

    it('does not re-notify within the same cycle (e.g. leaving and re-entering the radius)', async () => {
      notificationsService.findAlreadyNotifiedThisCycle.mockResolvedValue(
        new Set(['worker-user-1']),
      );

      await service.broadcastJob('booking-1');
      await flushPromises();

      expect(notificationsService.notify).not.toHaveBeenCalled();
    });

    // A genuine reopen/relist resets liveStartedAt, which opens a NEW cycle —
    // previously-notified eligible workers become reachable exactly once more.
    it('permits exactly one new notification after a reopen/relist resets liveStartedAt', async () => {
      const NEW_CYCLE = new Date('2026-07-31T09:00:00Z');
      matchingRepository.findBookingForMatching.mockResolvedValue(
        makeBooking({ liveStartedAt: NEW_CYCLE }),
      );
      // The ledger only has the previous cycle's row, so scoping to the new
      // cycle start reports "not yet notified".
      notificationsService.findAlreadyNotifiedThisCycle.mockImplementation(
        (userIds: string[], _b: string, _e: string, since: Date) =>
          Promise.resolve(
            since.getTime() === CYCLE_START.getTime()
              ? new Set(userIds)
              : new Set<string>(),
          ),
      );

      await service.broadcastJob('booking-1');
      await flushPromises();

      expect(notificationsService.notify).toHaveBeenCalledTimes(1);
      expect(
        notificationsService.findAlreadyNotifiedThisCycle,
      ).toHaveBeenCalledWith(
        ['worker-user-1'],
        'booking-1',
        expect.any(String),
        NEW_CYCLE,
      );
    });
  });

  // ── Inspector exclusion ───────────────────────────────────────────────────
  it('never notifies the original inspector about their own linked repair job', async () => {
    matchingRepository.findBookingForMatching.mockResolvedValue(
      makeBooking({
        lane: 'BIDDING',
        sourceInspectionBookingId: 'inspection-1',
        sourceInspectionBooking: {
          inspectionReport: {
            decisionStatus: 'FIND_OTHER_USTAAD',
            workerProfileId: 'worker-1',
          },
        },
      }),
    );

    await service.broadcastJob('booking-1');
    await flushPromises();

    expect(notificationsService.notify).not.toHaveBeenCalled();
  });

  // ── Late discovery ────────────────────────────────────────────────────────
  describe('matchOpenJobsForWorker', () => {
    beforeEach(() => {
      matchingRepository.findOpenBookingsForCategories.mockResolvedValue([
        makeBooking(),
      ]);
    });

    it('notifies a newly eligible worker about a still-open job', async () => {
      await service.matchOpenJobsForWorker('worker-1', {
        bypassCooldown: true,
      });
      await flushPromises();

      expect(notificationsService.notify).toHaveBeenCalledTimes(1);
      expect(notificationsService.notify.mock.calls[0][0].bookingId).toBe(
        'booking-1',
      );
    });

    it('bypasses the Redis cooldown for genuine state transitions', async () => {
      await service.matchOpenJobsForWorker('worker-1', {
        bypassCooldown: true,
      });
      expect(redisService.tryAcquire).not.toHaveBeenCalled();
    });

    it('applies a 60s per-worker cooldown to routine location heartbeats', async () => {
      await service.matchOpenJobsForWorker('worker-1');
      expect(redisService.tryAcquire).toHaveBeenCalledWith(
        'worker:jobmatch:worker-1',
        60,
      );
    });

    it('skips entirely when the cooldown is still held', async () => {
      redisService.tryAcquire.mockResolvedValue(false);

      await service.matchOpenJobsForWorker('worker-1');
      await flushPromises();

      expect(
        matchingRepository.findOpenBookingsForCategories,
      ).not.toHaveBeenCalled();
      expect(notificationsService.notify).not.toHaveBeenCalled();
    });

    it('still re-checks eligibility, so an out-of-radius job is not pushed', async () => {
      matchingRepository.findWorkerForMatching.mockResolvedValue(
        makeWorker({ currentLat: latOffsetFor(30) }),
      );

      await service.matchOpenJobsForWorker('worker-1', {
        bypassCooldown: true,
      });
      await flushPromises();

      expect(notificationsService.notify).not.toHaveBeenCalled();
    });

    it('never throws, so a caller can safely fire-and-forget', async () => {
      matchingRepository.findWorkerForMatching.mockRejectedValue(
        new Error('db down'),
      );
      await expect(
        service.matchOpenJobsForWorker('worker-1', { bypassCooldown: true }),
      ).resolves.toBeUndefined();
    });
  });

  // ── New Jobs refresh reconciliation ───────────────────────────────────────
  describe('reconcileVisibleJobs', () => {
    it('notifies once for a job the worker can see but was never pushed', async () => {
      service.reconcileVisibleJobs('worker-1', ['booking-1']);
      await flushPromises();
      await flushPromises();

      expect(notificationsService.notify).toHaveBeenCalledTimes(1);
    });

    it('stays silent on repeated refreshes within the same cycle', async () => {
      notificationsService.findAlreadyNotifiedBookingIds.mockResolvedValue(
        new Set(['booking-1']),
      );

      service.reconcileVisibleJobs('worker-1', ['booking-1']);
      await flushPromises();
      await flushPromises();

      expect(notificationsService.notify).not.toHaveBeenCalled();
    });

    it('returns immediately (non-blocking) and does nothing for an empty list', () => {
      expect(service.reconcileVisibleJobs('worker-1', [])).toBeUndefined();
      expect(matchingRepository.findBookingForMatching).not.toHaveBeenCalled();
    });
  });

  it('exposes the configured match radius so consumers share one source of truth', () => {
    expect(service.matchRadiusKm).toBe(7);
  });
});
