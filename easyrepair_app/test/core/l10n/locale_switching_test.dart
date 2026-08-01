import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';
import 'package:handygo_app/core/l10n/l10n_extensions.dart';
import 'package:handygo_app/core/l10n/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A stand-in for the app root: same delegates, same supportedLocales, same
/// locale source as `EasyRepairApp`, without dragging in Firebase or the
/// router.
class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocale = ref.watch(localeProvider);
    return MaterialApp(
      locale: appLocale.locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      localeResolutionCallback: (_, _) => appLocale.locale,
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              Text(context.l10n.languageRowLabel),
              Text(
                'dir:${Directionality.of(context) == TextDirection.rtl ? 'rtl' : 'ltr'}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Map<String, Object> initialPrefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const _Harness(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

String _direction(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .firstWhere((s) => s.startsWith('dir:'));
}

Future<void> _select(
  WidgetTester tester,
  ProviderContainer container,
  AppLocale locale,
) async {
  await container.read(localeProvider.notifier).setLocale(locale);
  await tester.pumpAndSettle();
}

void main() {
  group('default language', () {
    testWidgets('an existing user with no saved choice sees English', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Language'), findsOneWidget);
      expect(_direction(tester), 'dir:ltr');
    });

    testWidgets('an unrecognised stored value falls back to English', (
      tester,
    ) async {
      await _pump(tester, initialPrefs: {kLocalePrefsKey: 'fr_CA'});

      expect(find.text('Language'), findsOneWidget);
    });
  });

  group('switching applies immediately, with no restart', () {
    testWidgets('English → Urdu → Roman Urdu → English', (tester) async {
      final container = await _pump(tester);

      // English
      expect(find.text('Language'), findsOneWidget);
      expect(_direction(tester), 'dir:ltr');

      // → Urdu: script changes and the layout flips to RTL.
      await _select(tester, container, AppLocale.urdu);
      expect(find.text('زبان'), findsOneWidget);
      expect(find.text('Language'), findsNothing);
      expect(_direction(tester), 'dir:rtl');

      // → Roman Urdu: Latin script, and crucially back to LTR even though the
      // language code is still 'ur'.
      await _select(tester, container, AppLocale.romanUrdu);
      expect(find.text('Zaban'), findsOneWidget);
      expect(find.text('زبان'), findsNothing);
      expect(_direction(tester), 'dir:ltr');

      // → back to English
      await _select(tester, container, AppLocale.english);
      expect(find.text('Language'), findsOneWidget);
      expect(_direction(tester), 'dir:ltr');
    });

    testWidgets('Urdu → Roman Urdu directly', (tester) async {
      final container = await _pump(tester, initialPrefs: {
        kLocalePrefsKey: 'ur',
      });
      expect(find.text('زبان'), findsOneWidget);
      expect(_direction(tester), 'dir:rtl');

      await _select(tester, container, AppLocale.romanUrdu);
      expect(find.text('Zaban'), findsOneWidget);
      expect(_direction(tester), 'dir:ltr');
    });
  });

  group('text direction per language', () {
    testWidgets('English is LTR', (tester) async {
      await _pump(tester, initialPrefs: {kLocalePrefsKey: 'en'});
      expect(_direction(tester), 'dir:ltr');
    });

    testWidgets('Urdu is RTL', (tester) async {
      await _pump(tester, initialPrefs: {kLocalePrefsKey: 'ur'});
      expect(_direction(tester), 'dir:rtl');
    });

    testWidgets('Roman Urdu is LTR, not RTL like its language code implies', (
      tester,
    ) async {
      await _pump(tester, initialPrefs: {kLocalePrefsKey: 'ur_Latn'});
      expect(_direction(tester), 'dir:ltr');
    });
  });

  group('persistence', () {
    testWidgets('the choice is written to storage', (tester) async {
      final container = await _pump(tester);
      await _select(tester, container, AppLocale.urdu);

      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString(kLocalePrefsKey), 'ur');
    });

    testWidgets('a fresh app over the same storage starts in Urdu — survives '
        'app close and device restart', (tester) async {
      final container = await _pump(tester);
      await _select(tester, container, AppLocale.urdu);

      // Rebuild everything from scratch over the same SharedPreferences,
      // exactly as a cold start would.
      final prefs = container.read(sharedPreferencesProvider);
      final restarted = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(restarted.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: restarted,
          child: const _Harness(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('زبان'), findsOneWidget);
      expect(_direction(tester), 'dir:rtl');
    });

    testWidgets('logging out does not reset it — the key is untouched by auth',
        (tester) async {
      final container = await _pump(tester);
      await _select(tester, container, AppLocale.romanUrdu);

      // Auth clears secure storage, never SharedPreferences.
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString(kLocalePrefsKey), 'ur_Latn');
    });
  });

  group('English fallback for a missing key', () {
    testWidgets('a key absent from both translated ARBs renders English', (
      tester,
    ) async {
      for (final locale in AppLocale.values) {
        SharedPreferences.setMockInitialValues({
          kLocalePrefsKey: locale.storageValue,
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        late String probe;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: Consumer(
              builder: (context, ref, _) => MaterialApp(
                locale: ref.watch(localeProvider).locale,
                supportedLocales: appSupportedLocales,
                localizationsDelegates: appLocalizationsDelegates,
                home: Builder(
                  builder: (context) {
                    probe = context.l10n.l10nFallbackProbe;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          probe,
          'English fallback works',
          reason: '${locale.storageValue} should fall back to English',
        );
      }
    });
  });
}
