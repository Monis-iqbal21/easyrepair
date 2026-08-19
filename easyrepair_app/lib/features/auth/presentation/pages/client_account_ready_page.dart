import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../providers/auth_providers.dart';
import '../widgets/client_auth_widgets.dart';

/// SCREEN 4 — Client registration success.
///
/// ## Why it lives under `/client`
///
/// By the time this shows, the account exists and the session is live. Every
/// `/auth/...` location is a "logged-out route" to the router, so an
/// authenticated user sitting on one is dispatched to their home — which is
/// exactly right, and exactly why this screen is NOT under `/auth`. Placed
/// under `/client` it is simply a normal authenticated Client route: no
/// redirect rule was added, changed or exempted, and a logged-out visitor is
/// still sent to `/welcome` by the same untouched rule.
///
/// ## Where the details come from
///
/// The confirmed session ([authStateProvider]) is the source of truth for the
/// name and number. The values the user just typed are carried in as
/// [ClientAccountSummary] and used only until `/auth/me` resolves, so the card
/// is populated on the very first frame instead of flashing empty — it is a
/// fallback, never a substitute.
class ClientAccountReadyPage extends ConsumerWidget {
  const ClientAccountReadyPage({super.key, this.summary});

  static const route = '/client/account-ready';

  final ClientAccountSummary? summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.semanticColors;
    final user = ref.watch(authStateProvider).valueOrNull;

    // UserEntity carries the split name; the card shows the whole thing.
    final sessionName =
        [user?.firstName, user?.lastName].whereType<String>().join(' ').trim();
    final name = sessionName.isNotEmpty
        ? sessionName
        : (summary?.fullName.trim() ?? '');
    final phone = formatPkNationalPhone(user?.phone ?? summary?.phone ?? '');

    return ClientAuthScaffold(
      footer: ClientPrimaryButton(
        label: l10n.authClientGoHome,
        isLoading: false,
        // The existing authenticated Client home route — `go`, not `push`, so
        // the finished onboarding flow is not left on the stack behind Home.
        onPressed: () => context.go('/client/home'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: colors.softTeal,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 54,
                color: colors.success,
              ),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            l10n.authClientReadyHeading,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.authClientReadySubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 26),
          _AccountCard(name: name, phone: phone),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.semanticColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.authClientAccountCardLabel,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            // The number is Latin digits and must stay left-to-right in every
            // language; the role follows it after a middot, as in the design.
            '$kPkDialCode $phone · ${l10n.authClientRoleCustomer}',
            textDirection: TextDirection.ltr,
            style: TextStyle(fontSize: 15, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The name and number the registration flow just used, so the card renders
/// before the refreshed session arrives. See [ClientAccountReadyPage].
class ClientAccountSummary {
  const ClientAccountSummary({required this.fullName, required this.phone});

  final String fullName;
  final String phone;
}
