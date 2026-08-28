import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

import '../l10n/l10n_extensions.dart';
import '../theme/app_semantic_colors.dart';
import 'notification_permission_service.dart';

/// Non-blocking Profile/Settings row shown only when notification
/// permission needs attention — renders nothing when already granted, and is
/// never shown as a startup modal (it only appears when the user is already
/// on the page that hosts it, and is re-checked on every visit rather than
/// polled).
///
/// SHARED: sits at the top of both the Client and the Ustaad profile
/// settings list, identically. The #FFF7ED / #FED7AA / #B45309 / #92400E
/// amber it used to hardcode is the `warning` pairing the design system
/// already names; the action is now a real button-sized tap target rather
/// than bare text.
class NotificationPermissionCard extends ConsumerWidget {
  const NotificationPermissionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
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
        color: c.warningSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_off_outlined, size: 20, color: c.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.notificationsPermissionOffMessage,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    if (isPermanentlyDenied) {
                      await openAppSettings();
                    } else {
                      await requestNotificationPermission();
                    }
                    ref.invalidate(notificationPermissionStateProvider);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 10,
                    ),
                    child: Text(
                      isPermanentlyDenied
                          ? l10n.commonOpenSettings
                          : l10n.notificationsAllowAction,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.warning,
                      ),
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
