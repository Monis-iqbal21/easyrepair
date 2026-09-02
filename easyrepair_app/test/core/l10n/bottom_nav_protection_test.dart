import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/features/client/presentation/widgets/client_bottom_nav_bar.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_nav_indicator_providers.dart';
import 'package:handygo_app/features/worker/presentation/widgets/worker_bottom_nav_bar.dart';
import 'package:handygo_app/l10n/app_localizations.dart';

import '../../support/l10n_test_app.dart';

/// The navigation bars are translated, but their *layout* is not negotiable:
/// tab order, icons and reading direction must be identical in English, Urdu
/// and Roman Urdu. Urdu RTL must never flip Home away from the left edge —
/// muscle memory for a tab bar is positional, not linguistic.
///
/// Labels are asserted against the generated AppLocalizations rather than
/// against literals, so this file only needs editing when a tab is added,
/// removed or reordered — not every time a translation is reworded.

/// The label lookups each bar uses, in on-screen order.
List<String> clientTabs(AppLocalizations l) => [
  l.navHome,
  l.navBookings,
  l.chatTitleFallback,
  l.clientProfileTitle,
];

List<String> workerTabs(AppLocalizations l) => [
  l.navHome,
  l.workerNewJobsTitle,
  l.clientJobsTitle,
  l.chatTitleFallback,
  l.clientProfileTitle,
];

/// Both bars are pumped with every Ustaad nav indicator forced quiet.
///
/// This file protects *layout* — tab order, icons, reading direction — and a
/// badge is state, not layout. Pinning the indicators to "nothing to report"
/// keeps these assertions about the bar itself; the badges have their own
/// tests in test/features/worker/worker_nav_indicators_test.dart.
Future<void> _pumpNav(
  WidgetTester tester,
  Widget navBar,
  AppLocale locale,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workerUnreadConversationCountProvider.overrideWithValue(0),
        workerHasOngoingJobProvider.overrideWithValue(false),
      ],
      child: localizedApp(Scaffold(bottomNavigationBar: navBar), locale: locale),
    ),
  );
  await tester.pumpAndSettle();
}

/// Labels in the order they are laid out on screen, left to right.
List<String> _labelsInVisualOrder(WidgetTester tester) {
  final texts = tester.widgetList<Text>(find.byType(Text)).toList();
  final entries =
      texts
          .map(
            (t) => (
              label: t.data ?? '',
              dx: tester.getTopLeft(find.byWidget(t)).dx,
            ),
          )
          .toList()
        ..sort((a, b) => a.dx.compareTo(b.dx));
  return entries.map((e) => e.label).toList();
}

List<IconData> _icons(WidgetTester tester) {
  return tester
      .widgetList<Icon>(find.byType(Icon))
      .map((i) => i.icon!)
      .toList();
}

Future<AppLocalizations> _l10nFor(AppLocale locale) =>
    AppLocalizations.delegate.load(locale.locale);

void main() {
  for (final (name, barBuilder, tabsFor)
      in <(String, Widget Function(), List<String> Function(AppLocalizations))>[
        ('Client', () => const ClientBottomNavBar(currentIndex: 0), clientTabs),
        ('Ustaad', () => const WorkerBottomNavBar(currentIndex: 0), workerTabs),
      ]) {
    group('$name bottom navigation', () {
      for (final locale in AppLocale.values) {
        testWidgets('labels are translated in ${locale.storageValue}', (
          tester,
        ) async {
          final l10n = await _l10nFor(locale);
          await _pumpNav(tester, barBuilder(), locale);

          for (final label in tabsFor(l10n)) {
            expect(find.text(label), findsOneWidget, reason: 'missing: $label');
          }
        });

        testWidgets('tab order is unchanged in ${locale.storageValue}', (
          tester,
        ) async {
          final l10n = await _l10nFor(locale);
          await _pumpNav(tester, barBuilder(), locale);

          // Left-to-right on screen, in the same sequence in every language.
          expect(_labelsInVisualOrder(tester), tabsFor(l10n));
        });

        testWidgets('renders left-to-right in ${locale.storageValue}', (
          tester,
        ) async {
          final l10n = await _l10nFor(locale);
          await _pumpNav(tester, barBuilder(), locale);

          final navContext = tester.element(find.text(tabsFor(l10n).first));
          expect(Directionality.of(navContext), TextDirection.ltr);
        });
      }

      testWidgets('icons are identical across all three languages', (
        tester,
      ) async {
        final byLocale = <String, List<IconData>>{};
        for (final locale in AppLocale.values) {
          await _pumpNav(tester, barBuilder(), locale);
          byLocale[locale.storageValue] = _icons(tester);
        }

        expect(byLocale['ur'], byLocale['en']);
        expect(byLocale['ur_Latn'], byLocale['en']);
        final l10n = await _l10nFor(AppLocale.english);
        expect(byLocale['en']!.length, tabsFor(l10n).length);
      });

      testWidgets('Urdu actually changes the wording', (tester) async {
        // Guards against a bar that consults localization but was wired to
        // keys carrying the same text in every language — which would satisfy
        // every assertion above while still shipping English to Urdu readers.
        final en = tabsFor(await _l10nFor(AppLocale.english));
        final ur = tabsFor(await _l10nFor(AppLocale.urdu));

        expect(ur, isNot(en));
        final urduScript = RegExp(r'[؀-ۿ]');
        for (final label in ur) {
          expect(
            urduScript.hasMatch(label),
            isTrue,
            reason: 'not Urdu script: $label',
          );
        }
      });
    });
  }

  test('the nav bars pin themselves left-to-right', () {
    for (final path in [
      'lib/features/client/presentation/widgets/client_bottom_nav_bar.dart',
      'lib/features/worker/presentation/widgets/worker_bottom_nav_bar.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('TextDirection.ltr'),
        reason: '$path must pin itself LTR so Urdu cannot reverse tab order',
      );
    }
  });
}
