import {
  AvailabilityStatus,
  BookingStatus,
  WorkerOnboardingStatus,
  WorkerStatus,
} from '@prisma/client';
import { MatchingRepository } from './matching.repository';
import { JobBroadcastService } from './job-broadcast.service';
import {
  JOB_DISCOVERY_WINDOW_MS,
  LOCATION_FRESHNESS_MS,
  WORKER_PRESENCE_STALE_MS,
} from '../../common/utils/job-eligibility.util';
import { boundingBoxKm } from '../../common/utils/geo.util';

/**
 * LARGE-SCALE MATCHING PERFORMANCE.
 *
 * These tests are deliberately about QUERY SHAPE, not about re-testing the
 * eligibility rules themselves (job-eligibility.util.spec.ts owns those). The
 * optimization's whole premise is that Node must stop receiving Workers/jobs
 * it is only going to throw away, so what needs guarding is:
 *
 *   1. every eligibility predicate that CAN be expressed in SQL still IS, and
 *   2. the predicates that must NOT be pushed down (marketplace browsing) are
 *      still absent, and
 *   3. the fan-out no longer issues one query per recipient, while still
 *      re-reading both sides before every push.
 */

const JOB_LAT = 24.8607;
const JOB_LNG = 67.0011;
const RADIUS_KM = 7;
const CYCLE_START = new Date('2026-08-01T10:00:00Z');

function flushPromises(): Promise<void> {
  return new Promise((resolve) => setImmediate(resolve));
}

function makeBooking(overrides: Record<string, unknown> = {}) {
  return {
    id: 'booking-1',
    status: BookingStatus.PENDING,
    lane: 'BIDDING',
    categoryId: 'cat-1',
    latitude: JOB_LAT,
    longitude: JOB_LNG,
    workerProfileId: null,
    createdAt: new Date(),
    liveStartedAt: CYCLE_START,
    sourceInspectionBookingId: null,
    clientProfile: { userId: 'client-user-1' },
    workerExclusions: [],
    inspectionReport: null,
    sourceInspectionBooking: null,
    ...overrides,
  };
}

