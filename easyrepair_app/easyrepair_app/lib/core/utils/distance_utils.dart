import 'dart:math' as math;

/// Returns the geodesic distance in **meters** between two lat/lng points
/// using the Haversine formula.
double haversineDistanceMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadiusM = 6371000.0;
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) *
          math.cos(_toRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusM * c;
}

double _toRad(double deg) => deg * math.pi / 180;

/// Returns a human-readable distance string.
/// e.g. "250 m away", "1.8 km away", "Right at your location"
String formatDistance(double meters) {
  if (meters < 50) return 'Right at your location';
  if (meters < 1000) return '${meters.round()} m away';
  final km = meters / 1000;
  if (km < 10) return '${km.toStringAsFixed(1)} km away';
  return '${km.round()} km away';
}
