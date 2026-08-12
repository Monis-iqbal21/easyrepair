import 'package:go_router/go_router.dart';

/// Pure utility for resolving notification data to in-app routes.
/// Navigation logic is centralized here so FCM taps, local notification taps,
/// and in-app list taps all behave consistently.
class NotificationNavigator {
  NotificationNavigator._();

  /// Resolve a role-aware route from a notification data payload.
  ///
  /// Precedence:
  ///   1. conversationId (or entityType == 'conversation') → chat route
  ///   2. bookingId (or entityType == 'booking') → booking/job route
  ///   3. explicit route field (fallback)
  // Notification event keys that should open the Track Worker page for
  // clients — hire/assignment plus the worker's "on the way" update, which
  // is exactly the live-tracking moment this page exists for.
  static const _trackWorkerEventKeys = {
    'bid.accepted',
    'booking.assigned',
    'worker.hired',
    'worker.assigned',
    'booking.status.en_route',
  };

  static String? resolveRoute(
    Map<String, dynamic> data, {
    required bool isWorker,
  }) {
    // 1. Chat conversation
    final conversationId = data['conversationId'] as String?
        ?? (data['entityType'] == 'conversation' ? data['entityId'] as String? : null);
    if (conversationId != null && conversationId.isNotEmpty) {
      return isWorker
          ? '/worker/chat/$conversationId'
          : '/client/chat/$conversationId';
    }

    // 2. Booking / job
    final bookingId = data['bookingId'] as String?
        ?? (data['entityType'] == 'booking' ? data['entityId'] as String? : null);
    if (bookingId != null && bookingId.isNotEmpty) {
      final eventKey = data['eventKey'] as String? ?? '';
      // Client taps a worker-hired/bid-accepted notification → Track Worker page.
      if (!isWorker && _trackWorkerEventKeys.contains(eventKey)) {
        return '/client/track/$bookingId';
      }
      return isWorker
          ? '/worker/job/$bookingId'
          : '/client/booking/$bookingId';
    }

    // 3. Fallback to explicit route
    final route = data['route'] as String?;
    return (route != null && route.isNotEmpty) ? route : null;
  }

  /// Navigate using [GoRouter] without requiring a [BuildContext].
  /// Safe to call from any context including initState callbacks.
  static void navigateByRouter(
    GoRouter router,
    Map<String, dynamic> data, {
    required bool isWorker,
  }) {
    final route = resolveRoute(data, isWorker: isWorker);
    if (route != null) {
      router.go(route);
    }
  }
}
