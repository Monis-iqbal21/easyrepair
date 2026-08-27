import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/network/offline_banner.dart';
import '../../../../core/network/reconnect_refresh.dart';
import '../../../../core/notifications/notification_navigator.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/notification_entity.dart';
import '../providers/notification_providers.dart';

class NotificationListPage extends ConsumerWidget {
  const NotificationListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.semanticColors;
    final markAllMaxWidth = (MediaQuery.sizeOf(context).width * 0.44)
        .clamp(132.0, 180.0)
        .toDouble();
    final notificationsAsync = ref.watch(notificationsProvider);
    final isShowingCachedData =
        ref.watch(notificationsIsOfflineProvider) &&
        notificationsAsync.hasValue;

    // Reconnect refetches the authoritative list — including read state,
    // which is never mutated locally while offline.
    refreshOnReconnect(
      ref,
      () => ref.read(notificationsProvider.notifier).refresh(),
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: colors.surface,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Text(
          context.l10n.notificationsTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 20,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          notificationsAsync.maybeWhen(
            data: (notifications) {
              final hasUnread = notifications.any(
                (notification) => !notification.isRead,
              );
              if (!hasUnread) return const SizedBox.shrink();

              return ConstrainedBox(
                constraints: BoxConstraints(maxWidth: markAllMaxWidth),
                child: TextButton(
                  key: const Key('notifications-mark-all-read'),
                  onPressed: () =>
                      ref.read(notificationsProvider.notifier).markAllRead(),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(
                    context.l10n.notificationsMarkAllRead,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: colors.border, height: 1),
        ),
      ),
      body: Column(
        children: [
          if (isShowingCachedData) const OfflineDataBanner(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: notificationsAsync.when(
                  // Keep the cached list on screen when a background refresh
                  // fails rather than replacing it with a full-page error.
                  skipError: true,
                  loading: () => _LoadingState(color: colors.primary),
                  error: (error, _) => _ErrorState(
                    message: failureMessage(context.l10n, error),
                    onRetry: () => ref.invalidate(notificationsProvider),
                  ),
                  data: (notifications) => notifications.isEmpty
                      ? const _EmptyState()
                      : RefreshIndicator(
                          color: colors.primary,
                          backgroundColor: colors.surface,
                          onRefresh: () => ref
                              .read(notificationsProvider.notifier)
                              .refresh(),
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                            itemCount: notifications.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (itemContext, index) {
                              final notification = notifications[index];
                              return _NotificationCard(
                                key: ValueKey(
                                  'notification-card-${notification.id}',
                                ),
                                notification: notification,
                                onTap: () =>
                                    _handleTap(itemContext, ref, notification),
                              );
                            },
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification,
  ) {
    if (!notification.isRead) {
      ref.read(notificationsProvider.notifier).markRead(notification.id);
    }

    final user = ref.read(authStateProvider).valueOrNull;
    final isWorker = user?.isWorker ?? false;

    // Build the same data shape used by FCM so the centralized navigator
    // remains the only place that decides notification destinations.
    final data = <String, dynamic>{
      if (notification.eventKey != null) 'eventKey': notification.eventKey,
      if (notification.entityType != null)
        'entityType': notification.entityType,
      if (notification.entityId != null) 'entityId': notification.entityId,
      if (notification.bookingId != null) 'bookingId': notification.bookingId,
      if (notification.route != null) 'route': notification.route,
    };

    final destination = NotificationNavigator.resolveRoute(
      data,
      isWorker: isWorker,
    );
    if (destination != null && destination.isNotEmpty) {
      context.push(destination);
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final NotificationEntity notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final isUnread = !notification.isRead;

    return Material(
      color: isUnread ? colors.softTeal : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isUnread ? colors.primary : colors.border,
          width: isUnread ? 1.2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isUnread ? colors.surface : colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Icon(
                  _iconForEvent(notification.eventKey),
                  size: 19,
                  color: isUnread ? colors.primary : colors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14.5,
                              height: 1.25,
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isUnread) ...[
                                Container(
                                  key: ValueKey(
                                    'notification-unread-indicator-${notification.id}',
                                  ),
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                _formatTime(context, notification.createdAt),
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: TextStyle(
                                  color: isUnread
                                      ? colors.primary
                                      : colors.textSecondary,
                                  fontSize: 11,
                                  height: 1.3,
                                  fontWeight: isUnread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForEvent(String? eventKey) {
    switch (eventKey) {
      case 'bid.received':
        return Icons.local_offer_outlined;
      case 'bid.accepted':
      case 'booking.assigned':
        return Icons.work_outline_rounded;
      case 'booking.status.en_route':
        return Icons.directions_car_outlined;
      case 'booking.status.in_progress':
        return Icons.build_outlined;
      case 'booking.completed':
        return Icons.check_circle_outline_rounded;
      case 'booking.cancelled.by_client':
      case 'booking.cancelled.by_worker':
        return Icons.cancel_outlined;
      case 'booking.review.created':
        return Icons.star_outline_rounded;
      case 'worker.verified':
        return Icons.verified_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatTime(BuildContext context, DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return context.l10n.timeJustNow;
    if (difference.inMinutes < 60) {
      return context.l10n.timeMinutesAgo(difference.inMinutes);
    }
    if (difference.inHours < 24) {
      return context.l10n.timeHoursAgo(difference.inHours);
    }
    return DateFormat('MMM d').format(dateTime);
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(color: color, strokeWidth: 2.5),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 32,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.l10n.notificationsEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 17,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              context.l10n.notificationsEmptySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.errorSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 30,
                color: colors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 140,
              child: OutlinedButton(
                key: const Key('notifications-retry'),
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.controlBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.l10n.commonRetry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
