import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/presentation/pages/welcome_page.dart';
import '../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/theme/app_semantic_colors.dart';

/// Shown only while the session check has no answer yet — see
/// [resolveAuthRedirect]. It resolves auth, it does not land anyone: a
/// confirmed session goes to the right home, and a confirmed logout goes to
/// [WelcomePage]. There are no timers here and never should be.
///
/// It renders the SAME branded background and the SAME centred logo as the
/// welcome screen, at the same size and position, so the sequence
/// native launch screen → splash → welcome shows no flash and no logo jump:
/// only the button fades in at the end. The one thing that differs is what
/// sits below the logo — a spinner while resolving, or a Retry when the very
/// first check failed outright.
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
    final showRetry = authState.hasError && !authState.hasValue;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Android
        statusBarBrightness: Brightness.light, // iOS
        systemNavigationBarColor: colors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.background,
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                WelcomePage.backgroundAsset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                excludeFromSemantics: true,
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final maxHeight = constraints.maxHeight;
                  final sidePadding = maxWidth < 340 ? 20.0 : 28.0;
                  final usableWidth = maxWidth - sidePadding * 2;

                  // Identical sizing maths to WelcomePage, so the logo does
                  // not resize or move when this screen hands over to it.
                  final widthCap = (usableWidth * 0.84).clamp(0.0, 420.0);
                  final heightCap = maxHeight * 0.30;
                  final logoWidth =
                      widthCap < heightCap * WelcomePage.logoAspectRatio
                          ? widthCap
                          : heightCap * WelcomePage.logoAspectRatio;

                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: maxHeight),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: sidePadding),
                          child: Column(
                            children: [
                              const Spacer(flex: 4),
                              Semantics(
                                label: 'HandyGo',
                                image: true,
                                child: SizedBox(
                                  width: logoWidth,
                                  child: AspectRatio(
                                    aspectRatio: WelcomePage.logoAspectRatio,
                                    child: Image.asset(
                                      WelcomePage.logoAsset,
                                      fit: BoxFit.contain,
                                      excludeFromSemantics: true,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(flex: 5),
                              if (showRetry)
                                _RetryBlock(
                                  colors: colors,
                                  error: authState.error,
                                  onRetry: () =>
                                      ref.invalidate(authStateProvider),
                                )
                              else
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colors.primary,
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
          ],
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
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
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
