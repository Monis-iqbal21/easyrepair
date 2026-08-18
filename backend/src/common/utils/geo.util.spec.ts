import { boundingBoxKm, boundingBoxWhere, haversineKm } from './geo.util';

/**
 * The bounding box is the geographic PRE-FILTER pushed into SQL ahead of the
 * precise distance check. Its one hard requirement is that it be a strict
 * SUPERSET of the radius circle: if it ever excluded a point the precise check
 * would have accepted, matching would silently lose eligible Workers/jobs.
 */
describe('boundingBoxKm', () => {
  // Karachi — HandyGo's operating region.
  const LAT = 24.8607;
  const LNG = 67.0011;

  it('contains every point inside the radius (superset guarantee)', () => {
    const radiusKm = 7;
    const box = boundingBoxKm(LAT, LNG, radiusKm);

    // Sweep the circle: every bearing, at the exact radius and just inside.
    for (let bearing = 0; bearing < 360; bearing += 5) {
      for (const distance of [radiusKm, radiusKm * 0.999, radiusKm * 0.5]) {
        const rad = (bearing * Math.PI) / 180;
        const dLat = (distance / 6371) * (180 / Math.PI) * Math.cos(rad);
        const dLng =
          ((distance / 6371) * (180 / Math.PI) * Math.sin(rad)) /
          Math.cos((LAT * Math.PI) / 180);
        const pointLat = LAT + dLat;
        const pointLng = LNG + dLng;

        // Sanity: this point really is within the radius.
        const actual = haversineKm(LAT, LNG, pointLat, pointLng) as number;
        if (actual > radiusKm) continue;

        expect(pointLat).toBeGreaterThanOrEqual(box.minLat);
        expect(pointLat).toBeLessThanOrEqual(box.maxLat);
        expect(pointLng).toBeGreaterThanOrEqual(box.minLng);
        expect(pointLng).toBeLessThanOrEqual(box.maxLng);
      }
    }
  });

  it('is genuinely bounded — far-away points fall outside it', () => {
    const box = boundingBoxKm(LAT, LNG, 7);
    // Lahore, ~1000 km away.
    expect(31.5204 <= box.maxLat && 31.5204 >= box.minLat).toBe(false);
  });

  it('does not wrap for HandyGo coordinates', () => {
    expect(boundingBoxKm(LAT, LNG, 20).crossesAntimeridian).toBe(false);
  });

  it('flags the antimeridian wrap instead of producing an inverted range', () => {
    const box = boundingBoxKm(0, 179.99, 50);
    expect(box.crossesAntimeridian).toBe(true);
    expect(box.minLng).toBeGreaterThan(0);
    expect(box.maxLng).toBeLessThan(0);
  });

  it('falls back to the whole longitude range near the poles', () => {
    const box = boundingBoxKm(89.999, 10, 50);
    expect(box.minLng).toBe(-180);
    expect(box.maxLng).toBe(180);
  });
});

describe('boundingBoxWhere', () => {
  it('emits a plain BETWEEN-style pair for a non-wrapping box', () => {
    const box = boundingBoxKm(24.8607, 67.0011, 7);
    const where = boundingBoxWhere(box, 'currentLat', 'currentLng') as any;

    expect(where.currentLat).toEqual({ gte: box.minLat, lte: box.maxLat });
    expect(where.currentLng).toEqual({ gte: box.minLng, lte: box.maxLng });
    expect(where.OR).toBeUndefined();
  });

  it('emits the OR form when the box wraps the antimeridian', () => {
    const box = boundingBoxKm(0, 179.99, 50);
    const where = boundingBoxWhere(box, 'longitude') as any;

    expect(where.OR).toEqual([
      { longitude: { gte: box.minLng } },
      { longitude: { lte: box.maxLng } },
    ]);
  });
});
