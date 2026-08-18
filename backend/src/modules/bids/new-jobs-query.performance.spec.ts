import { BookingStatus } from '@prisma/client';
import { BidsRepository } from './bids.repository';
import { JOB_DISCOVERY_WINDOW_MS } from '../../common/utils/job-eligibility.util';
import { boundingBoxKm } from '../../common/utils/geo.util';

/**
 * The Worker-facing New Jobs feed is MARKETPLACE BROWSING, not live matching.
 *
 * The performance work pushed the discovery window and the match radius into
 * SQL, and the single most important thing these tests guard is what was NOT
 * pushed down: a manually OFFLINE Ustaad must still be able to browse and bid.
 * An `availabilityStatus: ONLINE` predicate creeping into this query would
 * silently delete that product rule while every other test still passed.
 */

const WORKER_LAT = 24.8607;
const WORKER_LNG = 67.0011;
const RADIUS_KM = 7;

describe('BidsRepository.findAvailableJobsForWorker — marketplace query shape', () => {
  let prisma: any;
  let repository: BidsRepository;

  beforeEach(() => {
    prisma = { booking: { findMany: jest.fn().mockResolvedValue([]) } };
    repository = new BidsRepository(prisma as never);
  });

  async function whereFor(geo?: {
    lat?: number | null;
    lng?: number | null;
    radiusKm?: number;
  }) {
    await repository.findAvailableJobsForWorker('worker-1', ['cat-1'], geo);
    return prisma.booking.findMany.mock.calls[0][0].where;
  }

  it('does NOT require the Worker to be ONLINE — manual-OFFLINE browsing is preserved', async () => {
    const where = await whereFor({
      lat: WORKER_LAT,
      lng: WORKER_LNG,
      radiusKm: RADIUS_KM,
    });
    expect(JSON.stringify(where)).not.toContain('availabilityStatus');
    expect(JSON.stringify(where)).not.toContain('ONLINE');
  });

  it('keeps completed/cancelled/assigned jobs out of the feed in SQL', async () => {
    const where = await whereFor();
    expect(where.status).toBe(BookingStatus.PENDING);
    expect(where.workerProfileId).toBeNull();
  });

  it('still enforces the 48h discovery window in SQL', async () => {
    const before = Date.now();
    const where = await whereFor();
    const cutoff = (where.createdAt.gte as Date).getTime();
    expect(cutoff).toBeGreaterThanOrEqual(before - JOB_DISCOVERY_WINDOW_MS);
    expect(cutoff).toBeLessThanOrEqual(Date.now() - JOB_DISCOVERY_WINDOW_MS);
  });

  it('still applies per-booking Worker exclusions in SQL', async () => {
    expect((await whereFor()).workerExclusions).toEqual({
      none: { workerProfileId: 'worker-1' },
    });
  });

  it('pre-filters the match radius as a bounding box in SQL', async () => {
    const where = await whereFor({
      lat: WORKER_LAT,
      lng: WORKER_LNG,
      radiusKm: RADIUS_KM,
    });
    const box = boundingBoxKm(WORKER_LAT, WORKER_LNG, RADIUS_KM);
    expect(where.AND).toEqual([
      {
        latitude: { gte: box.minLat, lte: box.maxLat },
        longitude: { gte: box.minLng, lte: box.maxLng },
      },
    ]);
  });

  it('falls back to no geographic filter for a Worker with no location on file', async () => {
    const where = await whereFor({
      lat: null,
      lng: null,
      radiusKm: RADIUS_KM,
    });
    expect(where.AND).toBeUndefined();
  });
});
