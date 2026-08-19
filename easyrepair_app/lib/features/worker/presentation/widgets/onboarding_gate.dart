import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/worker_providers.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import 'onboarding_routes.dart';

/// Gate for worker actions that require an APPROVED profile (bid, apply,
/// go online). Shows the required bilingual message and returns false if the
/// worker isn't approved yet; returns true and does nothing otherwise, so
/// callers can write `if (!ensureApprovedOrWarn(context, ref)) return;`.
/// The backend independently enforces this too — this is just so the worker
/// gets an immediate, clear message instead of a network round-trip failure.
bool ensureApprovedOrWarn(BuildContext context, WidgetRef ref) {
  final profile = ref.read(workerProfileProvider).valueOrNull;
  if (profile != null && !profile.isOnboardingApproved) {
    // Both states block the action, but for opposite reasons — one is "you
    // still have forms to fill in", the other "an admin has not looked yet".
    // Telling a submitted Ustaad to go and complete their profile is what
    // sends them hunting for work that does not exist.
    final message = profile.isPendingReview
        ? context.l10n.workerPendingReviewBody
        : context.l10n.workerApprovalRequired;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.semanticColors.error,
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
/// itself doesn't error, an unapproved profile has nothing meaningful to
/// list).
///
/// It reads the profile rather than only a message, because the two reasons a
/// list is empty need different endings: an Ustaad who still owes us forms
/// gets a button to go and fill them in, while one whose profile is sitting in
/// the admin queue gets an explanation and nothing to press. Offering the
/// second group a "complete your profile" button is what sends them back into
/// a form the backend will not accept edits from.
class ProfileIncompleteState extends ConsumerWidget {
  /// The already-localized explanation for the action-required case.
  final String message;

  const ProfileIncompleteState({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.semanticColors;
    final profile = ref.watch(workerProfileProvider).valueOrNull;
    final pending = profile?.isPendingReview ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: pending ? colors.softTeal : colors.urgentSoft,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  pending
                      ? Icons.hourglass_top_rounded
                      : Icons.assignment_late_outlined,
                  color: pending ? colors.primary : colors.urgent,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (pending) ...[
              Text(
                context.l10n.workerPendingReviewTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.workerPendingReviewBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: colors.textSecondary,
                ),
              ),
            ] else ...[
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push(
                    profile == null
                        ? legacyProfileCompletionRoute
                        : resumeOnboardingRoute(profile),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    context.l10n.workerCompleteProfile,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
