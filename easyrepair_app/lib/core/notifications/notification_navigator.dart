import 'package:go_router/go_router.dart';

/// Pure utility for resolving notification data to in-app routes.
/// Navigation logic is centralized here so FCM taps, local notification taps,
/// and in-app list taps all behave consistently.
class NotificationNavigator {
  NotificationNavigator._();

  /// Resolve a route from a notification data payload.
  /// Precedence: bookingId (role-aware) > explicit route field.
  static String? resolveRoute(
    Map<String, dynamic> data, {
    required bool isWorker,
  }) {
    // Chat message notification → open the conversation directly.
    final eventKey = data['eventKey'] as String?;
    final entityType = data['entityType'] as String?;
    final entityId = data['entityId'] as String?;
    if (eventKey == 'chat.message' &&
        entityType == 'conversation' &&
        entityId != null &&
        entityId.isNotEmpty) {
      return isWorker ? '/worker/chat/$entityId' : '/client/chat/$entityId';
    }

    final bookingId = data['bookingId'] as String?;
    if (bookingId != null && bookingId.isNotEmpty) {
      return isWorker
          ? '/worker/job/$bookingId'
          : '/client/booking/$bookingId';
    }
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
