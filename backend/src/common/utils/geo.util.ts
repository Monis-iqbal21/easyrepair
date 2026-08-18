/** Returns the great-circle distance in km, or null when either coordinate pair is missing. */
export function haversineKm(
  lat1: number | null | undefined,
  lng1: number | null | undefined,
  lat2: number | null | undefined,
  lng2: number | null | undefined,
): number | null {
  if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) return null;
  const R = 6371;
  const dLat = _deg2rad(lat2 - lat1);
  const dLng = _deg2rad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(_deg2rad(lat1)) *
      Math.cos(_deg2rad(lat2)) *
      Math.sin(dLng / 2) ** 2;
  return +(R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))).toFixed(2);
}

function _deg2rad(deg: number): number {
  return (deg * Math.PI) / 180;
}

/**
 * A latitude/longitude window that fully CONTAINS the circle of [radiusKm]
 * around (lat, lng). Deliberately a superset, never a subset: it is a cheap,
 * index-friendly SQL pre-filter that only removes rows which precise
 * Haversine/PostGIS distance would have rejected anyway, so pushing it into
 * the database can never change which workers/jobs are considered eligible.
 *
 * [crossesAntimeridian] is true when the window wraps past ±180° longitude.
 * Callers must then test `lng >= minLng OR lng <= maxLng` instead of BETWEEN.
 * HandyGo operates in Pakistan (~60–80°E) so this never triggers in practice,
 * but the filter must stay correct rather than merely convenient.
 *
 * Near the poles the longitude span degenerates (cos(lat) → 0); in that case
 * the whole longitude range is returned so nothing is ever wrongly excluded.
 */
export interface GeoBoundingBox {
  minLat: number;
  maxLat: number;
  minLng: number;
  maxLng: number;
  crossesAntimeridian: boolean;
}

const EARTH_RADIUS_KM = 6371;

export function boundingBoxKm(
  lat: number,
  lng: number,
  radiusKm: number,
): GeoBoundingBox {
  const latDelta = (radiusKm / EARTH_RADIUS_KM) * (180 / Math.PI);
  const minLat = Math.max(-90, lat - latDelta);
  const maxLat = Math.min(90, lat + latDelta);

  // Widest longitude span occurs at the latitude edge of the box nearest a
  // pole — use it so the window stays a strict superset of the circle.
  const widestLat = Math.max(Math.abs(minLat), Math.abs(maxLat));
  const cosLat = Math.cos((widestLat * Math.PI) / 180);

  if (cosLat <= 1e-9 || latDelta >= 180) {
    return {
      minLat,
      maxLat,
      minLng: -180,
      maxLng: 180,
      crossesAntimeridian: false,
    };
  }

  const lngDelta = ((radiusKm / EARTH_RADIUS_KM) * (180 / Math.PI)) / cosLat;
  if (lngDelta >= 180) {
    return {
      minLat,
      maxLat,
      minLng: -180,
      maxLng: 180,
      crossesAntimeridian: false,
    };
  }

  let minLng = lng - lngDelta;
  let maxLng = lng + lngDelta;
  let crossesAntimeridian = false;
  if (minLng < -180) {
    minLng += 360;
    crossesAntimeridian = true;
  }
  if (maxLng > 180) {
    maxLng -= 360;
    crossesAntimeridian = true;
  }

  return { minLat, maxLat, minLng, maxLng, crossesAntimeridian };
}

/**
 * The bounding box as a Prisma `where` fragment over a pair of float columns.
 * Returns the antimeridian-safe shape when the window wraps.
 */
export function boundingBoxWhere(
  box: GeoBoundingBox,
  latField = 'latitude',
  lngField = 'longitude',
): Record<string, unknown> {
  const latClause = { [latField]: { gte: box.minLat, lte: box.maxLat } };
  if (!box.crossesAntimeridian) {
    return { ...latClause, [lngField]: { gte: box.minLng, lte: box.maxLng } };
  }
  return {
    ...latClause,
    OR: [
      { [lngField]: { gte: box.minLng } },
      { [lngField]: { lte: box.maxLng } },
    ],
  };
}
