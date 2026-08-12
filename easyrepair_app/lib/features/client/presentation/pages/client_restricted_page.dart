import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/utils/support_contact.dart';

const _kOrange = Color(0xFFDB6234);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);
const _kBg = Color(0xFFF9FAFB);
const _kRed = Color(0xFFEF4444);

/// Full-screen lock for `AccountStatus.SUSPENDED` — the ONLY page a
/// restricted Client can ever see. Mirrors `WorkerSuspendedPage` exactly
/// (same wording — see `arb_parity_test.dart`'s "no two English keys carry
/// the same text" rule, which is why this reuses `workerSuspendedMessage`/
/// `workerSuspendedContactSupport` rather than duplicating a new key with
/// identical text).
///
/// Enforcement lives entirely in `app_router.dart`'s
/// `resolveClientRestrictedRedirect`: every Client route, deep link and
/// notification tap navigates through GoRouter, so that one central check is
/// what makes Home/Bookings/Chat/Post-Job/Profile/Notifications/bottom-nav
/// all unreachable — this page itself has no navigation into any of them.
///
/// Genuinely non-dismissible, mirroring WorkerSuspendedPage/
/// CustomerAgreementGatePage:
///  * `PopScope(canPop: false)` swallows Android/system back.
///  * No AppBar, no bottom nav, no close button.
///  * The only ways off this screen are Logout, or an admin reactivating the
///    account (the next authStateProvider refresh redirects away — see the
///    router).
class ClientRestrictedPage extends ConsumerWidget {
  const ClientRestrictedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _kBg,
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
                    color: _kRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.block_rounded,
                    color: _kRed,
                    size: 42,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.workerSuspendedMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.5,
                    color: _kDark,
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
                      backgroundColor: _kOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
                      foregroundColor: _kGray,
                      side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
