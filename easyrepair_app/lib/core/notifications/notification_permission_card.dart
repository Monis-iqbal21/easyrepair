import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

import '../l10n/l10n_extensions.dart';
import 'notification_permission_service.dart';

/// Non-blocking Profile/Settings row shown only when notification
/// permission needs attention — renders nothing when already granted, and is
/// never shown as a startup modal (it only appears when the user is already
/// on the page that hosts it, and is re-checked on every visit rather than
/// polled).
class NotificationPermissionCard extends ConsumerWidget {
  const NotificationPermissionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(notificationPermissionStateProvider);
    final state = stateAsync.valueOrNull;
    if (state == null || state == NotificationPermissionState.granted) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final isPermanentlyDenied =
        state == NotificationPermissionState.permanentlyDenied;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_off_outlined,
              size: 20, color: Color(0xFFB45309)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.notificationsPermissionOffMessage,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    if (isPermanentlyDenied) {
                      await openAppSettings();
                    } else {
                      await requestNotificationPermission();
                    }
                    ref.invalidate(notificationPermissionStateProvider);
                  },
                  child: Text(
                    isPermanentlyDenied
                        ? l10n.commonOpenSettings
                        : l10n.notificationsAllowAction,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
