import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/notifications/pending_notification_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers the persistence layer underneath app.dart's notification-tap
/// handling: a notification tapped while logged out must survive the app
/// process being killed before login completes, restore correctly on a
/// matching login, never leak across accounts, and expire/self-clean.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// A fresh SharedPreferences handle over the SAME mock-backed storage —
  /// simulates the app process being killed and relaunched (same technique
  /// used by locale_switching_test.dart's "survives app close and device
  /// restart" cases).
  Future<PendingNotificationStore> freshStore() async {
    final prefs = await SharedPreferences.getInstance();
    return PendingNotificationStore(prefs);
  }

  group('save + read (same-process)', () {
    test('a notification tapped while logged out can be read back', () async {
      final store = await freshStore();
      await store.setLastKnownUserId('user-A');

      await store.save({
        'eventKey': 'booking.assigned',
        'bookingId': 'booking-1',
      });

      final pending = await store.read();
      expect(pending, isNotNull);
      expect(pending!.data['eventKey'], 'booking.assigned');
      expect(pending.data['bookingId'], 'booking-1');
      expect(pending.ownerUserIdHint, 'user-A');
    });

    test('only the minimal routing keys are persisted — never the full payload', () async {
      final store = await freshStore();
      await store.save({
        'eventKey': 'chat.message',
        'conversationId': 'conv-1',
        'bookingId': 'booking-1',
        'entityType': 'conversation',
        'entityId': 'conv-1',
        'route': '/client/chat/conv-1',
        'notificationId': 'notif-1',
        'title': 'New message',
        'body': 'This is a private message body that must never be persisted',
        'actorUserId': 'worker-9',
      });

      final pending = await store.read();
      expect(pending!.data.keys, containsAll([
        'eventKey',
        'conversationId',
        'bookingId',
        'entityType',
        'entityId',
        'route',
        'notificationId',
      ]));
      expect(pending.data.containsKey('title'), isFalse);
      expect(pending.data.containsKey('body'), isFalse);
      expect(pending.data.containsKey('actorUserId'), isFalse);
    });

    test('a payload with none of the allowed routing keys is never saved', () async {
      final store = await freshStore();
      await store.save({'title': 'hello', 'body': 'world'});
      expect(await store.read(), isNull);
    });

    test('no pending notification returns null', () async {
      final store = await freshStore();
      expect(await store.read(), isNull);
    });
  });

  group('survives a simulated process restart', () {
    test('a saved destination is readable from a brand-new store instance over the same storage', () async {
      final firstProcess = await freshStore();
      await firstProcess.setLastKnownUserId('user-A');
      await firstProcess.save({
        'eventKey': 'booking.status.en_route',
        'bookingId': 'booking-1',
      });

      // Simulate the app being killed and relaunched.
      final secondProcess = await freshStore();
      final pending = await secondProcess.read();

      expect(pending, isNotNull);
      expect(pending!.data['eventKey'], 'booking.status.en_route');
      expect(pending.ownerUserIdHint, 'user-A');
    });
  });

  group('consumption clears the entry', () {
    test('clear() removes it — a second read returns null', () async {
      final store = await freshStore();
      await store.save({'eventKey': 'booking.completed', 'bookingId': 'b-1'});
      expect(await store.read(), isNotNull);

      await store.clear();

      expect(await store.read(), isNull);
    });
  });

  group('expiry (TTL)', () {
    test('an entry within the TTL is returned', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = PendingNotificationStore(prefs);
      await prefs.setString(
        'hg_pending_notification_v1',
        '{"data":{"eventKey":"booking.completed","bookingId":"b-1"},'
        '"ownerUserIdHint":"user-A",'
        '"savedAtEpochMs":${DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch}}',
      );

      expect(await store.read(), isNotNull);
    });

    test('an entry older than the TTL is discarded and cleared, not returned', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = PendingNotificationStore(prefs);
      final staleEpochMs = DateTime.now()
          .subtract(PendingNotificationStore.ttl + const Duration(minutes: 1))
          .millisecondsSinceEpoch;
      await prefs.setString(
        'hg_pending_notification_v1',
        '{"data":{"eventKey":"booking.completed","bookingId":"b-1"},'
        '"ownerUserIdHint":"user-A","savedAtEpochMs":$staleEpochMs}',
      );

      final pending = await store.read();

      expect(pending, isNull);
      // Self-cleaned — the stale entry does not linger for a later read.
      expect(prefs.getString('hg_pending_notification_v1'), isNull);
    });
  });

  group('corrupt data fails closed', () {
    test('unparseable JSON is discarded and cleared, not returned or thrown', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = PendingNotificationStore(prefs);
      await prefs.setString('hg_pending_notification_v1', 'not valid json{{{');

      expect(await store.read(), isNull);
      expect(prefs.getString('hg_pending_notification_v1'), isNull);
    });

    test('valid JSON missing the timestamp is discarded and cleared', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = PendingNotificationStore(prefs);
      await prefs.setString(
        'hg_pending_notification_v1',
        '{"data":{"eventKey":"booking.completed"}}',
      );

      expect(await store.read(), isNull);
      expect(prefs.getString('hg_pending_notification_v1'), isNull);
    });
  });

  group('cross-account leakage — ownerUserIdHint', () {
    test('a notification saved while Account A was last known does not carry A\'s hint over to B implicitly — the caller must compare it', () async {
      final store = await freshStore();
      await store.setLastKnownUserId('user-A');
      await store.save({'eventKey': 'booking.completed', 'bookingId': 'b-1'});

      // Account B logs in next (app.dart's login handler is what performs
      // the actual comparison — this pins the data this decision is made
      // from: the hint is frozen at save() time, not re-derived later).
      await store.setLastKnownUserId('user-B');
      final pending = await store.read();

      expect(pending!.ownerUserIdHint, 'user-A');
      expect(pending.ownerUserIdHint, isNot('user-B'));
    });

    test('setLastKnownUserId is not cleared by clear() — only the pending destination is', () async {
      final store = await freshStore();
      await store.setLastKnownUserId('user-A');
      await store.save({'eventKey': 'booking.completed', 'bookingId': 'b-1'});

      await store.clear();

      // A later notification for the same still-last-known account still
      // gets tagged correctly.
      await store.save({'eventKey': 'booking.assigned', 'bookingId': 'b-2'});
      final pending = await store.read();
      expect(pending!.ownerUserIdHint, 'user-A');
    });

    test('no prior login on this device means no owner hint — fails closed by design (caller must not navigate on a null hint)', () async {
      final store = await freshStore();
      // setLastKnownUserId never called — fresh install/device.
      await store.save({'eventKey': 'booking.completed', 'bookingId': 'b-1'});

      final pending = await store.read();
      expect(pending!.ownerUserIdHint, isNull);
    });
  });
}
