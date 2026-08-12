import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n_extensions.dart';

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
void showSupportOptionsSheet(
  BuildContext context, {
  required bool isWorker,
}) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline_rounded),
            title: Text(sheetContext.l10n.settingsSupportTitle),
            onTap: () {
              Navigator.of(sheetContext).pop();
              sheetContext.push(isWorker ? '/worker/chat' : '/client/chat');
            },
          ),
          ListTile(
            leading: const Icon(Icons.call_outlined),
            title: Text(sheetContext.l10n.workerSuspendedContactSupport),
            subtitle: const Text(kSupportPhoneNumber),
            onTap: () {
              Navigator.of(sheetContext).pop();
              launchSupportCall();
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
