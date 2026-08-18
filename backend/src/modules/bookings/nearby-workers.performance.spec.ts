import { BookingLane } from '@prisma/client';
import { BookingsRepository } from './bookings.repository';
import { boundingBoxKm } from '../../common/utils/geo.util';

/**
 * Direct-hire "nearby Ustaads" discovery (Haversine + bounding-box path — the
 * default, USE_POSTGIS=false).
 *
 * The optimization collapsed the radius LADDER from up to six sequential
 * database queries into ONE bounded query plus in-memory rung selection. These
 * tests pin the behaviour that must be identical either way: which Workers
 * come back, in what order, at which reported radius, and when expansion
 * stops.
 */

const JOB_LAT = 24.8607;
const JOB_LNG = 67.0011;

/** A Worker offset [km] due north of the job — a clean distance to reason about. */
function workerAtKm(id: string, km: number, rating = 4) {
  return {
    id,
    firstName: id,
    lastName: 'Ustaad',
    avatarUrl: null,
    rating,
    currentLat: JOB_LAT + km / 111.195,
    currentLng: JOB_LNG,
    skills: [{ category: { name: 'AC Repair' } }],
  };
}

function makeRepository(candidates: ReturnType<typeof workerAtKm>[]) {
  const prisma = {
    workerProfile: { findMany: jest.fn().mockResolvedValue(candidates) },
    booking: {
      groupBy: jest.fn().mockResolvedValue([]),
      findMany: jest.fn().mockResolvedValue([]),
    },
  };
  const config = {
    get: jest.fn((key: string) => (key === 'usePostgis' ? false : undefined)),
  };
  return {
    prisma,
    repository: new BookingsRepository(prisma as never, config as never),
  };
}

describe('BookingsRepository nearby search — geographic push-down', () => {
  it('sends a bounding box to the database instead of loading every Worker', async () => {
    const { prisma, repository } = makeRepository([]);

    await repository.findNearbyWorkers({
      categoryId: 'cat-1',
      lat: JOB_LAT,
      lng: JOB_LNG,
      lane: BookingLane.BIDDING,
    });

    // Widest rung of the legacy ladder — one query, not one per rung.
    expect(prisma.workerProfile.findMany).toHaveBeenCalledTimes(1);
    const args = prisma.workerProfile.findMany.mock.calls[0][0];
    const box = boundingBoxKm(JOB_LAT, JOB_LNG, 20);
    expect(args.where.AND).toEqual([
      {
        currentLat: { gte: box.minLat, lte: box.maxLat },
        currentLng: { gte: box.minLng, lte: box.maxLng },
      },
    ]);
  });

  it('caps the candidate query so one search can never pull an unbounded pool', async () => {
    const { prisma, repository } = makeRepository([]);
    await repository.findNearbyWorkers({
      categoryId: 'cat-1',
      lat: JOB_LAT,
      lng: JOB_LNG,
    });
    expect(prisma.workerProfile.findMany.mock.calls[0][0].take).toBe(200);
  });

  it('projects only display columns — no documents, CNIC images or User payload', async () => {
    const { prisma, repository } = makeRepository([]);
    await repository.findNearbyWorkers({
      categoryId: 'cat-1',
      lat: JOB_LAT,
      lng: JOB_LNG,
    });
    const select = prisma.workerProfile.findMany.mock.calls[0][0].select;
    expect(Object.keys(select).sort()).toEqual([
      'avatarUrl',
      'currentLat',
      'currentLng',
      'firstName',
      'id',
      'lastName',
      'rating',
      'skills',
    ]);
    // The per-row COMPLETED-booking count is now one batched groupBy.
    expect(select._count).toBeUndefined();
  });

  it('boxes to the single caller-supplied radius for frontend-driven expansion', async () => {
    const { prisma, repository } = makeRepository([]);
    await repository.findNearbyWorkers({
      categoryId: 'cat-1',
      lat: JOB_LAT,
      lng: JOB_LNG,
      radiusKm: 5,
    });
    const box = boundingBoxKm(JOB_LAT, JOB_LNG, 5);
    expect(
      prisma.workerProfile.findMany.mock.calls[0][0].where.AND[0].currentLat,
    ).toEqual({ gte: box.minLat, lte: box.maxLat });
  });
});

