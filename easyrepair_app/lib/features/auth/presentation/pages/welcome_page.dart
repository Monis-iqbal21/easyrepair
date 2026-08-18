import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_semantic_colors.dart';

/// The logged-out landing screen — HandyGo's branded welcome.
///
/// Shown only when [resolveAuthRedirect] has confirmed there is no session
/// (see `core/router/app_router.dart`). It has no timers and no auth logic of
/// its own: it stays put until the Ustaad/Client taps "Shuru karein", which
/// hands off to the EXISTING role-selection screen at `/auth/role-select`.
/// An already-authenticated user is dispatched to their home by the router
/// and never sees this page.
///
/// ## Colour architecture
///
/// Every Flutter-drawn pixel here reads from [AppSemanticColors]. There is
/// deliberately not a single brand hex literal in this file, so choosing the
/// final HandyGo palette — or adding a dark theme — is a change to
/// `core/theme/app_semantic_colors.dart` alone. The only literal is
/// `Colors.transparent` for the status-bar overlay, which is a platform
/// value ("do not tint the system bar"), not a colour choice.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  /// Full-bleed branded artwork. Decoration only — nothing is positioned
  /// relative to its contents.
  static const backgroundAsset = 'assets/images/background.png';

  /// The complete lockup: icon, "HandyGo" wordmark, "(Private) Limited" and
  /// the "Har maslay ka ustaad" tagline. Never rebuilt as Flutter text.
  static const logoAsset = 'assets/images/handygo_logo.png';

  /// The asset is 1536x1024. Its own transparent padding means the visible
  /// mark occupies ~75% of that box, which the sizing below accounts for.
  static const logoAspectRatio = 1536 / 1024;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The artwork is light, so the OS bars need dark icons. Set here rather
      // than globally so no other screen's chrome is affected.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Android
        statusBarBrightness: Brightness.light, // iOS
        systemNavigationBarColor: colors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        // Shows for the frame or two before the artwork decodes, and behind
        // any edge the artwork does not cover — never a white/black flash.
        backgroundColor: colors.background,
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                backgroundAsset,
                fit: BoxFit.cover,
                // The skyline is the distinctive part of the artwork and sits
                // at the top; anchoring there keeps it intact and lets the
                // plain lower canvas absorb the crop on shorter/wider screens.
                alignment: Alignment.topCenter,
                // Decorative: the page's meaning comes from the logo and the
                // button, so screen readers should skip it entirely.
                excludeFromSemantics: true,
              ),
            ),
            SafeArea(child: _WelcomeContent(colors: colors)),
          ],
        ),
      ),
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({required this.colors});

  final AppSemanticColors colors;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;

        // Horizontal breathing room, tightened on very narrow phones.
        final sidePadding = maxWidth < 340 ? 20.0 : 28.0;
        final usableWidth = maxWidth - sidePadding * 2;

        // Logo: bounded by BOTH the available width and the available height,
        // so it can never crowd the button on a short screen nor balloon on a
        // tablet. `contain` + a fixed AspectRatio keeps it undistorted.
        final widthCap = (usableWidth * 0.84).clamp(0.0, 420.0);
        final heightCap = maxHeight * 0.30;
        final logoWidth =
            widthCap < heightCap * WelcomePage.logoAspectRatio
                ? widthCap
                : heightCap * WelcomePage.logoAspectRatio;

        // Buttons stay a comfortable mobile width even on tablets.
        final actionWidth = usableWidth > 460.0 ? 460.0 : usableWidth;

        // Scroll only kicks in when the content genuinely cannot fit (a very
        // short screen at a very large text scale). Above that threshold the
        // Spacers below distribute the slack, so the layout breathes on tall
        // screens and compresses on short ones — and RenderFlex can never
        // overflow either way.
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: sidePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Top negative space.
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
                    // Larger gap below the logo so it reads slightly above the
                    // optical centre, with the CTA anchored low.
                    const Spacer(flex: 5),
                    SizedBox(
                      width: actionWidth,
                      child: _ShuruKareinButton(colors: colors),
                    ),
                    SizedBox(height: maxHeight < 620 ? 16 : 28),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The welcome CTA.
///
/// Composed locally rather than reusing `AuthPrimaryButton`: that widget has
/// no trailing-icon slot and hardcodes its brand colours, and re-styling it
/// would change every existing auth screen — out of scope here. The colours
/// below come from [AppSemanticColors], which is the part that matters.
class _ShuruKareinButton extends StatelessWidget {
  const _ShuruKareinButton({required this.colors});

  final AppSemanticColors colors;

  // l10n-ignore: Fixed Roman Urdu brand CTA, identical in every supported
  // language — the same treatment as the "Har maslay ka ustaad" tagline that
  // is baked into the logo artwork.
  static const _label = 'Shuru karein';

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => context.go('/auth/role-select'),
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: colors.disabled,
        elevation: 0,
        // Grows with the text scale instead of clipping; never below the
        // 48dp accessible minimum.
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            // Reserves the arrow's gutter on both sides so the label stays
            // optically centred and can never run underneath the icon.
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 22,
              // Inherits the button's foregroundColor, but stated explicitly
              // so the token dependency is visible at the call site.
              color: colors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
