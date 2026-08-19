import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';
import 'package:handygo_app/core/l10n/locale_provider.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/auth/presentation/pages/language_selection_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The onboarding language step: exactly two choices, the right one preselected,
/// the existing locale mechanism reused, and no brand colour of its own.

const _romanUrduTitle = 'Roman Urdu + Easy English';
const _englishTitle = 'English';

Widget _stub(String label) => Scaffold(body: Center(child: Text(label)));

/// Pumps the page inside a router that owns the real route names, so
/// "Continue navigates to the existing role picker" is exercised for real.
Future<({GoRouter router, ProviderContainer container})> _pump(
  WidgetTester tester, {
  String? storedLocale,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(
    storedLocale == null ? {} : {kLocalePrefsKey: storedLocale},
  );
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: '/auth/language',
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => _stub('WELCOME')),
      GoRoute(
        path: '/auth/language',
        builder: (_, _) => const LanguageSelectionPage(),
      ),
      GoRoute(
        path: '/auth/role-select',
        builder: (_, _) => _stub('ROLE_SELECT'),
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) {
          final locale = ref.watch(localeProvider);
          return MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
            locale: locale.locale,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            localeResolutionCallback: (_, _) => locale.locale,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (router: router, container: container);
}

/// Only the selected card renders a check mark, so "does this card contain a
/// check" is the honest read-back of the selection state.
bool _isSelected(WidgetTester tester, String cardTitle) {
  final card =
      find.ancestor(of: find.text(cardTitle), matching: find.byType(InkWell));
  return find
      .descendant(of: card, matching: find.byIcon(Icons.check_rounded))
      .evaluate()
      .isNotEmpty;
}

void main() {
  group('the two options', () {
    testWidgets('shows exactly two language choices', (tester) async {
      await _pump(tester);

      expect(find.text(_romanUrduTitle), findsOneWidget);
      expect(find.text(_englishTitle), findsOneWidget);
      // Exactly one card is selected at any time, which also means exactly
      // one indicator is rendered. Counting InkWells is avoided deliberately:
      // Material's own button ink would be counted too, making the assertion
      // about framework internals rather than about the two options.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('never offers an Urdu-script-only third option',
        (tester) async {
      await _pump(tester);

      // The Urdu script label that the SETTINGS sheet offers must not appear
      // in onboarding.
      expect(find.text(AppLocale.urdu.displayLabel), findsNothing);
      expect(find.text('اردو'), findsNothing);
    });

    testWidgets('renders the heading, both subtitles and Continue in the '
        'active language', (tester) async {
      await _pump(tester);

      // Default locale is Roman Urdu, so the localized copy is what shows.
      expect(find.text('Zabaan chunein'), findsOneWidget);
      expect(
        find.text('Aap kis zabaan mein application use karna chahte hain?'),
        findsOneWidget,
      );
      expect(find.text('Asaan alfaaz, samajhne mein aasan'), findsOneWidget);
      expect(find.text('Poori application English mein'), findsOneWidget);
      expect(find.text('Aage Barhein'), findsOneWidget);
    });

    testWidgets('an English user sees the same page in English', (tester) async {
      await _pump(tester, storedLocale: 'en');

      expect(find.text('Choose Language'), findsOneWidget);
      expect(find.text('Simple words, easy to understand'), findsOneWidget);
      expect(find.text('Full application in English'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('the two option NAMES stay identical whatever locale is '
        'active, so a user can always find their own', (tester) async {
      for (final stored in [null, 'en', 'ur']) {
        await _pump(tester, storedLocale: stored);
        expect(find.text(_romanUrduTitle), findsOneWidget);
        expect(find.text(_englishTitle), findsOneWidget);
      }
    });
  });

  group('initial selection', () {
    testWidgets('with NO stored preference, Roman Urdu is preselected',
        (tester) async {
      await _pump(tester);

      expect(_isSelected(tester, _romanUrduTitle), isTrue);
      expect(_isSelected(tester, _englishTitle), isFalse);
    });

    testWidgets('an existing English preference preselects English',
        (tester) async {
      await _pump(tester, storedLocale: 'en');

      expect(_isSelected(tester, _englishTitle), isTrue);
      expect(_isSelected(tester, _romanUrduTitle), isFalse);
    });

    testWidgets('an existing Roman Urdu preference preselects Roman Urdu',
        (tester) async {
      await _pump(tester, storedLocale: 'ur_Latn');

      expect(_isSelected(tester, _romanUrduTitle), isTrue);
    });

    testWidgets('a stored Urdu-script user sees the Roman Urdu card — the '
        'nearest option, never English', (tester) async {
      await _pump(tester, storedLocale: 'ur');

      expect(_isSelected(tester, _romanUrduTitle), isTrue);
      expect(_isSelected(tester, _englishTitle), isFalse);
    });
  });

  group('choosing and continuing', () {
    testWidgets('English + Continue persists the locale and opens the '
        'existing role picker', (tester) async {
      final ctx = await _pump(tester);

      await tester.tap(find.text(_englishTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(ctx.container.read(localeProvider), AppLocale.english);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kLocalePrefsKey), 'en');
      expect(find.text('ROLE_SELECT'), findsOneWidget);
    });

    testWidgets('Roman Urdu + Continue persists the locale and navigates',
        (tester) async {
      final ctx = await _pump(tester, storedLocale: 'en');

      await tester.tap(find.text(_romanUrduTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(ctx.container.read(localeProvider), AppLocale.romanUrdu);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kLocalePrefsKey), 'ur_Latn');
      expect(find.text('ROLE_SELECT'), findsOneWidget);
    });

    testWidgets('a brand-new user who accepts the default has it written down',
        (tester) async {
      await _pump(tester);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kLocalePrefsKey), 'ur_Latn');
      expect(find.text('ROLE_SELECT'), findsOneWidget);
    });

    testWidgets('merely opening the page never overwrites an existing '
        'preference the user did not touch', (tester) async {
      // The Urdu-script case is the one that would silently migrate: the card
      // shown is Roman Urdu because Urdu has no card, so a blind write would
      // change their language behind their back.
      final ctx = await _pump(tester, storedLocale: 'ur');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kLocalePrefsKey), 'ur',
          reason: 'untouched preference must survive');
      expect(ctx.container.read(localeProvider), AppLocale.urdu);
      expect(find.text('ROLE_SELECT'), findsOneWidget);
    });

    testWidgets('tapping only moves the selection — the locale is applied on '
        'Continue, not on every tap', (tester) async {
      final ctx = await _pump(tester);

      await tester.tap(find.text(_englishTitle));
      await tester.pumpAndSettle();

      expect(_isSelected(tester, _englishTitle), isTrue);
      expect(ctx.container.read(localeProvider), AppLocale.romanUrdu,
          reason: 'nothing is committed until Continue');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(ctx.container.read(localeProvider), AppLocale.english);
    });
  });

  group('navigation', () {
    testWidgets('Continue PUSHES, so Back returns to the language step',
        (tester) async {
      final ctx = await _pump(tester);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text('ROLE_SELECT'), findsOneWidget);

      ctx.router.pop();
      await tester.pumpAndSettle();

      expect(find.text(_romanUrduTitle), findsOneWidget,
          reason: 'normal stack behaviour, no double-pop hack');
    });
  });

  group('colour architecture', () {
    // The palette lives centrally; this page must only ever name meanings.
    testWidgets('Continue resolves from semanticColors.primary/onPrimary',
        (tester) async {
      await _pump(tester);

      final colors =
          tester.element(find.byType(ElevatedButton)).semanticColors;
      final style =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;

      expect(style.backgroundColor!.resolve(const {}), colors.primary);
      expect(style.foregroundColor!.resolve(const {}), colors.onPrimary);
    });

    testWidgets('the selected card border and indicator use semantic primary',
        (tester) async {
      await _pump(tester);

      final colors = tester.element(find.byType(InkWell).first).semanticColors;

      // The selected card's border.
      final borders = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.border != null)
          .toList();
      expect(
        borders.any((d) => (d.border! as Border).top.color == colors.primary),
        isTrue,
        reason: 'selected card must be outlined in the central primary',
      );

      // The filled indicator.
      expect(
        borders.any((d) => d.color == colors.primary),
        isTrue,
        reason: 'selected indicator must be filled with the central primary',
      );

      // And the check mark rides on onPrimary.
      final check = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
      expect(check.color, colors.onPrimary);
    });

    testWidgets('swapping the central palette repaints this page — no local '
        'literal anywhere', (tester) async {
      const swapped = Color(0xFF123456);
      final base = AppTheme.lightTheme;

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: base.copyWith(
              extensions: <ThemeExtension<dynamic>>[
                AppSemanticColors.fromColorScheme(base.colorScheme)
                    .copyWith(primary: swapped),
              ],
            ),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: const LanguageSelectionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final style =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;
      expect(style.backgroundColor!.resolve(const {}), swapped);
    });
  });

  group('responsive', () {
    const sizes = <String, Size>{
      'small 320x568': Size(320, 568),
      'common 360x640': Size(360, 640),
      'tall 390x844': Size(390, 844),
      'large 430x932': Size(430, 932),
      'tablet 768x1024': Size(768, 1024),
    };

    sizes.forEach((name, size) {
      testWidgets('$name lays out without overflow', (tester) async {
        await _pump(tester, size: size);

        expect(tester.takeException(), isNull);
        expect(find.text(_romanUrduTitle), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });
    });

    testWidgets('content is width-capped on a tablet rather than stretched',
        (tester) async {
      await _pump(tester, size: const Size(768, 1024));

      final button = tester.getRect(find.byType(ElevatedButton));
      expect(button.width, lessThanOrEqualTo(480.0));
    });

    testWidgets('a large text scale scrolls instead of overflowing',
        (tester) async {
      await _pump(tester, size: const Size(320, 568), textScale: 2.0);

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
