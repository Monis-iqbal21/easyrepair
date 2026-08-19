import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';

/// Pins HandyGo's FINAL palette and the light/dark architecture around it.
///
/// These tests exist so a stray edit cannot quietly move a brand colour, and
/// so the two brightnesses can never drift into offering different concepts:
/// every token below is asserted on BOTH palettes, by name.
void main() {
  group('final LIGHT palette', () {
    const expected = <String, Color>{
      'background': Color(0xFFF7F3EA),
      'surface': Color(0xFFFFFFFF),
      'surfaceSubtle': Color(0xFFEDE9DF),
      'textPrimary': Color(0xFF1C2826),
      'textSecondary': Color(0xFF586764),
      'border': Color(0xFFD7E0DC),
      'controlBorder': Color(0xFF7D8B87),
      'primary': Color(0xFF11645D),
      'primaryPressed': Color(0xFF0D514B),
      'softTeal': Color(0xFFE4F1EE),
      'urgent': Color(0xFFA9431D),
      'urgentSoft': Color(0xFFFCE8DF),
      'success': Color(0xFF2E6E4F),
      'warning': Color(0xFF8A5B10),
      'error': Color(0xFFB42318),
    };

    final actual = <String, Color>{
      'background': AppSemanticColors.light.background,
      'surface': AppSemanticColors.light.surface,
      'surfaceSubtle': AppSemanticColors.light.surfaceSubtle,
      'textPrimary': AppSemanticColors.light.textPrimary,
      'textSecondary': AppSemanticColors.light.textSecondary,
      'border': AppSemanticColors.light.border,
      'controlBorder': AppSemanticColors.light.controlBorder,
      'primary': AppSemanticColors.light.primary,
      'primaryPressed': AppSemanticColors.light.primaryPressed,
      'softTeal': AppSemanticColors.light.softTeal,
      'urgent': AppSemanticColors.light.urgent,
      'urgentSoft': AppSemanticColors.light.urgentSoft,
      'success': AppSemanticColors.light.success,
      'warning': AppSemanticColors.light.warning,
      'error': AppSemanticColors.light.error,
    };

    expected.forEach((token, value) {
      test('$token is $value', () => expect(actual[token], value));
    });

    test('the retired orange is nowhere in the light palette', () {
      expect(actual.values, isNot(contains(const Color(0xFFDB6234))));
    });
  });

  group('DARK palette', () {
    test('is a genuinely different palette, not the light one reused', () {
      expect(AppSemanticColors.dark.background,
          isNot(AppSemanticColors.light.background));
      expect(AppSemanticColors.dark.primary,
          isNot(AppSemanticColors.light.primary));
    });

    test('backgrounds are dark, surfaces step up from them, and neither is '
        'pure black', () {
      final bg = AppSemanticColors.dark.background;
      final surface = AppSemanticColors.dark.surface;

      expect(_luminance(bg), lessThan(0.05));
      expect(bg, isNot(const Color(0xFF000000)));
      expect(_luminance(surface), greaterThan(_luminance(bg)));
      expect(_luminance(AppSemanticColors.dark.surfaceSubtle),
          greaterThan(_luminance(surface)));
    });

    test('text is readable off-white on the dark canvas, with muted '
        'secondary text still clearing AA', () {
      final c = AppSemanticColors.dark;
      expect(c.textPrimary, isNot(const Color(0xFFFFFFFF)));
      expect(_contrastRatio(c.textPrimary, c.background), greaterThan(7.0));
      expect(_contrastRatio(c.textSecondary, c.background), greaterThan(4.5));
      expect(_luminance(c.textSecondary), lessThan(_luminance(c.textPrimary)));
    });

    test('borders are visible against their surfaces without being harsh', () {
      final c = AppSemanticColors.dark;
      expect(_luminance(c.border), greaterThan(_luminance(c.surface)));
      expect(_luminance(c.controlBorder), greaterThan(_luminance(c.border)));
    });

    test('the brand teal stays recognisable but gains control contrast', () {
      final c = AppSemanticColors.dark;
      // Same hue family as #11645D, lifted for legibility on a dark canvas.
      expect(_hueDegrees(c.primary),
          closeTo(_hueDegrees(AppSemanticColors.light.primary), 12));
      expect(_contrastRatio(c.primary, c.background), greaterThan(4.5));
      expect(_contrastRatio(c.onPrimary, c.primary), greaterThan(4.5));
    });

    test('status colours stay readable and stay in their own lanes', () {
      final c = AppSemanticColors.dark;
      for (final status in [c.success, c.warning, c.error, c.urgent]) {
        expect(_contrastRatio(status, c.background), greaterThan(4.5));
      }
      expect(_contrastRatio(c.urgent, c.urgentSoft), greaterThan(4.5));
      expect(_contrastRatio(c.warning, c.warningSurface), greaterThan(4.5));
    });
  });

  group('the two palettes expose the SAME token API', () {
    // Every semantic concept must be answerable in either brightness — that
    // is what lets a page name a token and never a brightness.
    final tokens = <String, Color Function(AppSemanticColors)>{
      'background': (c) => c.background,
      'surface': (c) => c.surface,
      'surfaceSubtle': (c) => c.surfaceSubtle,
      'textPrimary': (c) => c.textPrimary,
      'textSecondary': (c) => c.textSecondary,
      'onPrimary': (c) => c.onPrimary,
      'border': (c) => c.border,
      'controlBorder': (c) => c.controlBorder,
      'primary': (c) => c.primary,
      'primaryPressed': (c) => c.primaryPressed,
      'softTeal': (c) => c.softTeal,
      'urgent': (c) => c.urgent,
      'urgentSoft': (c) => c.urgentSoft,
      'success': (c) => c.success,
      'warning': (c) => c.warning,
      'warningSurface': (c) => c.warningSurface,
      'error': (c) => c.error,
      // Derived aliases the app already consumes.
      'surfaceElevated': (c) => c.surfaceElevated,
      'divider': (c) => c.divider,
      'disabled': (c) => c.disabled,
    };

    tokens.forEach((name, read) {
      test('$name resolves in both brightnesses, to different values', () {
        expect(read(AppSemanticColors.light), isA<Color>());
        expect(read(AppSemanticColors.dark), isA<Color>());
        expect(read(AppSemanticColors.dark), isNot(read(AppSemanticColors.light)));
      });
    });
  });

  group('Material integration', () {
    test('the light ColorScheme is built FROM the light palette', () {
      const c = AppSemanticColors.light;
      final theme = AppTheme.lightTheme;

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, c.primary);
      expect(theme.colorScheme.onPrimary, c.onPrimary);
      expect(theme.colorScheme.surface, c.surface);
      expect(theme.colorScheme.onSurface, c.textPrimary);
      expect(theme.colorScheme.error, c.error);
      expect(theme.colorScheme.onError, c.surface);
      expect(theme.colorScheme.outline, c.controlBorder);
      expect(theme.colorScheme.outlineVariant, c.border);
      expect(theme.scaffoldBackgroundColor, c.background);
      expect(theme.cardColor, c.surface);
      expect(theme.dividerColor, c.border);
    });

    test('the dark ColorScheme is built FROM the dark palette', () {
      const c = AppSemanticColors.dark;
      final theme = AppTheme.darkTheme;

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, c.primary);
      expect(theme.colorScheme.surface, c.surface);
      expect(theme.scaffoldBackgroundColor, c.background);
      expect(theme.cardColor, c.surface);
      expect(theme.dividerColor, c.border);
    });

    test('both themes register the matching semantic extension', () {
      expect(AppTheme.lightTheme.extension<AppSemanticColors>(),
          same(AppSemanticColors.light));
      expect(AppTheme.darkTheme.extension<AppSemanticColors>(),
          same(AppSemanticColors.dark));
    });

    test('input decoration and button defaults come from the tokens', () {
      const c = AppSemanticColors.light;
      final theme = AppTheme.lightTheme;

      final input = theme.inputDecorationTheme;
      expect(input.fillColor, c.surface);
      expect((input.enabledBorder! as OutlineInputBorder).borderSide.color,
          c.border);
      expect((input.focusedBorder! as OutlineInputBorder).borderSide.color,
          c.primary);
      expect(
          (input.errorBorder! as OutlineInputBorder).borderSide.color, c.error);

      final button = theme.elevatedButtonTheme.style!;
      expect(button.backgroundColor!.resolve(const {}), c.primary);
      expect(button.foregroundColor!.resolve(const {}), c.onPrimary);
      expect(
        button.overlayColor!.resolve(const {WidgetState.pressed}),
        c.primaryPressed,
      );
    });

    test('semanticColors falls back to the palette for the ambient '
        'brightness when the extension is missing', () {
      expect(
        AppSemanticColors.fromColorScheme(
          const ColorScheme.dark(),
        ),
        same(AppSemanticColors.dark),
      );
      expect(
        AppSemanticColors.fromColorScheme(
          const ColorScheme.light(),
        ),
        same(AppSemanticColors.light),
      );
    });

    testWidgets('a widget reads the active brightness\'s tokens through the '
        'context, with no conditional of its own', (tester) async {
      late AppSemanticColors seen;

      Future<void> pump(ThemeData theme) async {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Builder(builder: (context) {
            seen = context.semanticColors;
            return const SizedBox.shrink();
          }),
        ));
        // MaterialApp animates theme changes through AnimatedTheme, so the
        // first frame after a swap is still mid-lerp.
        await tester.pumpAndSettle();
      }

      await pump(AppTheme.lightTheme);
      expect(seen.primary, AppSemanticColors.light.primary);

      await pump(AppTheme.darkTheme);
      expect(seen.primary, AppSemanticColors.dark.primary);
    });
  });
}

/// WCAG relative luminance — the basis for every contrast assertion above.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Hue in degrees on the HSV wheel — used to assert the dark brand teal is the
/// SAME hue as the light one, only lifted, rather than a different colour.
double _hueDegrees(Color c) => HSVColor.fromColor(c).hue;
