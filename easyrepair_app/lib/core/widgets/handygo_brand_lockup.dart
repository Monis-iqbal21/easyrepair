import 'package:flutter/material.dart';

import '../theme/app_semantic_colors.dart';

/// HandyGo's startup brand lockup: the approved app logo, the "HandyGo"
/// wordmark and the "Har maslay ka ustaad" tagline, stacked and centred.
///
/// Shared by the loading screen (`SplashPage`) and the logged-out landing
/// screen (`WelcomePage`) so the mark never jumps position or size as one
/// hands over to the other.
///
/// ## Text, not artwork
///
/// The wordmark and tagline are real [Text] widgets. Only the wrench comes
/// from an image ([logoAsset]) — so the type scales with the device and the
/// user's text-size setting instead of pixelating, and screen readers get
/// words rather than a label bolted onto a bitmap.
///
/// ## Colour
///
/// Two marks, one source. Both are lifted from the approved
/// `assets/images/logo-final.png` — a brand-teal tile carrying an off-white
/// wrench — and neither is a recolour or an inversion of it:
///
///  * on the primary teal canvas ([onPrimaryBackground]) the wrench is drawn
///    in its own off-white, straight onto the canvas. Canvas plus mark then
///    reproduce `logo-final.png` exactly, which is what the native launch
///    screens on both platforms show, so startup hands over without a jump.
///  * on light in-app surfaces an off-white mark would be invisible, so the
///    same silhouette is filled with the primary teal instead.
///
/// Text colours come from semantic tokens. Flutter widgets add no raw brand
/// literals.
class HandyGoBrandLockup extends StatelessWidget {
  const HandyGoBrandLockup({
    super.key,
    required this.widthBudget,
    required this.heightBudget,
    this.onPrimaryBackground = false,
    this.colorPalette,
  });

  /// The width and height of the screen area the lockup has to live in.
  ///
  /// Passed in rather than measured with a [LayoutBuilder] of its own, for two
  /// reasons: the lockup sits in a scrolling column whose vertical constraint
  /// is unbounded (measuring would let the mark GROW on a short screen,
  /// exactly where it must shrink), and a `LayoutBuilder` cannot report
  /// intrinsic dimensions, which the surrounding `IntrinsicHeight` needs.
  final double widthBudget;
  final double heightBudget;

  /// Whether the surrounding canvas is the primary brand fill.
  final bool onPrimaryBackground;

  /// Optional fixed palette for startup surfaces that must not follow a saved
  /// dark-mode preference before the app has finished loading.
  final AppSemanticColors? colorPalette;

  /// The in-app HandyGo brand mark: primary-teal wrench on true transparency,
  /// for the light surfaces it sits on inside the app.
  static const logoAsset = 'assets/images/logo-primary-transparent.png';

  /// The startup brand mark: the off-white wrench exactly as it appears in
  /// `assets/images/logo-final.png`, on true transparency, for the primary
  /// teal canvas. The same asset the native launch screens draw.
  static const onPrimaryLogoAsset =
      'assets/images/logo-onprimary-transparent.png';

  // l10n-ignore: the brand name and its Roman Urdu tagline are the same in
  // every supported language — the same treatment as the "Shuru karein" CTA.
  static const wordmark = 'HandyGo';
  static const tagline = 'Har maslay ka ustaad';

  @override
  Widget build(BuildContext context) {
    final colors = colorPalette ?? context.semanticColors;
    final wordmarkColor = onPrimaryBackground
        ? colors.onPrimary
        : colors.textPrimary;
    final taglineColor = onPrimaryBackground
        ? colors.onPrimaryMuted
        : colors.textSecondary;

    // Sized from BOTH axes so the mark can never crowd a short screen nor
    // balloon on a tablet, and capped absolutely so a wide window keeps a
    // phone-sized lockup rather than a poster.
    final byWidth = widthBudget * 0.42;
    final byHeight = heightBudget * 0.24;
    final logoSize = (byWidth < byHeight ? byWidth : byHeight).clamp(
      64.0,
      120.0,
    );

    // The type is proportional to the mark, so the whole lockup scales as one
    // object. Text scaling is applied by Flutter on top of these.
    final wordmarkSize = (logoSize * 0.34).clamp(26.0, 46.0);
    final taglineSize = (wordmarkSize * 0.40).clamp(13.0, 19.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox.square(
          key: const Key('handygo-brand-logo'),
          dimension: logoSize,
          // No surface square behind the mark. One used to sit here to keep a
          // teal wrench legible on the teal canvas — which is exactly the
          // off-white-tile inversion the approved icon is not.
          child: Image.asset(
            onPrimaryBackground ? onPrimaryLogoAsset : logoAsset,
            // `contain` on a square box: the mark keeps its aspect ratio and
            // is never stretched.
            fit: BoxFit.contain,
            // Decorative: the brand name is right underneath it as real
            // text, so labelling the mark too would make a screen reader say
            // "HandyGo" twice.
            excludeFromSemantics: true,
          ),
        ),
        SizedBox(height: logoSize * 0.18),
        Text(
          wordmark,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: wordmarkSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            height: 1.05,
            color: wordmarkColor,
          ),
        ),
        SizedBox(height: logoSize * 0.07),
        Text(
          tagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: taglineSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            height: 1.2,
            color: taglineColor,
          ),
        ),
      ],
    );
  }
}

/// HandyGo's in-app brand mark, rendered from the single approved asset.
class HandyGoBrandMark extends StatelessWidget {
  const HandyGoBrandMark({super.key, required this.size, this.semanticLabel});

  /// Square display size. [BoxFit.contain] preserves the source aspect ratio.
  final double size;

  /// Screen-reader label. Leave null where the brand name is already adjacent
  /// as real text — the About card and the Support row both name HandyGo — so
  /// the mark is not announced twice.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        HandyGoBrandLockup.logoAsset,
        fit: BoxFit.contain,
        excludeFromSemantics: semanticLabel == null,
        semanticLabel: semanticLabel,
      ),
    );
  }
}
