import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/utils/support_contact.dart';

/// Full-screen lock for `WorkerStatus.SUSPENDED` — the ONLY page a suspended
/// Ustaad can ever see.
///
/// Enforcement lives entirely in `app_router.dart`'s
/// `resolveWorkerSuspendedRedirect`: every Worker route, deep link and
/// notification tap navigates through GoRouter, so that one central check is
/// what makes Home/Jobs/Chat/Earnings/Profile/Notifications/bottom-nav all
/// unreachable — this page itself has no navigation into any of them.
///
/// Genuinely non-dismissible, mirroring CustomerAgreementGatePage:
///  * `PopScope(canPop: false)` swallows Android/system back.
///  * No AppBar, no bottom nav, no close button.
///  * The only ways off this screen are Logout, or an admin restoring the
///    account (the next authStateProvider refresh redirects away — see the
///    router).
class WorkerSuspendedPage extends ConsumerWidget {
  const WorkerSuspendedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    // The tint that pairs with `error`, straight from the
                    // palette — not `error` faded, which is not a colour the
                    // palette owns.
                    color: c.urgentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.block_rounded, color: c.error, size: 42),
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.workerSuspendedMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.5,
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => launchSupportCall(),
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: Text(context.l10n.workerSuspendedContactSupport),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(logoutNotifierProvider.notifier).logout(),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(context.l10n.commonLogout),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.textPrimary,
                      side: BorderSide(color: c.border),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
