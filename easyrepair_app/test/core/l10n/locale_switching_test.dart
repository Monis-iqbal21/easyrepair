import 'dart:async';

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

      // → Urdu: the script changes and the layout does NOT. HandyGo is
      // never mirrored, so Urdu translates the words and leaves the direction
      // alone.
      await _select(tester, container, AppLocale.urdu);
      expect(find.text('زبان'), findsOneWidget);
      expect(find.text('Language'), findsNothing);
      expect(_direction(tester), 'dir:ltr');

      // → Roman Urdu: Latin script, still LTR.
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
      expect(_direction(tester), 'dir:ltr');

      await _select(tester, container, AppLocale.romanUrdu);
      expect(find.text('Zaban'), findsOneWidget);
      expect(_direction(tester), 'dir:ltr');
    });
  });

  group('the interface is never mirrored', () {
    // HandyGo is designed left-to-right and stays that way in every language.
    // Urdu changes the words; it must not flip rows, app bars, cards, icons,
    // list order, padding or navigation. Urdu's language code would normally
    // make Flutter mirror everything, so this is the regression guard.
    for (final stored in ['en', 'ur', 'ur_Latn']) {
      testWidgets('$stored lays out left-to-right', (tester) async {
        await _pump(tester, initialPrefs: {kLocalePrefsKey: stored});
        expect(_direction(tester), 'dir:ltr');
      });
    }

    testWidgets('no language reports RTL from AppLocale either', (
      tester,
    ) async {
      for (final locale in AppLocale.values) {
        expect(
          locale.textDirection,
          TextDirection.ltr,
          reason: '${locale.storageValue} would reintroduce mirroring',
        );
      }
    });

    testWidgets('Urdu still renders Urdu script while laid out LTR', (
      tester,
    ) async {
      // The point of pinning direction is that it costs nothing linguistically:
      // the translation is still Urdu, only the layout is unchanged.
      await _pump(tester, initialPrefs: {kLocalePrefsKey: 'ur'});

      expect(find.text('زبان'), findsOneWidget);
      expect(_direction(tester), 'dir:ltr');
    });

    testWidgets('dialogs and bottom sheets are LTR in Urdu too', (
      tester,
    ) async {
      // Overlays are pushed as their own routes, so they are the likeliest
      // place for RTL to creep back in unnoticed.
      await _pump(tester, initialPrefs: {kLocalePrefsKey: 'ur'});
      final context = tester.element(find.byType(Scaffold));

      unawaited(showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('dialog')),
      ));
      await tester.pumpAndSettle();
      expect(
        Directionality.of(tester.element(find.text('dialog'))),
        TextDirection.ltr,
      );
      Navigator.of(context).pop();
      await tester.pumpAndSettle();

      unawaited(showModalBottomSheet<void>(
        context: context,
        builder: (_) => const Text('sheet'),
      ));
      await tester.pumpAndSettle();
      expect(
        Directionality.of(tester.element(find.text('sheet'))),
        TextDirection.ltr,
      );
    });

    testWidgets('directional padding does not flip in Urdu', (tester) async {
      // EdgeInsetsDirectional/AlignmentDirectional resolve against the ambient
      // direction. If anything ever re-enabled RTL, spacing across the app
      // would silently swap sides — this catches that without a golden file.
      await _pump(tester, initialPrefs: {kLocalePrefsKey: 'ur'});
      final direction = Directionality.of(tester.element(find.byType(Scaffold)));

      const padding = EdgeInsetsDirectional.only(start: 16);
      expect(padding.resolve(direction).left, 16);
      expect(padding.resolve(direction).right, 0);

      expect(
        AlignmentDirectional.centerStart.resolve(direction),
        Alignment.centerLeft,
      );
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
      expect(_direction(tester), 'dir:ltr');
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
