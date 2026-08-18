import { BookingsRepository } from './bookings.repository';

/**
 * Direct-hire discovery (STANDARD/INSPECTION "nearby workers" list) must
 * exclude a stale-presence Worker the same way the central
 * checkJobEligibility matcher does — this is the Haversine fallback path
 * (no PostGIS). The PostGIS raw-SQL path carries the equivalent
 * `wp."lastSeenAt" > cutoff` clause but isn't covered here — it has no
 * existing repository-level test harness (requires a live Postgres/PostGIS
 * connection), consistent with the rest of this file's raw-SQL methods.
 */
describe('BookingsRepository.findNearbyWorkers — presence lease (Haversine fallback)', () => {
  it('filters candidates to workers whose lastSeenAt is within the stale-presence window', async () => {
    const prisma = {
      workerProfile: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      review: { count: jest.fn().mockResolvedValue(0) },
      booking: { count: jest.fn().mockResolvedValue(0) },
    };
    const config = {
      get: jest.fn((key: string) => (key === 'usePostgis' ? false : undefined)),
    };

    const repository = new BookingsRepository(prisma as never, config as never);

    await repository.findNearbyWorkers({
      categoryId: 'cat-1',
      lat: 24.86,
      lng: 67.0,
    });

    const where = prisma.workerProfile.findMany.mock.calls[0][0].where;
    expect(where.lastSeenAt).toEqual({ gte: expect.any(Date) });
    // Presence and location freshness are independent, sibling checks.
    expect(where.locationUpdatedAt).toEqual({ gte: expect.any(Date) });
  });
});
