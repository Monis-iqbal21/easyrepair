import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity_service.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../domain/entities/notification_entity.dart';

// ── Notification list notifier ────────────────────────────────────────────────

/// True while [notificationsProvider] is showing the last cached list because
/// the live fetch could not reach the server — drives the offline banner on
/// the notification list.
final notificationsIsOfflineProvider = StateProvider<bool>((ref) => false);

class NotificationsNotifier
    extends AsyncNotifier<List<NotificationEntity>> {
  @override
  Future<List<NotificationEntity>> build() async {
    final result =
        await ref.read(notificationRepositoryProvider).getNotifications();
    return result.fold((f) => throw f, (cached) {
      ref.read(notificationsIsOfflineProvider.notifier).state = cached.isStale;
      return cached.data;
    });
  }

  /// Background refresh that keeps the current list visible while refetching
  /// (Riverpod's own isRefreshing/copyWithPrevious path) instead of blanking
  /// the page to a spinner.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // Already reflected in state; cached data stays on screen.
    }
  }

  Future<void> markRead(String id) async {
    // Marking read is a WRITE. Offline it is blocked outright rather than
    // applied locally and replayed later — there is deliberately no offline
    // write queue in HandyGo, and the server owns read state.
    if (offlineActionGuard() != null) return;
    final result =
        await ref.read(notificationRepositoryProvider).markRead(id);
    result.fold((_) => null, (_) {
      final current = state.valueOrNull;
      if (current == null) return;
      state = AsyncData(
        current
            .map((n) => n.id == id
                ? NotificationEntity(
                    id: n.id,
                    title: n.title,
                    body: n.body,
                    isRead: true,
                    readAt: DateTime.now(),
                    eventKey: n.eventKey,
                    entityType: n.entityType,
                    entityId: n.entityId,
                    bookingId: n.bookingId,
                    route: n.route,
                    payload: n.payload,
                    createdAt: n.createdAt,
                  )
                : n)
            .toList(),
      );
    });
  }

  Future<void> markAllRead() async {
    // Same rule as markRead — never mutate read state from a stale cache.
    if (offlineActionGuard() != null) return;
    final result =
        await ref.read(notificationRepositoryProvider).markAllRead();
    result.fold((_) => null, (_) {
      final current = state.valueOrNull;
      if (current == null) return;
      final now = DateTime.now();
      state = AsyncData(
        current
            .map((n) => n.isRead
                ? n
                : NotificationEntity(
                    id: n.id,
                    title: n.title,
                    body: n.body,
                    isRead: true,
                    readAt: now,
                    eventKey: n.eventKey,
                    entityType: n.entityType,
                    entityId: n.entityId,
                    bookingId: n.bookingId,
                    route: n.route,
                    payload: n.payload,
                    createdAt: n.createdAt,
                  ))
            .toList(),
      );
    });
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<NotificationEntity>>(
  NotificationsNotifier.new,
);

// ── Unread count ──────────────────────────────────────────────────────────────

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final result =
      await ref.read(notificationRepositoryProvider).getUnreadCount();
  return result.fold((_) => 0, (count) => count);
});
