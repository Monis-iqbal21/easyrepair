import 'package:flutter/material.dart';

import 'app_semantic_colors.dart';

/// HandyGo's Material themes.
///
/// This file makes NO colour decisions of its own. Every value below is read
/// from [AppSemanticColors.light] / [AppSemanticColors.dark], so the palette
/// has exactly one home and Material's own defaults (button fills, input
/// borders, dividers, text selection, snackbars) land on the same tokens the
/// pages read through `context.semanticColors`.
///
///     AppSemanticColors → ColorScheme + ThemeData → widgets
class AppTheme {
  const AppTheme._();

  /// The brightness the app runs in.
  ///
  /// Both themes are complete and interchangeable — flip this to
  /// [ThemeMode.system] (or drive it from a user setting) and dark mode is
  /// live, with no other change anywhere. It is pinned to light for now
  /// because the feature pages still carry ~1k pre-token colour literals from
  /// before the semantic layer existed; those render as light-on-light under
  /// a dark scheme. Migrating them is a separate, page-by-page task — this
  /// constant is the switch it flips when it lands.
  static const ThemeMode themeMode = ThemeMode.light;

  static ThemeData get lightTheme =>
      _themeFrom(AppSemanticColors.light, Brightness.light);

  static ThemeData get darkTheme =>
      _themeFrom(AppSemanticColors.dark, Brightness.dark);

  /// Builds a complete [ThemeData] from a semantic palette. Both brightnesses
  /// go through this one function, which is what guarantees they stay
  /// structurally identical and differ only in their token values.
  static ThemeData _themeFrom(AppSemanticColors c, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.softTeal,
      onPrimaryContainer: isDark ? c.textPrimary : c.primary,
      // HandyGo has no separate secondary brand colour; the brand teal plays
      // that role so nothing can drift into an unowned hue.
      secondary: c.primary,
      onSecondary: c.onPrimary,
      secondaryContainer: c.softTeal,
      onSecondaryContainer: isDark ? c.textPrimary : c.primary,
      tertiary: c.urgent,
      onTertiary: c.surface,
      tertiaryContainer: c.urgentSoft,
      onTertiaryContainer: c.urgent,
      error: c.error,
      onError: isDark ? c.background : c.surface,
      errorContainer: c.urgentSoft,
      onErrorContainer: c.error,
      surface: c.surface,
      onSurface: c.textPrimary,
      surfaceDim: c.surfaceSubtle,
      surfaceBright: c.surface,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.background,
      surfaceContainer: c.surfaceSubtle,
      surfaceContainerHigh: c.surfaceSubtle,
      surfaceContainerHighest: c.surfaceSubtle,
      onSurfaceVariant: c.textSecondary,
      outline: c.controlBorder,
      outlineVariant: c.border,
      inverseSurface: c.textPrimary,
      onInverseSurface: c.background,
      inversePrimary: c.softTeal,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      cardColor: c.surface,
      dividerColor: c.border,
      // Single registration point for HandyGo's semantic tokens. Every page
      // reads its colours from here rather than hardcoding values, so a
      // palette change — or the light/dark switch — is a one-file edit.
      extensions: <ThemeExtension<dynamic>>[c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: TextStyle(color: c.textSecondary),
        labelStyle: TextStyle(color: c.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.error, width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.disabled,
          disabledForegroundColor: c.onPrimary,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ).copyWith(
          // The pressed token is a real palette value, not an opacity trick,
          // so it can be tuned per brightness like everything else.
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? c.primaryPressed
                : null,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          side: BorderSide(color: c.controlBorder),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.onPrimary : c.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.primary
              : c.surfaceSubtle,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.textPrimary,
        contentTextStyle: TextStyle(color: c.background),
        behavior: SnackBarBehavior.floating,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionHandleColor: c.primary,
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: c.textSecondary),
      ),
    );
  }
}
