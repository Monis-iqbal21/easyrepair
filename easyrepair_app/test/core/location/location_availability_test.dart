import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:handygo_app/core/location/location_availability.dart';

class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission checkResult = LocationPermission.whileInUse;
  LocationPermission requestResult = LocationPermission.whileInUse;
  Object? getCurrentPositionError;
  Position? position;
  int requestPermissionCalls = 0;
  int openLocationSettingsCalls = 0;
  int openAppSettingsCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => checkResult;

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalls++;
    return requestResult;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    if (getCurrentPositionError != null) throw getCurrentPositionError!;
    return position!;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalls++;
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls++;
    return true;
  }
}

Position _fakePosition() => Position(
      latitude: 24.86,
      longitude: 67.00,
      timestamp: DateTime(2026, 1, 1),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  late _FakeGeolocatorPlatform fake;

  setUp(() {
    fake = _FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = fake;
  });

  group('resolveCurrentLocation', () {
    test('GPS/location services disabled is reported distinctly, before '
        'permission is ever checked', () async {
      fake.serviceEnabled = false;

      final result = await resolveCurrentLocation();

      expect(result.status, LocationAvailability.serviceDisabled);
      expect(result.isAvailable, isFalse);
      expect(fake.requestPermissionCalls, 0,
          reason: 'must not attempt a permission request when GPS is off');
    });

    test('permission denied but askable is reported as permissionDenied',
        () async {
      fake.checkResult = LocationPermission.denied;
      fake.requestResult = LocationPermission.denied;

      final result = await resolveCurrentLocation();

      expect(result.status, LocationAvailability.permissionDenied);
      expect(fake.requestPermissionCalls, 1,
          reason: 're-prompts once when initially denied');
    });

    test('permission permanently denied is reported distinctly', () async {
      fake.checkResult = LocationPermission.denied;
      fake.requestResult = LocationPermission.deniedForever;

      final result = await resolveCurrentLocation();

      expect(result.status, LocationAvailability.permissionPermanentlyDenied);
    });

    test('a fix that fails/times out is reported as unavailable — never an '
        'infinite wait, never a raw exception surfaced to the caller',
        () async {
      fake.checkResult = LocationPermission.whileInUse;
      fake.getCurrentPositionError = Exception('platform channel boom');

      final result = await resolveCurrentLocation(
        timeLimit: const Duration(milliseconds: 50),
      );

      expect(result.status, LocationAvailability.unavailable);
      expect(result.position, isNull);
    });

    test('permission granted and GPS on returns a fresh position', () async {
      fake.checkResult = LocationPermission.whileInUse;
      fake.position = _fakePosition();

      final result = await resolveCurrentLocation();

      expect(result.status, LocationAvailability.available);
      expect(result.isAvailable, isTrue);
      expect(result.position!.latitude, 24.86);
    });

    test('already-granted permission never re-prompts', () async {
      fake.checkResult = LocationPermission.always;
      fake.position = _fakePosition();

      await resolveCurrentLocation();

      expect(fake.requestPermissionCalls, 0);
    });
  });

  group('Settings routing', () {
    test('openLocationServicesSettings opens the OS location-services screen',
        () async {
      await openLocationServicesSettings();
      expect(fake.openLocationSettingsCalls, 1);
    });

    test('openAppPermissionSettings opens this app\'s permission page',
        () async {
      await openAppPermissionSettings();
      expect(fake.openAppSettingsCalls, 1);
    });
  });
}
