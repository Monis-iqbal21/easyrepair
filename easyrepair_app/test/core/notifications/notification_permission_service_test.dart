import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/notifications/notification_permission_service.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

class _FakePermissionHandlerPlatform extends PermissionHandlerPlatform {
  PermissionStatus status = PermissionStatus.granted;
  int openAppSettingsCalls = 0;
  int requestCalls = 0;

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async => status;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    requestCalls++;
    return {for (final p in permissions) p: status};
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls++;
    return true;
  }
}

void main() {
  late _FakePermissionHandlerPlatform fake;

  setUp(() {
    fake = _FakePermissionHandlerPlatform();
    PermissionHandlerPlatform.instance = fake;
  });

  group('checkNotificationPermissionState', () {
    test('granted → NotificationPermissionState.granted, no warning shown',
        () async {
      fake.status = PermissionStatus.granted;
      expect(
        await checkNotificationPermissionState(),
        NotificationPermissionState.granted,
      );
    });

    test('limited (iOS) is also treated as granted', () async {
      fake.status = PermissionStatus.limited;
      expect(
        await checkNotificationPermissionState(),
        NotificationPermissionState.granted,
      );
    });

    test('denied (still askable) → deniedCanAsk, distinct from permanent',
        () async {
      fake.status = PermissionStatus.denied;
      expect(
        await checkNotificationPermissionState(),
        NotificationPermissionState.deniedCanAsk,
      );
    });

    test('permanentlyDenied → permanentlyDenied (Settings-only recovery)',
        () async {
      fake.status = PermissionStatus.permanentlyDenied;
      expect(
        await checkNotificationPermissionState(),
        NotificationPermissionState.permanentlyDenied,
      );
    });
  });

  test('requestNotificationPermission asks the platform exactly once', () async {
    fake.status = PermissionStatus.denied;
    await requestNotificationPermission();
    expect(fake.requestCalls, 1);
  });
}
