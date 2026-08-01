import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/worker_providers.dart';
import '../../../../core/l10n/l10n_extensions.dart';

const _kOrange = Color(0xFFDB6234);
const _kDark = Color(0xFF1A1A1A);

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
      SnackBar(
        content: Text(context.l10n.workerApprovalRequired),
        backgroundColor: Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  }
  return true;
}

/// Full-panel replacement for a list's loading/data/error content when the
/// worker's profile isn't APPROVED yet — shown instead of "Something went
/// wrong" (New Jobs' own fetch would otherwise 403, and even where the fetch
/// itself doesn't error, an incomplete profile has nothing meaningful to
/// list). [message] is the already-localized explanation — this used to be a
/// fixed Roman-Urdu line plus an Urdu one, which the language selector makes
/// redundant. The button always opens the profile-completion page.
class ProfileIncompleteState extends StatelessWidget {
  final String message;

  const ProfileIncompleteState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0EB),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.assignment_late_outlined, color: _kOrange, size: 32),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _kDark, height: 1.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/worker/profile-completion'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.workerCompleteProfile, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
