import 'package:flutter/material.dart';

/// The ONE place HandyGo's semantic colour tokens are defined.
///
/// WHY THIS EXISTS
/// ---------------
/// HandyGo's final palette is not decided yet, and the app will later support
/// both light and dark mode. Any widget that hardcodes `Color(0xFF...)` has to
/// be hunted down and rewritten when that happens. Widgets that ask for a
/// *meaning* — "the warning surface", "secondary text" — do not.
///
/// So this is deliberately a naming layer, not a palette decision:
///
///   * Every token that Material 3 already models is DERIVED from the active
///     [ColorScheme]. Change the seed/palette (or add a dark theme) in one
///     place and every token follows automatically — including this file's
///     own consumers.
///   * Only the handful of tokens Material 3 has no role for ([success],
///     [warning]) carry literal values, and those values are the ones the app
///     already used inline. Nothing new was invented; the existing colours
///     were relocated here so the future redesign has a single file to edit.
///
/// USAGE
/// -----
/// ```dart
/// final c = context.semanticColors;
/// Container(color: c.warningSurface, child: Text('…', style: TextStyle(color: c.onWarningSurface)));
/// ```
///
/// SCOPE
/// -----
/// Only the tokens the offline/cache foundation actually consumes are defined
/// so far. This is intentionally NOT the full HandyGo design system — the
/// remaining tokens land with the UI/UX redesign, in this same file.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  // ── Surfaces ──────────────────────────────────────────────────────────────
  /// App/page background.
  final Color background;

  /// Cards, sheets, list rows sitting on [background].
  final Color surface;

  /// A surface that needs to read as raised//distinct from [surface] —
  /// banners, chips, inline notices.
  final Color surfaceElevated;

  // ── Content ───────────────────────────────────────────────────────────────
  /// Primary body/heading text on [surface] / [background].
  final Color textPrimary;

  /// Supporting/secondary text and inactive icons.
  final Color textSecondary;

  /// Text/icons drawn on top of [primary].
  final Color onPrimary;

  // ── Lines ─────────────────────────────────────────────────────────────────
  /// Outlines around inputs, cards, buttons.
  final Color border;

  /// Hairline separators inside a surface.
  final Color divider;

  // ── Brand / state ─────────────────────────────────────────────────────────
  final Color primary;
  final Color success;

  /// Foreground for warning content (icon + text) — e.g. the offline banner.
  final Color warning;

  /// Background for warning content.
  final Color warningSurface;

  final Color error;

  /// Non-interactive controls and their labels.
  final Color disabled;

  const AppSemanticColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.onPrimary,
    required this.border,
    required this.divider,
    required this.primary,
    required this.success,
    required this.warning,
    required this.warningSurface,
    required this.error,
    required this.disabled,
  });

  /// Derives the whole token set from a [ColorScheme].
  ///
  /// Everything Material 3 models is taken straight from the scheme, so a
  /// future palette change or a dark [ColorScheme] flows through without
  /// touching any widget. [success]/[warning] have no M3 role; their light
  /// and dark values are the two explicit decisions in this file and are
  /// carried over from the values the app was already using inline.
  factory AppSemanticColors.fromColorScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return AppSemanticColors(
      background: scheme.surfaceContainerLowest,
      surface: scheme.surface,
      surfaceElevated: scheme.surfaceContainerHighest,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      onPrimary: scheme.onPrimary,
      border: scheme.outlineVariant,
      divider: scheme.outlineVariant,
      primary: scheme.primary,
      // Relocated from the inline values previously used across the app.
      success: isDark ? const Color(0xFF4ADE80) : const Color(0xFF22C55E),
      warning: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
      warningSurface:
          isDark ? const Color(0xFF3A2E12) : const Color(0xFFFFF4E5),
      error: scheme.error,
      disabled: scheme.onSurface.withValues(alpha: 0.38),
    );
  }

  @override
  AppSemanticColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? onPrimary,
    Color? border,
    Color? divider,
    Color? primary,
    Color? success,
    Color? warning,
    Color? warningSurface,
    Color? error,
    Color? disabled,
  }) {
    return AppSemanticColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      onPrimary: onPrimary ?? this.onPrimary,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      primary: primary ?? this.primary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
      error: error ?? this.error,
      disabled: disabled ?? this.disabled,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      error: Color.lerp(error, other.error, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
    );
  }
}

extension AppSemanticColorsX on BuildContext {
  /// HandyGo's semantic colour tokens for the active theme.
  ///
  /// Falls back to deriving them from the ambient [ColorScheme] when the
  /// extension has not been registered — so a widget test that pumps a bare
  /// `MaterialApp` still renders correctly instead of throwing.
  AppSemanticColors get semanticColors {
    final theme = Theme.of(this);
    return theme.extension<AppSemanticColors>() ??
        AppSemanticColors.fromColorScheme(theme.colorScheme);
  }
}
