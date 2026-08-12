import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Mirrors the three states the Profile/Settings recovery card distinguishes.
/// Uses `permission_handler` (the same package [AppPermissionService] already
/// uses for camera/microphone/location) rather than
/// `firebase_messaging`'s own authorization API, so the whole app reads
/// permission state through one consistent mechanism.
enum NotificationPermissionState {
  /// Notifications are allowed — nothing to show.
  granted,

  /// Denied, but the OS will still show the system request dialog again.
  deniedCanAsk,

  /// Permanently denied — only the system Settings screen can restore it.
  permanentlyDenied,
}

Future<NotificationPermissionState> checkNotificationPermissionState() async {
  final status = await Permission.notification.status;
  if (status.isGranted || status.isLimited) {
    return NotificationPermissionState.granted;
  }
  if (status.isPermanentlyDenied) {
    return NotificationPermissionState.permanentlyDenied;
  }
  return NotificationPermissionState.deniedCanAsk;
}

Future<void> requestNotificationPermission() => Permission.notification.request();

/// Re-read on every visit to the screen that hosts the recovery card
/// (autoDispose — never polled or shown as a startup modal).
final notificationPermissionStateProvider =
    FutureProvider.autoDispose<NotificationPermissionState>(
  (ref) => checkNotificationPermissionState(),
);
