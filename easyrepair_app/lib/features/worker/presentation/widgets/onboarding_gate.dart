import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/worker_providers.dart';

/// Gate for worker actions that require an APPROVED profile (bid, apply,
/// go online). Shows the required bilingual message and returns false if the
/// worker isn't approved yet; returns true and does nothing otherwise, so
/// callers can write `if (!ensureApprovedOrWarn(context, ref)) return;`.
/// The backend independently enforces this too — this is just so the worker
/// gets an immediate, clear message instead of a network round-trip failure.
bool ensureApprovedOrWarn(BuildContext context, WidgetRef ref) {
  final profile = ref.read(workerProfileProvider).valueOrNull;
  if (profile != null && !profile.isOnboardingApproved) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Profile approval required before receiving jobs.\n'
          'Jobs hasil karne ke liye pehle profile approval zaroori hai.',
        ),
        backgroundColor: Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  }
  return true;
}
