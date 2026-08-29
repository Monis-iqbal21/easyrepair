import 'package:flutter/material.dart';
import 'onboarding_routes.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';

/// Shown when a logged-in Ustaad's onboarding isn't APPROVED yet — on first
/// Worker Home load per app session (see [onboardingModalShownProvider]).
/// Has a close button; the worker can always reach the same destination
/// later via the persistent banner on Worker Home.
/// [route] is where the CTA goes — the caller decides, because only it knows
/// whether this Ustaad can resume the new registration at Step 4 or needs the
/// legacy form. See `resumeOnboardingRoute`.
Future<void> showProfileCompletionModal(
  BuildContext context, {
  String route = legacyProfileCompletionRoute,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final c = ctx.semanticColors;
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.softTeal,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.assignment_ind_outlined,
                      color: c.primary,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Icon(
                      Icons.close_rounded,
                      color: c.textSecondary,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.workerCompleteProfileDetails,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.workerCompleteProfileWhy,
                style: TextStyle(
                  fontSize: 13.5,
                  color: c.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push(route);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: c.onPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        context.l10n.workerCompleteProfile,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
