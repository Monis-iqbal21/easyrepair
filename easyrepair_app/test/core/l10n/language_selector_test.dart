import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/locale_provider.dart';
import 'package:handygo_app/core/presentation/widgets/language_selector_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n_test_app.dart';

Future<ProviderContainer> _openSheet(
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
      child: Consumer(
        builder: (context, ref, _) => localizedApp(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showLanguageSelectorSheet(context),
                child: const Text('OPEN'),
              ),
            ),
          ),
          locale: ref.watch(localeProvider),
        ),
      ),
    ),
  );
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows exactly the three required options, each in its own '
      'script', (tester) async {
    await _openSheet(tester);

    expect(find.text('English'), findsOneWidget);
    expect(find.text('اردو'), findsOneWidget);
    expect(find.text('Roman Urdu'), findsOneWidget);
  });

  // One test per starting language: each needs its own widget tree, since
  // re-pumping over a still-open sheet leaves the modal barrier in place.
  for (final start in AppLocale.values) {
    testWidgets('option labels are identical when the app is already in '
        '${start.storageValue}', (tester) async {
      await _openSheet(tester, initialPrefs: {
        kLocalePrefsKey: start.storageValue,
      });

      expect(find.text('English'), findsOneWidget);
      expect(find.text('اردو'), findsOneWidget);
      expect(find.text('Roman Urdu'), findsOneWidget);
    });
  }

  testWidgets('the active language is check-marked', (tester) async {
    await _openSheet(tester, initialPrefs: {kLocalePrefsKey: 'ur'});

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('picking Urdu applies it and closes the sheet', (tester) async {
    final container = await _openSheet(tester);

    await tester.tap(find.text('اردو'));
    await tester.pumpAndSettle();

    expect(container.read(localeProvider), AppLocale.urdu);
    // Sheet dismissed.
    expect(find.text('Roman Urdu'), findsNothing);
    // And persisted.
    expect(
      container.read(sharedPreferencesProvider).getString(kLocalePrefsKey),
      'ur',
    );
  });

  testWidgets('picking Roman Urdu persists ur_Latn', (tester) async {
    // Starts from English (not the Roman Urdu default) so tapping "Roman
    // Urdu" is a real selection — setLocale is a no-op when reselecting the
    // already-current value, which would leave storage unwritten.
    final container =
        await _openSheet(tester, initialPrefs: {kLocalePrefsKey: 'en'});

    await tester.tap(find.text('Roman Urdu'));
    await tester.pumpAndSettle();

    expect(container.read(localeProvider), AppLocale.romanUrdu);
    expect(
      container.read(sharedPreferencesProvider).getString(kLocalePrefsKey),
      'ur_Latn',
    );
  });

  testWidgets('every option is laid out identically, including اردو', (
    tester,
  ) async {
    // The three rows must read as one list. Wrapping the Urdu endonym in an
    // RTL Directionality would push it to the opposite edge from the other
    // two — the mirroring HandyGo does not do. The Urdu glyphs shape correctly
    // without it.
    await _openSheet(tester);

    for (final label in ['English', 'اردو', 'Roman Urdu']) {
      expect(
        Directionality.of(tester.element(find.text(label))),
        TextDirection.ltr,
        reason: '$label is laid out differently from the other options',
      );
    }

    // …and they all start at the same left edge.
    final lefts = ['English', 'اردو', 'Roman Urdu']
        .map((l) => tester.getTopLeft(find.text(l)).dx)
        .toSet();
    expect(lefts, hasLength(1), reason: 'options are not left-aligned together');
  });
}
