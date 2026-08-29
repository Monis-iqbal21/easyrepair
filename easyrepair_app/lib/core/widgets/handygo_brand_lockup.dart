import 'package:flutter/material.dart';

import '../theme/app_semantic_colors.dart';

/// HandyGo's startup brand lockup: the off-white wrench, the "HandyGo"
/// wordmark and the "Har maslay ka ustaad" tagline, stacked and centred.
///
/// Shared by the loading screen (`SplashPage`) and the logged-out landing
/// screen (`WelcomePage`) so the mark never jumps position or size as one
/// hands over to the other.
///
/// ## Text, not artwork
///
/// The wordmark and tagline are real [Text] widgets. Only the wrench comes
/// from an image ([wrenchAsset]) — so the type scales with the device and the
/// user's text-size setting instead of pixelating, and screen readers get
/// words rather than a label bolted onto a bitmap.
///
/// ## Colour
///
/// Every colour is [AppSemanticColors.onPrimary]; the lockup assumes it is
/// drawn on an [AppSemanticColors.primary] background. There is no literal
/// here, so the light/dark palettes drive it like everything else.
class HandyGoBrandLockup extends StatelessWidget {
  const HandyGoBrandLockup({
    super.key,
    required this.widthBudget,
    required this.heightBudget,
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

  /// The wrench mark alone — no wordmark, no tagline, no background box. The
  /// asset is already drawn in HandyGo's off-white, so it is never tinted.
  static const wrenchAsset = 'assets/images/logo-only.png';

  // l10n-ignore: the brand name and its Roman Urdu tagline are the same in
  // every supported language — the same treatment as the "Shuru karein" CTA.
  static const wordmark = 'HandyGo';
  static const tagline = 'Har maslay ka ustaad';

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    // Sized from BOTH axes so the mark can never crowd a short screen nor
    // balloon on a tablet, and capped absolutely so a wide window keeps a
    // phone-sized lockup rather than a poster.
    final byWidth = widthBudget * 0.42;
    final byHeight = heightBudget * 0.24;
    final wrenchSize = (byWidth < byHeight ? byWidth : byHeight).clamp(
      64.0,
      168.0,
    );

    // The type is proportional to the mark, so the whole lockup scales as one
    // object. Text scaling is applied by Flutter on top of these.
    final wordmarkSize = (wrenchSize * 0.34).clamp(26.0, 46.0);
    final taglineSize = (wordmarkSize * 0.40).clamp(13.0, 19.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: wrenchSize,
          child: Image.asset(
            wrenchAsset,
            // `contain` on a square box: the mark keeps its aspect ratio and
            // is never stretched.
            fit: BoxFit.contain,
            // Decorative: the brand name is right underneath it as real text,
            // so labelling the mark too would make a screen reader say
            // "HandyGo" twice.
            excludeFromSemantics: true,
          ),
        ),
        SizedBox(height: wrenchSize * 0.18),
        Text(
          wordmark,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: wordmarkSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            height: 1.05,
            color: colors.onPrimary,
          ),
        ),
        SizedBox(height: wrenchSize * 0.07),
        Text(
          tagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: taglineSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            height: 1.2,
            // Subordinate to the wordmark without introducing a second
            // colour: the same token, held back a little.
            color: colors.onPrimary.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

/// HandyGo's in-app brand mark: the off-white wrench on a filled
/// [AppSemanticColors.primary] disc.
///
/// ## Why this exists
///
/// `assets/images/logo-green.png` is the *launcher* icon source — `pubspec.yaml`
/// hands that exact file to `flutter_launcher_icons`. It is a pre-rendered
/// orange tile carrying EasyRepair's retired orange, baked into the pixels
/// where no palette can reach it. Screens that used it as ordinary in-app
/// branding therefore showed an orange square inside a teal app, in both
/// themes, and got the wrong brand colour besides.
///
/// This widget draws the same mark from the parts the app already owns: the
/// transparent wrench of [HandyGoBrandLockup.wrenchAsset] over a `primary`
/// disc. The colour is a token, so it follows light/dark like everything else
/// and moves with the brand if the brand moves.
class HandyGoBrandMark extends StatelessWidget {
  const HandyGoBrandMark({super.key, required this.size, this.semanticLabel});

  /// Diameter of the disc. The wrench is inset within it.
  final double size;

  /// Screen-reader label. Leave null where the brand name is already adjacent
  /// as real text — the About card and the Support row both name HandyGo — so
  /// the mark is not announced twice.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Container(
      width: size,
      height: size,
      // The wrench is drawn edge-to-edge in its own artwork; the inset keeps
      // it from touching the rim of the disc at any size.
      padding: EdgeInsets.all(size * 0.22),
      decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
      child: Image.asset(
        HandyGoBrandLockup.wrenchAsset,
        fit: BoxFit.contain,
        excludeFromSemantics: semanticLabel == null,
        semanticLabel: semanticLabel,
      ),
    );
  }
}
