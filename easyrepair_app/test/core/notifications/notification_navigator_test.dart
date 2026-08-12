import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/notifications/notification_navigator.dart';

/// Pins the single centralized notification-payload → route mapping used by
/// FCM taps, local-notification taps, and in-app notification-list taps
/// alike (see app.dart / notification_list_page.dart). Every entry here is
/// an eventKey actually emitted by the backend (see notifications.service.ts
/// call sites) — this test intentionally does not invent event types the
/// backend never sends.
void main() {
  group('chat / conversation routing (precedence #1)', () {
    test('conversationId routes a Client to their chat thread', () {
      final route = NotificationNavigator.resolveRoute(
        {'conversationId': 'conv-1', 'eventKey': 'chat.message'},
        isWorker: false,
      );
      expect(route, '/client/chat/conv-1');
    });

    test('conversationId routes a Worker to their chat thread', () {
      final route = NotificationNavigator.resolveRoute(
        {'conversationId': 'conv-1', 'eventKey': 'chat.message'},
        isWorker: true,
      );
      expect(route, '/worker/chat/conv-1');
    });

    test('entityType conversation + entityId is equivalent to conversationId', () {
      final route = NotificationNavigator.resolveRoute(
        {'entityType': 'conversation', 'entityId': 'conv-2'},
        isWorker: false,
      );
      expect(route, '/client/chat/conv-2');
    });

    test(
      'a support-conversation payload routes exactly like any other conversation — '
      'the conversationId alone is enough, no special-casing needed',
      () {
        final route = NotificationNavigator.resolveRoute(
          {'conversationId': 'support-conv-1', 'eventKey': 'chat.message'},
          isWorker: false,
        );
        expect(route, '/client/chat/support-conv-1');
      },
    );

    test('conversationId takes precedence over a bookingId also present in the payload', () {
      final route = NotificationNavigator.resolveRoute(
        {'conversationId': 'conv-1', 'bookingId': 'booking-1'},
        isWorker: true,
      );
      expect(route, '/worker/chat/conv-1');
    });
  });

  group('booking / job routing (precedence #2) — Worker recipient', () {
    // Every worker-facing booking eventKey the backend actually emits
    // (bookings.service.ts / bids.service.ts / inspection-reports.service.ts /
    // job-broadcast.service.ts) resolves to the job detail page.
    for (final eventKey in [
      'bid.received', // technically client-facing, but exercised for shape
      'booking.assigned',
      'booking.completed',
      'booking.inspection.closed',
      'booking.standard.worker_listed',
      'booking.inspection.available',
      'booking.bidding.available',
      'booking.inspection.find_other_ustaad_available',
    ]) {
      test('$eventKey routes a Worker to /worker/job/:id', () {
        final route = NotificationNavigator.resolveRoute(
          {'bookingId': 'booking-1', 'eventKey': eventKey},
          isWorker: true,
        );
        expect(route, '/worker/job/booking-1');
      });
    }

    test('bid.accepted routes the WINNING Worker to job detail, not track-worker (track-worker is Client-only)', () {
      final route = NotificationNavigator.resolveRoute(
        {'bookingId': 'booking-1', 'eventKey': 'bid.accepted'},
        isWorker: true,
      );
      expect(route, '/worker/job/booking-1');
    });
  });

  group('booking / job routing (precedence #2) — Client recipient', () {
    // Client-facing worker-lifecycle eventKeys (bookings.service.ts /
    // inspection-reports.service.ts / bookings.processor.ts) resolve to the
    // booking detail page, EXCEPT the track-worker set below.
    for (final eventKey in [
      'booking.status.arrived',
      'booking.status.in_progress',
      'booking.inspection.report_submitted',
      'booking.cancelled.by_worker',
      'booking.review.created', // worker-facing normally, exercised for shape
      'booking.cancelled.by_client',
      'booking.inspection.quote_accepted',
      'booking.expired',
      'booking.relisted',
    ]) {
      test('$eventKey routes a Client to /client/booking/:id', () {
        final route = NotificationNavigator.resolveRoute(
          {'bookingId': 'booking-1', 'eventKey': eventKey},
          isWorker: false,
        );
        expect(route, '/client/booking/booking-1');
      });
    }

    // "WORKER ON THE WAY" must open live tracking, not the static detail page.
    group('Track Worker page — hire/assignment + on-the-way', () {
      for (final eventKey in [
        'bid.accepted',
        'booking.assigned',
        'worker.hired',
        'worker.assigned',
        'booking.status.en_route',
      ]) {
        test('$eventKey routes a Client to /client/track/:id', () {
          final route = NotificationNavigator.resolveRoute(
            {'bookingId': 'booking-1', 'eventKey': eventKey},
            isWorker: false,
          );
          expect(route, '/client/track/booking-1');
        });
      }
    });

    test('entityType booking + entityId is equivalent to bookingId', () {
      final route = NotificationNavigator.resolveRoute(
        {'entityType': 'booking', 'entityId': 'booking-9', 'eventKey': 'booking.completed'},
        isWorker: false,
      );
      expect(route, '/client/booking/booking-9');
    });
  });

  group('explicit route fallback (precedence #3)', () {
    test('worker.auto_offline (no bookingId/conversationId) falls back to the payload route', () {
      final route = NotificationNavigator.resolveRoute(
        {'eventKey': 'worker.auto_offline', 'route': '/worker/home'},
        isWorker: true,
      );
      expect(route, '/worker/home');
    });

    test('an unrecognized eventKey with no ids and no route resolves to null (safe no-op, not a crash)', () {
      final route = NotificationNavigator.resolveRoute(
        {'eventKey': 'some.future.event'},
        isWorker: false,
      );
      expect(route, isNull);
    });

    test('a malformed/empty payload resolves to null', () {
      final route = NotificationNavigator.resolveRoute({}, isWorker: false);
      expect(route, isNull);
    });
  });

  group('role safety', () {
    test('the SAME payload routes a Worker and a Client to their own namespace, never the other role\'s', () {
      final payload = {'bookingId': 'booking-1', 'eventKey': 'booking.assigned'};
      final workerRoute = NotificationNavigator.resolveRoute(payload, isWorker: true);
      final clientRoute = NotificationNavigator.resolveRoute(payload, isWorker: false);
      expect(workerRoute, '/worker/job/booking-1');
      expect(clientRoute, '/client/track/booking-1');
      expect(workerRoute, isNot(contains('/client/')));
      expect(clientRoute, isNot(contains('/worker/')));
    });
  });
}
