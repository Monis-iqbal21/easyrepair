import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n_extensions.dart';
import '../theme/app_semantic_colors.dart';

/// HandyGo Support's phone number — the single source of truth for every
/// "Contact Support" affordance that needs to actually dial it (e.g. the
/// Worker-suspended lock screen).
const String kSupportPhoneNumber = '+923320219006';

/// Opens the device's dialer pre-filled with [kSupportPhoneNumber]. Returns
/// whether the dialer was actually launched, so a caller can fall back to
/// showing the number as plain text if the platform refuses (e.g. no
/// telephony capability, as on some tablets/emulators).
Future<bool> launchSupportCall() async {
  final uri = Uri(scheme: 'tel', path: kSupportPhoneNumber);
  try {
    return await launchUrl(uri);
  } catch (e) {
    debugPrint('[SupportContact] failed to launch dialer: $e');
    return false;
  }
}

/// Profile/Settings "Support" row action — a small chooser between the
/// existing HandyGo Support chat thread (already auto-ensured and pinned
/// first in the chat list, see ChatProviders.getConversations /
/// chat_list_page.dart — deliberately NOT re-created here) and a direct
/// phone call. Never creates a new support conversation itself.
///
/// SHARED: opened from both the Client and the Ustaad profile. [isWorker]
/// still picks only the chat *route*; the presentation is identical for both
/// roles. Colour, shape and row metrics moved to the design system here —
/// neither destination changed.
void showSupportOptionsSheet(
  BuildContext context, {
  required bool isWorker,
}) {
  final c = context.semanticColors;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                sheetContext.l10n.settingsSupportTitle,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SupportOption(
              icon: Icons.chat_bubble_outline_rounded,
              title: sheetContext.l10n.settingsSupportTitle,
              onTap: () {
                Navigator.of(sheetContext).pop();
                sheetContext.push(isWorker ? '/worker/chat' : '/client/chat');
              },
            ),
            const SizedBox(height: 8),
            _SupportOption(
              icon: Icons.call_outlined,
              title: sheetContext.l10n.workerSuspendedContactSupport,
              // A phone number is never translated or localised.
              subtitle: kSupportPhoneNumber,
              onTap: () {
                Navigator.of(sheetContext).pop();
                launchSupportCall();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _SupportOption extends StatelessWidget {
  const _SupportOption({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.softTeal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: c.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: c.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            // Icons.chevron_right_rounded declares matchTextDirection.
            Icon(Icons.chevron_right_rounded, size: 20, color: c.textSecondary),
          ],
        ),
      ),
    );
  }
}
