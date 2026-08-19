import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/widgets/handygo_brand_lockup.dart';

/// The logged-out landing screen — HandyGo's branded welcome.
///
/// Shown only when [resolveAuthRedirect] has confirmed there is no session
/// (see `core/router/app_router.dart`). It has no timers and no auth logic of
/// its own: it stays put until the Ustaad/Client taps "Shuru karein", which
/// opens the onboarding language step (`/auth/language`); that screen then
/// hands off to the EXISTING role-selection screen at `/auth/role-select`.
/// An already-authenticated user is dispatched to their home by the router
/// and never sees this page.
///
/// ## Composition
///
/// A full-bleed [AppSemanticColors.primary] canvas carrying the
/// [HandyGoBrandLockup] — wrench, "HandyGo", "Har maslay ka ustaad" — with
/// the CTA anchored low. The previous decorative artwork
/// (`assets/images/background.png`) and the baked-in logo lockup
/// (`assets/images/handygo_logo.png`) are deliberately not used here: the
/// wordmark and tagline are now real text, so they scale with the device and
/// the user's text-size setting.
///
/// ## Colour architecture
///
/// Every Flutter-drawn pixel here reads from [AppSemanticColors]. There is
/// deliberately not a single brand hex literal in this file, so a palette
/// change — or the light/dark switch — is a change to
/// `core/theme/app_semantic_colors.dart` alone. The only literal is
/// `Colors.transparent` for the status-bar overlay, which is a platform
/// value ("do not tint the system bar"), not a colour choice.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  /// Where "Shuru karein" leads: the onboarding language step, which then
  /// hands off to the existing Client/Ustaad role picker.
  static const languageRoute = '/auth/language';

  /// The wrench mark. Re-exported from [HandyGoBrandLockup] so the splash
  /// screen and the tests have one name to reference.
  static const logoAsset = HandyGoBrandLockup.wrenchAsset;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The canvas is a dark brand teal, so the OS bars need light icons. Set
      // here rather than globally so no other screen's chrome is affected.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // Android
        statusBarBrightness: Brightness.dark, // iOS
        systemNavigationBarColor: colors.primary,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        // Fills the WHOLE window, including behind the status/navigation bars,
        // so SafeArea insets the content without framing the screen in the
        // page background colour.
        backgroundColor: colors.primary,
        body: SafeArea(child: _WelcomeContent(colors: colors)),
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

        // The lockup and the CTA stay a comfortable phone width even on a
        // tablet or a landscape window, rather than stretching edge to edge.
        final contentWidth = usableWidth > 460.0 ? 460.0 : usableWidth;

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
                    SizedBox(
                      width: contentWidth,
                      child: HandyGoBrandLockup(
                        widthBudget: contentWidth,
                        heightBudget: maxHeight,
                      ),
                    ),
                    // Larger gap below the lockup so it reads slightly above
                    // the optical centre, with the CTA anchored low.
                    const Spacer(flex: 5),
                    SizedBox(
                      width: contentWidth,
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
/// would change every existing auth screen — out of scope here.
///
/// Because the page itself is filled with [AppSemanticColors.primary], a
/// primary-filled button would vanish into it. The inverse pairing is used
/// instead — a [AppSemanticColors.surface] fill with a `primary` label — which
/// is the highest-contrast treatment the palette offers in either brightness,
/// and still names nothing but tokens.
class _ShuruKareinButton extends StatelessWidget {
  const _ShuruKareinButton({required this.colors});

  final AppSemanticColors colors;

  // l10n-ignore: Fixed Roman Urdu brand CTA, identical in every supported
  // language — the same treatment as the "Har maslay ka ustaad" tagline.
  static const _label = 'Shuru karein';

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      // push, not go: the language step is a forward move the user can back
      // out of, so Android/iOS Back returns here rather than exiting.
      onPressed: () => context.push(WelcomePage.languageRoute),
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.surface,
        foregroundColor: colors.primary,
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
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
