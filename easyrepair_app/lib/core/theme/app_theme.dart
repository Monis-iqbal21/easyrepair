import 'package:flutter/material.dart';

import 'app_semantic_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    const primaryColor = Color(0xFF1A1A1A);

    /// HANDYGO PRIMARY BRAND COLOUR — THE SINGLE SOURCE OF TRUTH.
    ///
    /// Feeds [ColorScheme.primary], which feeds
    /// `AppSemanticColors.primary`, which every screen that has adopted the
    /// semantic tokens reads through `context.semanticColors.primary`.
    /// Changing this one value is how HandyGo's primary colour changes
    /// app-wide — no page ever hardcodes it.
    ///
    /// The value is the orange the CLIENT HOME page is already using today
    /// (`_kGreen` — misleadingly named — in client_home_page.dart, and
    /// `_kAccent` in client_bottom_nav_bar.dart), so the themed surfaces
    /// match the rest of the product instead of diverging from it. The wider
    /// migration of those ~995 remaining literals onto these tokens is a
    /// later task; this constant is where that migration will land.
    const accentColor = Color(0xFFDB6234);

    const backgroundColor = Color(0xFFF9FAFB);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      primary: accentColor,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: colorScheme,
      // Single registration point for HandyGo's semantic colour tokens — see
      // AppSemanticColors. Every offline/cache surface reads its colours from
      // here rather than hardcoding values, so the pending palette decision
      // and the future dark theme are a one-file change.
      extensions: <ThemeExtension<dynamic>>[
        AppSemanticColors.fromColorScheme(colorScheme),
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentColor, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: primaryColor,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: primaryColor,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
      ),
    );
  }
}