describe('BookingsRepository nearby search — radius, ordering and expansion', () => {
  it('returns only Workers inside the searched radius', async () => {
    // The bounding box is a superset of the circle, so the DB can legitimately
    // hand back a Worker just outside it — the precise pass must drop them.
    const { repository } = makeRepository([
      workerAtKm('near', 1),
      workerAtKm('far', 25),
    ]);

    const { workers } = await repository.findNearbyWorkers({
      categoryId: 'cat-1',
      lat: JOB_LAT,
      lng: JOB_LNG,
      lane: BookingLane.BIDDING,
    });

    expect(workers.map((w) => w.id)).toEqual(['near']);
  });

  it('preserves nearest-first ordering', async () => {
    const { repository } = makeRepository([
      workerAtKm('c', 2.8),
      workerAtKm('a', 0.4),
      workerAtKm('d', 2.9),
      workerAtKm('b', 1.2),
    ]);

    const { workers } = await repository.findNearbyWorkers({
      categoryId: 'cat-1',
      lat: JOB_LAT,
      lng: JOB_LNG,
      lane: BookingLane.BIDDING,
    });

    expect(workers.map((w) => w.id)).toEqual(['a', 'b', 'c', 'd']);
  });

  it('stops expanding as soon as the target pool is satisfied', async () => {
    // Four Workers inside the first 3 km rung, one much farther out.
    const { repository } = makeRepository([
      workerAtKm('a', 0.5),
      workerAtKm('b', 1.0),
      workerAtKm('c', 1.5),
      workerAtKm('d', 2.0),
      workerAtKm('e', 12),
    ]);

    const result = await repository.findNearbyWorkers({
      categoryId: 'cat-1',
      lat: JOB_LAT,
      lng: JOB_LNG,
      lane: BookingLane.BIDDING,
    });

    expect(result.searchedRadiusKm).toBe(3);
    expect(result.searchCompleted).toBe(true);
    expect(result.workers.map((w) => w.id)).toEqual(['a', 'b', 'c', 'd']);
  });

  it('expands rung by rung until the target pool is reached', async () => {
    const { repository } = makeRepository([
      workerAtKm('a', 1),
      workerAtKm('b', 4),
      workerAtKm('c', 6),
      workerAtKm('d', 7.5),
    ]);

    const result = await repository.findNearbyWorkers({
      categoryId: 'cat-1',
      lat: JOB_LAT,
      lng: JOB_LNG,
      lane: BookingLane.BIDDING,
    });

    // 3km → 1, 5km → 2, 8km → 4 ⇒ stops at the 8km rung.
    expect(result.searchedRadiusKm).toBe(8);
    expect(result.workers).toHaveLength(4);
  });

  it('enforces the maximum radius and reports an incomplete search', async () => {
    const { repository } = makeRepository([
      workerAtKm('inside', 19),
      workerAtKm('outside', 21),
    ]);

    const result = await repository.findNearbyWorkers({
      categoryId: 'cat-1',
      lat: JOB_LAT,
      lng: JOB_LNG,
      lane: BookingLane.BIDDING,
    });

    expect(result.searchedRadiusKm).toBe(20);
    expect(result.searchCompleted).toBe(false);
    expect(result.workers.map((w) => w.id)).toEqual(['inside']);
  });

  it('uses the tighter 5→7km ladder for the direct-assignment lanes', async () => {
    for (const lane of [BookingLane.STANDARD, BookingLane.INSPECTION]) {
      const { prisma, repository } = makeRepository([workerAtKm('a', 6)]);
      const result = await repository.findNearbyWorkers({
        categoryId: 'cat-1',
        lat: JOB_LAT,
        lng: JOB_LNG,
        lane,
      });
      // Boxed to the 7km max rung, and the 5km rung did not satisfy the pool.
      const box = boundingBoxKm(JOB_LAT, JOB_LNG, 7);
      expect(
        prisma.workerProfile.findMany.mock.calls[0][0].where.AND[0].currentLat,
      ).toEqual({ gte: box.minLat, lte: box.maxLat });
      expect(result.searchedRadiusKm).toBe(7);
      expect(result.workers.map((w) => w.id)).toEqual(['a']);
    }
  });

  it('never returns a Worker excluded from this booking', async () => {
    const { prisma, repository } = makeRepository([]);
    await repository.findNearbyWorkers({
      categoryId: 'cat-1',
      lat: JOB_LAT,
      lng: JOB_LNG,
      excludedWorkerIds: ['worker-9'],
    });
    expect(prisma.workerProfile.findMany.mock.calls[0][0].where.id).toEqual({
      notIn: ['worker-9'],
    });
  });
});

describe('BookingsRepository nearby search — stats batching (N+1 removal)', () => {
  it('resolves completedJobs and review/cancellation stats without per-Worker queries', async () => {
    const candidates = Array.from({ length: 6 }, (_, i) =>
      workerAtKm(`w${i}`, i * 0.2),
    );
    const { prisma, repository } = makeRepository(candidates);
    prisma.booking.groupBy.mockImplementation(async (args: any) => {
      if (args.where.status === 'COMPLETED') {
        return [{ workerProfileId: 'w0', _count: { _all: 9 } }];
      }
      if (args.where.status === 'CANCELLED') {
        return [{ workerProfileId: 'w0', _count: { _all: 1 } }];
      }
      return [{ workerProfileId: 'w0', _count: { _all: 4 } }];
    });
    prisma.booking.findMany.mockResolvedValue([
      { workerProfileId: 'w0' },
      { workerProfileId: 'w0' },
    ]);

    const { workers } = await repository.findNearbyWorkers({
      categoryId: 'cat-1',
      lat: JOB_LAT,
      lng: JOB_LNG,
    });

    const w0 = workers.find((w) => w.id === 'w0')!;
    expect(w0.completedJobs).toBe(9);
    expect(w0.reviewsCount).toBe(2);
    expect(w0.cancellationRate).toBe(25); // 1 / 4
    // Three grouped queries + one review-attribution read, for SIX Workers —
    // previously this was three queries PER Worker.
    expect(prisma.booking.groupBy).toHaveBeenCalledTimes(3);
    expect(prisma.booking.findMany).toHaveBeenCalledTimes(1);
  });

  it('skips the stats round trips entirely for an empty pool', async () => {
    const { prisma, repository } = makeRepository([]);
    await repository.findNearbyWorkers({
      categoryId: 'cat-1',
      lat: JOB_LAT,
      lng: JOB_LNG,
    });
    expect(prisma.booking.groupBy).not.toHaveBeenCalled();
  });
});

describe('BookingsRepository.findNearbyWorkerIds — membership test', () => {
  it('runs the same search but skips the stats/ranking work', async () => {
    const { prisma, repository } = makeRepository([
      workerAtKm('a', 1),
      workerAtKm('b', 30),
    ]);

    const ids = await repository.findNearbyWorkerIds({
      categoryId: 'cat-1',
      lat: JOB_LAT,
      lng: JOB_LNG,
      lane: BookingLane.BIDDING,
    });

    expect([...ids]).toEqual(['a']);
    // completedJobs is still batched for the pool; the review/cancellation
    // stats are not fetched at all.
    expect(prisma.booking.groupBy).toHaveBeenCalledTimes(1);
  });
});
