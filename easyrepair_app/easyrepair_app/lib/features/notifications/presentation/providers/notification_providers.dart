import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/notification_repository_impl.dart';
import '../../domain/entities/notification_entity.dart';

// ── Notification list notifier ────────────────────────────────────────────────

class NotificationsNotifier
    extends AsyncNotifier<List<NotificationEntity>> {
  @override
  Future<List<NotificationEntity>> build() async {
    final result =
        await ref.read(notificationRepositoryProvider).getNotifications();
    return result.fold((f) => throw f, (list) => list);
  }

  Future<void> markRead(String id) async {
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
