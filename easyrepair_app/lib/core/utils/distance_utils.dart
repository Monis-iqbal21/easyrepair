import 'dart:math' as math;

import '../../l10n/app_localizations.dart';

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

/// Returns a human-readable distance label, e.g. "250 m away", "1.8 km away",
/// "Right at your location".
///
/// The wording depends on the selected language, so it arrives through
/// [AppLocalizations] rather than being decided inside this helper — same
/// shape as `features/bookings/presentation/utils/worker_labels.dart`. The
/// number itself is never translated: digits stay Latin in every language, so
/// a distance reads the same way to everyone.
String formatDistanceLabel(AppLocalizations l10n, double meters) {
  if (meters < 50) return l10n.distanceAtYourLocation;
  if (meters < 1000) return l10n.distanceMetersAway(meters.round());
  final km = meters / 1000;
  if (km < 10) return l10n.distanceKmAway(km.toStringAsFixed(1));
  return l10n.distanceKmAway('${km.round()}');
}
