import 'package:geolocator/geolocator.dart';

/// The reason a location fix could not be produced (or the fact that one
/// was), always distinguished so the UI never has to guess which recovery
/// action applies. See `location_recovery_view.dart` for the widget that
/// renders each of these.
enum LocationAvailability {
  /// A fresh fix was obtained — [LocationAvailabilityResult.position] is set.
  available,

  /// Permission was denied but the OS will still show the request dialog
  /// again — "Allow Location" is actionable.
  permissionDenied,

  /// Permission was permanently denied — only the system Settings screen can
  /// restore it.
  permissionPermanentlyDenied,

  /// Permission is fine, but the device's location/GPS service itself is
  /// switched off.
  serviceDisabled,

  /// Permission and GPS are both available, but a fix could not be obtained
  /// in time (timeout) or the platform call failed.
  unavailable,
}

class LocationAvailabilityResult {
  final LocationAvailability status;
  final Position? position;

  const LocationAvailabilityResult(this.status, {this.position});

  bool get isAvailable => status == LocationAvailability.available;
}

/// Returns a best-effort camera position for non-authoritative map previews.
///
/// This deliberately never requests permission. If permission is already
/// granted it prefers the platform's last known fix, then attempts a short,
/// low-accuracy fresh fix when location services are enabled. Any denied
/// permission, disabled service, timeout, or platform failure returns null so
/// callers can use a neutral visual fallback without changing user state.
Future<Position?> resolvePassiveLocationPreview({
  Duration timeLimit = const Duration(seconds: 3),
}) async {
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final latest = await Geolocator.getLastKnownPosition();
    if (latest != null) return latest;

    if (!await Geolocator.isLocationServiceEnabled()) return null;
    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: timeLimit,
      ),
    ).timeout(timeLimit + const Duration(seconds: 1));
  } catch (_) {
    return null;
  }
}

/// Checks device location services, then permission, then attempts a fresh
/// fix — in that order, so a disabled GPS is reported as [serviceDisabled]
/// rather than masquerading as a permission problem, and a denied permission
/// is reported before ever attempting (and timing out) a fix.
///
/// Does not change any matching/freshness business rule — this only decides
/// what to *tell the user* when a fix cannot be produced. Callers that also
/// need the resulting position (e.g. "Go Online") still own that logic
/// themselves; this is a pre-flight UX check.
Future<LocationAvailabilityResult> resolveCurrentLocation({
  Duration timeLimit = const Duration(seconds: 10),
}) async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return const LocationAvailabilityResult(LocationAvailability.serviceDisabled);
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    return const LocationAvailabilityResult(
      LocationAvailability.permissionPermanentlyDenied,
    );
  }
  if (permission == LocationPermission.denied) {
    return const LocationAvailabilityResult(LocationAvailability.permissionDenied);
  }

  try {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeLimit,
      ),
    ).timeout(timeLimit + const Duration(seconds: 2));
    return LocationAvailabilityResult(
      LocationAvailability.available,
      position: position,
    );
  } catch (_) {
    return const LocationAvailabilityResult(LocationAvailability.unavailable);
  }
}

/// Opens the OS location-services screen (e.g. "turn on GPS"), distinct from
/// [Geolocator.openAppSettings] which opens this app's own permission page.
Future<void> openLocationServicesSettings() => Geolocator.openLocationSettings();

/// Opens this app's permission page in system Settings.
Future<void> openAppPermissionSettings() => Geolocator.openAppSettings();
