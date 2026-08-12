import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/network/connectivity_service.dart';

/// [offlineActionGuard] is what every server-changing action notifier
/// (create/cancel booking, send message, accept job, submit review, …)
/// calls before ever attempting the request.
void main() {
  // Restore the default so this file never leaks state into another test
  // file sharing the same process (ConnectivityService is a singleton).
  tearDown(() => ConnectivityService.instance.debugIsOnline = true);

  group('offlineActionGuard', () {
    test('returns null (proceed) while the device is online', () {
      ConnectivityService.instance.debugIsOnline = true;

      expect(offlineActionGuard(), isNull);
    });

    test(
      'returns an OfflineActionBlockedFailure while the device is offline, '
      'so the caller blocks the action before ever attempting it',
      () {
        ConnectivityService.instance.debugIsOnline = false;

        final failure = offlineActionGuard();

        expect(failure, isA<OfflineActionBlockedFailure>());
        expect(failure!.code, FailureCode.offlineActionBlocked);
        // Never a raw/technical message — failure_messages.dart renders
        // this code's wording, not this string.
        expect(failure.message, isEmpty);
      },
    );

    test('flips back to null the moment connectivity returns', () {
      ConnectivityService.instance.debugIsOnline = false;
      expect(offlineActionGuard(), isNotNull);

      ConnectivityService.instance.debugIsOnline = true;
      expect(offlineActionGuard(), isNull);
    });
  });

  group('isOnlineProvider / onStatusChanged', () {
    test('broadcasts a change when connectivity flips', () async {
      ConnectivityService.instance.debugIsOnline = true;
      final events = <bool>[];
      final sub = ConnectivityService.instance.onStatusChanged.listen(events.add);
      addTearDown(sub.cancel);

      ConnectivityService.instance.debugIsOnline = false;
      ConnectivityService.instance.debugIsOnline = true;
      await Future<void>.delayed(Duration.zero);

      expect(events, [false, true]);
    });

    test('setting the same value again does not emit a duplicate event', () async {
      ConnectivityService.instance.debugIsOnline = true;
      final events = <bool>[];
      final sub = ConnectivityService.instance.onStatusChanged.listen(events.add);
      addTearDown(sub.cancel);

      ConnectivityService.instance.debugIsOnline = true;
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
    });
  });
}
