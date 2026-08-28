import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/presentation/pages/welcome_page.dart';
import '../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/widgets/handygo_brand_lockup.dart';

/// Shown only while the session check has no answer yet — see
/// [resolveAuthRedirect]. It resolves auth, it does not land anyone: a
/// confirmed session goes to the right home, and a confirmed logout goes to
/// [WelcomePage]. There are no timers here and never should be.
///
/// It renders the SAME full-bleed primary canvas and the SAME
/// [HandyGoBrandLockup] as the welcome screen, at the same size and position,
/// so the sequence native launch screen → splash → welcome shows no flash and
/// no logo jump: only the button fades in at the end. The one thing that
/// differs is what sits below the lockup — a spinner while resolving, or a
/// Retry when the very first check failed outright.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final colors = context.semanticColors;

    // A transient failure (no internet, timeout, backend 5xx) on the very
    // first session check, with nothing previously confirmed to fall back
    // on — see AuthStateNotifier and app_router.dart's redirect. This never
    // means the session was destroyed; it just couldn't be confirmed yet,
    // so offer a retry instead of guessing either way.
    //
    // Only reachable when this device actually HOLDS a stored session:
    // AuthStateNotifier resolves "no stored session" to `null` without
    // making a request, so a logged-out or fresh install goes to the welcome
    // screen and can never be parked here behind a Retry it cannot satisfy.
    final showRetry = authState.hasError && !authState.hasValue;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // Android
        statusBarBrightness: Brightness.dark, // iOS
        systemNavigationBarColor: colors.primary,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: colors.primary,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final maxHeight = constraints.maxHeight;
              final sidePadding = maxWidth < 340 ? 20.0 : 28.0;
              final usableWidth = maxWidth - sidePadding * 2;

              // Identical sizing maths to WelcomePage, so the lockup does not
              // resize or move when this screen hands over to it.
              final contentWidth =
                  usableWidth > 460.0 ? 460.0 : usableWidth;

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: sidePadding),
                      child: Column(
                        children: [
                          const Spacer(flex: 4),
                          SizedBox(
                            width: contentWidth,
                            child: HandyGoBrandLockup(
                              widthBudget: contentWidth,
                              heightBudget: maxHeight,
                            ),
                          ),
                          const Spacer(flex: 5),
                          if (showRetry)
                            _RetryBlock(
                              colors: colors,
                              error: authState.error,
                              onRetry: () => ref.invalidate(authStateProvider),
                            )
                          else
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colors.onPrimary,
                                ),
                                strokeWidth: 2.5,
                              ),
                            ),
                          SizedBox(height: maxHeight < 620 ? 16 : 28),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// First-load failure state: the message plus a Retry that re-runs the session
/// check in place. Deliberately never guesses "logged out" from a network
/// blip — see [SplashPage].
class _RetryBlock extends StatelessWidget {
  const _RetryBlock({
    required this.colors,
    required this.error,
    required this.onRetry,
  });

  final AppSemanticColors colors;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          failureMessage(context.l10n, error),
          textAlign: TextAlign.center,
          // On the primary canvas the on-primary token is the readable one;
          // textSecondary is for content sitting on background/surface.
          style: TextStyle(fontSize: 14, color: colors.onPrimary),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onRetry,
          // Same inverse pairing as the welcome CTA: a primary-filled button
          // would disappear into the primary canvas behind it.
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.surface,
            foregroundColor: colors.primary,
            elevation: 0,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          ),
          child: Text(context.l10n.commonRetry),
        ),
      ],
    );
  }
}