function makeWorker(overrides: Record<string, unknown> = {}) {
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

// ── Candidate query: everything that can be filtered in SQL, is ─────────────

describe('MatchingRepository.findCandidateWorkers — DB-level filtering', () => {
  let prisma: any;
  let repository: MatchingRepository;

  beforeEach(() => {
    prisma = {
      workerProfile: { findMany: jest.fn().mockResolvedValue([]) },
      booking: { findMany: jest.fn().mockResolvedValue([]) },
    };
    repository = new MatchingRepository(prisma);
  });

  async function whereFor(params: Record<string, unknown> = {}) {
    await repository.findCandidateWorkers({
      categoryId: 'cat-1',
      lat: JOB_LAT,
      lng: JOB_LNG,
      radiusKm: RADIUS_KM,
      ...params,
    } as any);
    return prisma.workerProfile.findMany.mock.calls[0][0].where;
  }

  it('rejects ineligible operational status in the database, not in Node', async () => {
    expect((await whereFor()).status).toBe(WorkerStatus.ACTIVE);
  });

  it('rejects unapproved / incomplete onboarding in the database', async () => {
    const where = await whereFor();
    expect(where.onboardingStatus).toBe('APPROVED');
    expect(where.profileCompleted).toBe(true);
  });

  it('requires ONLINE for live matching', async () => {
    expect((await whereFor()).availabilityStatus).toBe(
      AvailabilityStatus.ONLINE,
    );
  });

  it('excludes a currently-working Worker in the database', async () => {
    expect((await whereFor()).currentlyWorking).toBe(false);
  });

  it('applies the presence-lease freshness cutoff in the database', async () => {
    const before = Date.now();
    const where = await whereFor();
    const cutoff = (where.lastSeenAt.gte as Date).getTime();
    expect(cutoff).toBeGreaterThanOrEqual(before - WORKER_PRESENCE_STALE_MS);
    expect(cutoff).toBeLessThanOrEqual(Date.now() - WORKER_PRESENCE_STALE_MS);
  });

  it('applies the GPS freshness cutoff in the database, separately from presence', async () => {
    const before = Date.now();
    const where = await whereFor();
    const cutoff = (where.locationUpdatedAt.gte as Date).getTime();
    expect(cutoff).toBeGreaterThanOrEqual(before - LOCATION_FRESHNESS_MS);
    expect(cutoff).toBeLessThanOrEqual(Date.now() - LOCATION_FRESHNESS_MS);
    // The two cutoffs are different concepts and must stay independent.
    expect(cutoff).not.toBe((where.lastSeenAt.gte as Date).getTime());
  });

  it('rejects a null location in the database', async () => {
    const where = await whereFor();
    expect(where.currentLat).toEqual({ not: null });
    expect(where.currentLng).toEqual({ not: null });
  });

  it('matches the skill/category in the database', async () => {
    expect((await whereFor()).skills).toEqual({
      some: { categoryId: 'cat-1' },
    });
  });

  it('applies booking-specific exclusions in the database', async () => {
    const where = await whereFor({ excludedWorkerIds: ['worker-9'] });
    expect(where.id).toEqual({ notIn: ['worker-9'] });
  });

  it('pre-filters the radius as a bounding box in the database', async () => {
    const where = await whereFor();
    const box = boundingBoxKm(JOB_LAT, JOB_LNG, RADIUS_KM);
    expect(where.AND).toEqual([
      {
        currentLat: { gte: box.minLat, lte: box.maxLat },
        currentLng: { gte: box.minLng, lte: box.maxLng },
      },
    ]);
  });

  it('omits the geographic filter entirely when no job location is supplied', async () => {
    await repository.findCandidateWorkers({ categoryId: 'cat-1' });
    expect(
      prisma.workerProfile.findMany.mock.calls[0][0].where.AND,
    ).toBeUndefined();
  });

  it('projects only the matching columns — no CNIC/documents/User payload', async () => {
    await whereFor();
    const select = prisma.workerProfile.findMany.mock.calls[0][0].select;
    expect(Object.keys(select).sort()).toEqual(
      [
        'availabilityStatus',
        'currentLat',
        'currentLng',
        'currentlyWorking',
        'id',
        'lastSeenAt',
        'locationUpdatedAt',
        'onboardingStatus',
        'profileCompleted',
        'skills',
        'status',
        'userId',
      ].sort(),
    );
  });
});

// ── Late-discovery job query ────────────────────────────────────────────────

describe('MatchingRepository.findOpenBookingsForCategories — DB-level filtering', () => {
  let prisma: any;
  let repository: MatchingRepository;

  beforeEach(() => {
    prisma = { booking: { findMany: jest.fn().mockResolvedValue([]) } };
    repository = new MatchingRepository(prisma as any);
  });

  it('keeps completed/cancelled/assigned jobs out of the candidate flow in SQL', async () => {
    await repository.findOpenBookingsForCategories(['cat-1'], 'worker-1');
    const where = prisma.booking.findMany.mock.calls[0][0].where;
    expect(where.status).toBe(BookingStatus.PENDING);
    expect(where.workerProfileId).toBeNull();
  });

  it('enforces the 48h discovery window in SQL', async () => {
    const before = Date.now();
    await repository.findOpenBookingsForCategories(['cat-1'], 'worker-1');
    const cutoff = (
      prisma.booking.findMany.mock.calls[0][0].where.createdAt.gte as Date
    ).getTime();
    expect(cutoff).toBeGreaterThanOrEqual(before - JOB_DISCOVERY_WINDOW_MS);
    expect(cutoff).toBeLessThanOrEqual(Date.now() - JOB_DISCOVERY_WINDOW_MS);
  });

  it('applies per-booking Worker exclusions in SQL', async () => {
    await repository.findOpenBookingsForCategories(['cat-1'], 'worker-1');
    expect(
      prisma.booking.findMany.mock.calls[0][0].where.workerExclusions,
    ).toEqual({ none: { workerProfileId: 'worker-1' } });
  });

  it('pre-filters the radius from the job side as a bounding box', async () => {
    await repository.findOpenBookingsForCategories(['cat-1'], 'worker-1', {
      lat: JOB_LAT,
      lng: JOB_LNG,
      radiusKm: RADIUS_KM,
    });
    const box = boundingBoxKm(JOB_LAT, JOB_LNG, RADIUS_KM);
    expect(prisma.booking.findMany.mock.calls[0][0].where.AND).toEqual([
      {
        latitude: { gte: box.minLat, lte: box.maxLat },
        longitude: { gte: box.minLng, lte: box.maxLng },
      },
    ]);
  });

  it('short-circuits without querying when the Worker has no skills', async () => {
    await repository.findOpenBookingsForCategories([], 'worker-1');
    expect(prisma.booking.findMany).not.toHaveBeenCalled();
  });
});

// ── Fan-out: no N+1, recheck preserved ──────────────────────────────────────

describe('JobBroadcastService fan-out — batching without losing the recheck', () => {
  let matchingRepository: any;
  let notificationsService: any;
  let service: JobBroadcastService;

  const candidates = Array.from({ length: 12 }, (_, i) =>
    makeWorker({ id: `worker-${i}`, userId: `worker-user-${i}` }),
  );

  beforeEach(() => {
    matchingRepository = {
      findBookingForMatching: jest.fn().mockResolvedValue(makeBooking()),
      findWorkerForMatching: jest.fn().mockResolvedValue(makeWorker()),
      findCandidateWorkers: jest.fn().mockResolvedValue(candidates),
      findOpenBookingsForCategories: jest.fn().mockResolvedValue([]),
      findWorkersForMatching: jest.fn(async (ids: string[]) =>
        candidates.filter((c) => ids.includes(c.id)),
      ),
      findBookingsForMatching: jest.fn(async (ids: string[]) =>
        ids.map((id) => makeBooking({ id })),
      ),
    };
    notificationsService = {
      notify: jest.fn().mockResolvedValue(undefined),
      findAlreadyNotifiedThisCycle: jest.fn().mockResolvedValue(new Set()),
      findAlreadyNotifiedBookingIds: jest.fn().mockResolvedValue(new Set()),
    };
    service = new JobBroadcastService(
      matchingRepository,
      notificationsService,
      { tryAcquire: jest.fn().mockResolvedValue(true) } as any,
      {
        get: jest.fn((key: string) =>
          key === 'matching.radiusKm'
            ? RADIUS_KM
            : key === 'matching.fanOutChunkSize'
              ? 5
              : undefined,
        ),
      } as any,
    );
  });

  it('passes the job location and radius down so the DB bounds the candidate set', async () => {
    await service.broadcastJob('booking-1');
    expect(matchingRepository.findCandidateWorkers).toHaveBeenCalledWith(
      expect.objectContaining({
        categoryId: 'cat-1',
        lat: JOB_LAT,
        lng: JOB_LNG,
        radiusKm: RADIUS_KM,
      }),
    );
  });

  it('re-reads every recipient in batches instead of one query per recipient', async () => {
    await service.broadcastJob('booking-1');

    // 12 candidates at a chunk size of 5 → 3 chunks.
    expect(matchingRepository.findWorkersForMatching).toHaveBeenCalledTimes(3);
    expect(matchingRepository.findWorkerForMatching).not.toHaveBeenCalled();
    // One dedup query per chunk, not one per recipient.
    expect(
      notificationsService.findAlreadyNotifiedThisCycle,
    ).toHaveBeenCalledTimes(3);
    expect(notificationsService.notify).toHaveBeenCalledTimes(12);
  });

  it('still re-reads Worker state before pushing — a Worker who went offline mid-fan-out is skipped', async () => {
    matchingRepository.findWorkersForMatching.mockImplementation(
      async (ids: string[]) =>
        candidates
          .filter((c) => ids.includes(c.id))
          .map((c) =>
            c.id === 'worker-3'
              ? { ...c, availabilityStatus: AvailabilityStatus.OFFLINE }
              : c,
          ),
    );

    await service.broadcastJob('booking-1');

    const notifiedUserIds = notificationsService.notify.mock.calls.map(
      (call: any[]) => call[0].userId,
    );
    expect(notifiedUserIds).not.toContain('worker-user-3');
    expect(notifiedUserIds).toHaveLength(11);
  });

  it('still re-reads the job before pushing — a job hired mid-fan-out stops the fan-out', async () => {
    matchingRepository.findBookingForMatching
      .mockResolvedValueOnce(makeBooking())
      .mockResolvedValueOnce(makeBooking())
      .mockResolvedValue(makeBooking({ workerProfileId: 'someone-else' }));

    await service.broadcastJob('booking-1');

    // Chunk 1 pushed; the hire is observed on chunk 2's re-read and the rest
    // of the fan-out is abandoned.
    expect(notificationsService.notify).toHaveBeenCalledTimes(5);
  });

  it('skips Workers the batched dedup reports as already notified this cycle', async () => {
    notificationsService.findAlreadyNotifiedThisCycle.mockImplementation(
      async (userIds: string[]) =>
        new Set(userIds.filter((id) => id === 'worker-user-0')),
    );

    await service.broadcastJob('booking-1');

    const notifiedUserIds = notificationsService.notify.mock.calls.map(
      (call: any[]) => call[0].userId,
    );
    expect(notifiedUserIds).not.toContain('worker-user-0');
    expect(notifiedUserIds).toHaveLength(11);
  });

  it('never notifies the original inspector, even inside a batch (Find Other Ustaad)', async () => {
    matchingRepository.findBookingForMatching.mockResolvedValue(
      makeBooking({
        lane: 'BIDDING',
        sourceInspectionBookingId: 'inspection-1',
        sourceInspectionBooking: {
          inspectionReport: {
            decisionStatus: 'FIND_OTHER_USTAAD',
            workerProfileId: 'worker-4',
          },
        },
      }),
    );

    await service.broadcastJob('booking-1');

    const notifiedUserIds = notificationsService.notify.mock.calls.map(
      (call: any[]) => call[0].userId,
    );
    expect(notifiedUserIds).not.toContain('worker-user-4');
    expect(notifiedUserIds).toHaveLength(11);
  });

  it('passes the Worker location and radius down for late discovery too', async () => {
    await service.matchOpenJobsForWorker('worker-1', { bypassCooldown: true });
    expect(
      matchingRepository.findOpenBookingsForCategories,
    ).toHaveBeenCalledWith(['cat-1'], 'worker-1', {
      lat: JOB_LAT,
      lng: JOB_LNG,
      radiusKm: RADIUS_KM,
    });
  });

  it('batches the reverse fan-out (one Worker, many jobs) the same way', async () => {
    matchingRepository.findOpenBookingsForCategories.mockResolvedValue(
      Array.from({ length: 7 }, (_, i) => makeBooking({ id: `booking-${i}` })),
    );

    await service.matchOpenJobsForWorker('worker-1', { bypassCooldown: true });
    await flushPromises();

    // 7 jobs at a chunk size of 5 → 2 chunks, each with ONE Worker re-read
    // and ONE batched booking re-read.
    expect(matchingRepository.findBookingsForMatching).toHaveBeenCalledTimes(2);
    expect(matchingRepository.findWorkerForMatching).toHaveBeenCalledTimes(
      1 + 2, // the initial discovery read + one recheck per chunk
    );
    expect(notificationsService.notify).toHaveBeenCalledTimes(7);
  });
});
