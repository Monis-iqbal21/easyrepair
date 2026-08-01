import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/l10n/l10n_extensions.dart';

/// Requests camera, microphone, and location-when-in-use permissions once per
/// app session. Call [maybeRequest] after the user is authenticated.
class AppPermissionService {
  AppPermissionService._();
  static final instance = AppPermissionService._();

  bool _askedThisSession = false;

  static const _permissions = [
    Permission.camera,
    Permission.microphone,
    Permission.locationWhenInUse,
  ];

  Future<void> maybeRequest(BuildContext context) async {
    if (_askedThisSession) return;
    _askedThisSession = true;

    // Check current statuses without requesting.
    final statuses = {
      for (final p in _permissions) p: await p.status,
    };

    final missing = statuses.entries
        .where((e) =>
            e.value != PermissionStatus.granted &&
            e.value != PermissionStatus.limited)
        .map((e) => e.key)
        .toList();

    if (missing.isEmpty) return; // all already granted

    if (!context.mounted) return;

    // Show explanation before triggering OS dialogs.
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PermissionExplainDialog(),
    );
    if (proceed != true || !context.mounted) return;

    // Request only the missing ones — OS shows dialogs in sequence.
    final results = await missing.request();

    // If any permanently denied, offer Settings.
    final permanentlyDenied =
        results.values.any((s) => s == PermissionStatus.permanentlyDenied);

    if (permanentlyDenied && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => const _OpenSettingsDialog(),
      );
    }
  }

  void reset() => _askedThisSession = false;
}

// ── Explanation dialog ────────────────────────────────────────────────────────

class _PermissionExplainDialog extends StatelessWidget {
  const _PermissionExplainDialog();

  static const _brand = Color(0xFFDB6234);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        context.l10n.permissionsTitle,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      content: Text(
        context.l10n.permissionsRationale,
        style: TextStyle(fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            context.l10n.commonNotNow,
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _brand,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(context.l10n.commonContinue),
        ),
      ],
    );
  }
}

// ── Permanently-denied dialog ─────────────────────────────────────────────────

class _OpenSettingsDialog extends StatelessWidget {
  const _OpenSettingsDialog();

  static const _brand = Color(0xFFDB6234);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        context.l10n.permissionsBlockedTitle,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      content: Text(
        context.l10n.permissionsBlockedBody,
        style: TextStyle(fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            context.l10n.commonNotNow,
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            openAppSettings();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _brand,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(context.l10n.commonOpenSettings),
        ),
      ],
    );
  }
}
