import 'package:flutter/material.dart';

import '../../../../core/theme/app_semantic_colors.dart';

/// Presentation pieces shared by the four Ustaad registration steps.
///
/// Every colour is an [AppSemanticColors] token, so all four screens follow
/// the light and dark palettes with no brightness checks of their own.

/// Placeholder masks shown in the registration fields.
///
/// l10n-ignore: these are digit/format examples — the same characters in every
/// language, exactly like the `+92` dial code and the `3XX XXX XXXX` phone
/// mask beside them. Putting them in the ARB would mean three keys whose
/// "translations" are byte-identical to the English, which the translation set
/// deliberately rejects.
const kCnicHint = '42101-1234567-1';
const kStreetHint = '14';
const kHouseHint = 'B-42';

/// Back arrow + step name + the four-segment progress bar from the design.
class UstaadStepHeader extends StatelessWidget {
  const UstaadStepHeader({
    super.key,
    required this.title,
    required this.step,
    this.totalSteps = 4,
  });

  final String title;

  /// 1-based. Segments before it read as complete, it reads as active, the
  /// rest as untouched.
  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Semantics(
              button: true,
              label: MaterialLocalizations.of(context).backButtonTooltip,
              child: InkResponse(
                onTap: () => Navigator.of(context).maybePop(),
                radius: 24,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 24,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Semantics(
          label: '$step / $totalSteps',
          child: Row(
            children: [
              for (var i = 1; i <= totalSteps; i++) ...[
                if (i > 1) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= step ? colors.primary : colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The page skeleton every registration step sits in.
///
/// Long steps (3 and 4) scroll while the CTA stays pinned above the safe area,
/// which is what the design shows — the content slides under a fixed bottom
/// bar rather than the button drifting far below the fold. Short steps get the
/// same bar, so the CTA is always in the same place.
class UstaadStepScaffold extends StatelessWidget {
  const UstaadStepScaffold({
    super.key,
    required this.child,
    required this.cta,
  });

  final Widget child;
  final Widget cta;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Scaffold(
      backgroundColor: colors.background,
      // The scroll view owns the keyboard inset, so the Scaffold must not also
      // resize or the content would be shortened twice.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboard = MediaQuery.viewInsetsOf(context).bottom;
            final horizontal = constraints.maxWidth < 360 ? 18.0 : 24.0;

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      12,
                      horizontal,
                      // Clears the keyboard so the focused field is always
                      // reachable, whatever is on screen.
                      16 + keyboard,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: child,
                      ),
                    ),
                  ),
                ),
                // Hidden while the keyboard is up: the CTA would otherwise sit
                // on top of it, and the field being typed into matters more.
                if (keyboard == 0)
                  Padding(
                    padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 12),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: cta,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A white rounded panel — the grouping the design uses for every Step 3/4
/// section.
class UstaadSectionCard extends StatelessWidget {
  const UstaadSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

/// A section heading inside an [UstaadSectionCard].
class UstaadSectionTitle extends StatelessWidget {
  const UstaadSectionTitle(this.text, {super.key, this.subtitle});

  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// A selectable pill — trades and experience bands both use it.
class UstaadChoiceChip extends StatelessWidget {
  const UstaadChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.rounded = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Trades are fully rounded pills; experience bands are softer rectangles,
  /// as in the design.
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final radius = BorderRadius.circular(rounded ? 24 : 12);

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.softTeal : colors.surfaceSubtle,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? colors.primary : colors.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? colors.primary : colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small status pill on a CNIC card — "Baqi hai" until the image is up.
class UstaadStatusBadge extends StatelessWidget {
  const UstaadStatusBadge({
    super.key,
    required this.label,
    required this.done,
  });

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: done ? colors.softTeal : colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: done ? colors.success : colors.textSecondary,
        ),
      ),
    );
  }
}
