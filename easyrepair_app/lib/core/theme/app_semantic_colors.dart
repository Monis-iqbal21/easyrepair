import 'package:flutter/material.dart';

/// The ONE place HandyGo's colours are decided.
///
/// WHY THIS EXISTS
/// ---------------
/// Any widget that hardcodes `Color(0xFF...)` has to be hunted down and
/// rewritten whenever the palette moves or a second brightness is added.
/// Widgets that ask for a *meaning* — "the urgent surface", "secondary
/// text" — do not.
///
/// ARCHITECTURE
/// ------------
/// This file holds two literal palettes, [light] and [dark], exposing the
/// IDENTICAL token API. Nothing else in the app — not a page, not a widget,
/// not `AppTheme` — decides a colour:
///
///     Widget → semantic token → light/dark palette
///
/// and never
///
///     Widget → if (isDark) hardcodedA else hardcodedB
///
/// `AppTheme` builds its `ColorScheme` *from* these palettes rather than the
/// other way round, so Material's own defaults (buttons, inputs, dividers,
/// text selection) land on the same values.
///
/// USAGE
/// -----
/// ```dart
/// final c = context.semanticColors;
/// Container(color: c.urgentSoft, child: Text('…', style: TextStyle(color: c.urgent)));
/// ```
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  // ── Surfaces ──────────────────────────────────────────────────────────────
  /// App/page background — the canvas everything else sits on.
  final Color background;

  /// Cards, sheets, list rows sitting on [background].
  final Color surface;

  /// A surface that must read as distinct from [surface] — banners, chips,
  /// inline notices, muted fills.
  final Color surfaceSubtle;

  // ── Content ───────────────────────────────────────────────────────────────
  /// Primary body/heading text on [surface] / [background].
  final Color textPrimary;

  /// Supporting/secondary text and inactive icons.
  final Color textSecondary;

  /// Text/icons drawn on top of [primary] — e.g. the welcome lockup, which
  /// sits on a full-bleed [primary] background.
  final Color onPrimary;

  // ── Lines ─────────────────────────────────────────────────────────────────
  /// Hairline outlines around cards, and separators inside a surface.
  final Color border;

  /// The stronger outline interactive controls need — inputs, outlined
  /// buttons, checkboxes — where [border] would be too faint to read as an
  /// affordance.
  final Color controlBorder;

  // ── Brand ─────────────────────────────────────────────────────────────────
  /// HandyGo's primary brand colour. Changing it here changes it app-wide.
  final Color primary;

  /// [primary] in its pressed/active state.
  final Color primaryPressed;

  /// The quiet brand tint — selected rows, brand-flavoured info surfaces.
  final Color softTeal;

  // ── State ─────────────────────────────────────────────────────────────────
  /// Attention/urgency accent (urgent jobs, "act now" chips). Deliberately
  /// distinct from [error]: urgent is not a failure.
  final Color urgent;

  /// Background pairing for [urgent] content.
  final Color urgentSoft;

  final Color success;

  /// Background pairing for [success] content — e.g. a "Ready" status chip.
  ///
  /// Named to match [urgentSoft] rather than [warningSurface]: the two
  /// existing names disagree with each other, and `urgentSoft` is the one a
  /// state colour's tint is called. Renaming `warningSurface` to match is a
  /// separate job, deliberately not done here.
  final Color successSoft;

  /// Foreground for warning content (icon + text) — e.g. the offline banner.
  final Color warning;

  /// Background pairing for [warning] content.
  final Color warningSurface;

  final Color error;

  const AppSemanticColors({
    required this.background,
    required this.surface,
    required this.surfaceSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.onPrimary,
    required this.border,
    required this.controlBorder,
    required this.primary,
    required this.primaryPressed,
    required this.softTeal,
    required this.urgent,
    required this.urgentSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSurface,
    required this.error,
  });

  // ── Derived aliases ───────────────────────────────────────────────────────
  // Getters, not fields, so there is exactly one decision per concept and a
  // palette cannot define an alias inconsistently with what it aliases.

  /// Older name for [surfaceSubtle]. Same concept, same value.
  Color get surfaceElevated => surfaceSubtle;

  /// Hairline separators inside a surface — the same line weight as [border].
  Color get divider => border;

  /// Non-interactive controls and their labels.
  Color get disabled => textPrimary.withValues(alpha: 0.38);

  /// FINAL HANDYGO LIGHT PALETTE.
  static const AppSemanticColors light = AppSemanticColors(
    background: Color(0xFFF7F3EA),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFEDE9DF),
    textPrimary: Color(0xFF1C2826),
    textSecondary: Color(0xFF586764),
    // The warm off-white the brand mark itself is drawn in, so text on a
    // primary fill matches the wrench beside it instead of glaring pure white.
    onPrimary: Color(0xFFF7F3EA),
    border: Color(0xFFD7E0DC),
    controlBorder: Color(0xFF7D8B87),
    primary: Color(0xFF11645D),
    primaryPressed: Color(0xFF0D514B),
    softTeal: Color(0xFFE4F1EE),
    urgent: Color(0xFFA9431D),
    urgentSoft: Color(0xFFFCE8DF),
    success: Color(0xFF2E6E4F),
    // The prototype's `--sageT` — the tint relationship urgentSoft has to
    // urgent, expressed in the success hue.
    successSoft: Color(0xFFE6F4EA),
    warning: Color(0xFF8A5B10),
    // No brand value was specified for the warning surface; this is the tint
    // relationship urgentSoft has to urgent, expressed in the warning hue.
    warningSurface: Color(0xFFFBF0DC),
    error: Color(0xFFB42318),
  );

  /// FINAL HANDYGO DARK PALETTE.
  ///
  /// Derived from the same brand identity rather than inverted mechanically:
  /// backgrounds are a deep teal-charcoal (not black), surfaces step up in
  /// small increments, and the brand teal is lifted to `#3FA79B` — still
  /// unmistakably the HandyGo teal, but light enough that a filled control
  /// clears AA against the dark canvas, which `#11645D` does not. Status
  /// colours are lifted the same way and stay in their own hue lanes.
  static const AppSemanticColors dark = AppSemanticColors(
    background: Color(0xFF0C1F1D),
    surface: Color(0xFF122A28),
    surfaceSubtle: Color(0xFF1A3532),
    textPrimary: Color(0xFFECF1EE),
    textSecondary: Color(0xFF9BAAA6),
    // Dark ink on the lifted teal — the readable pairing at that lightness.
    onPrimary: Color(0xFF06201D),
    border: Color(0xFF2C3E3B),
    controlBorder: Color(0xFF61736F),
    primary: Color(0xFF3FA79B),
    primaryPressed: Color(0xFF2F8B81),
    softTeal: Color(0xFF10332F),
    urgent: Color(0xFFE0834F),
    urgentSoft: Color(0xFF3A2317),
    success: Color(0xFF56B183),
    // The prototype's dark `--sageT`.
    successSoft: Color(0xFF173B2C),
    warning: Color(0xFFD9A441),
    warningSurface: Color(0xFF35290F),
    error: Color(0xFFE57A6E),
  );

  /// The palette for a [Brightness] — the only place the two are chosen
  /// between.
  static AppSemanticColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The palette matching a [ColorScheme]'s brightness.
  ///
  /// `AppTheme` builds its schemes FROM these palettes, so this is a lookup,
  /// not a derivation. It exists so the [AppSemanticColorsX] fallback — and a
  /// widget test that pumps a bare `MaterialApp` — still gets real HandyGo
  /// colours instead of Material's defaults.
  factory AppSemanticColors.fromColorScheme(ColorScheme scheme) =>
      of(scheme.brightness);

  @override
  AppSemanticColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? onPrimary,
    Color? border,
    Color? controlBorder,
    Color? primary,
    Color? primaryPressed,
    Color? softTeal,
    Color? urgent,
    Color? urgentSoft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSurface,
    Color? error,
  }) {
    return AppSemanticColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      onPrimary: onPrimary ?? this.onPrimary,
      border: border ?? this.border,
      controlBorder: controlBorder ?? this.controlBorder,
      primary: primary ?? this.primary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      softTeal: softTeal ?? this.softTeal,
      urgent: urgent ?? this.urgent,
      urgentSoft: urgentSoft ?? this.urgentSoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
      error: error ?? this.error,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      border: Color.lerp(border, other.border, t)!,
      controlBorder: Color.lerp(controlBorder, other.controlBorder, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!,
      softTeal: Color.lerp(softTeal, other.softTeal, t)!,
      urgent: Color.lerp(urgent, other.urgent, t)!,
      urgentSoft: Color.lerp(urgentSoft, other.urgentSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

extension AppSemanticColorsX on BuildContext {
  /// HandyGo's semantic colour tokens for the active theme.
  ///
  /// Falls back to the palette matching the ambient brightness when the
  /// extension has not been registered — so a widget test that pumps a bare
  /// `MaterialApp` still renders in HandyGo's colours instead of throwing.
  AppSemanticColors get semanticColors {
    final theme = Theme.of(this);
    return theme.extension<AppSemanticColors>() ??
        AppSemanticColors.of(theme.brightness);
  }
}
