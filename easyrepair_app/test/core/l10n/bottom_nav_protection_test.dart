import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';
import 'package:handygo_app/features/client/presentation/widgets/client_bottom_nav_bar.dart';
import 'package:handygo_app/features/worker/presentation/widgets/worker_bottom_nav_bar.dart';

/// The navigation bars are explicitly excluded from localization. These labels
/// must read identically in English, Urdu and Roman Urdu.
const clientTabs = ['Home', 'Bookings', 'Chats', 'Profile'];
const workerTabs = ['Home', 'New Jobs', 'My Jobs', 'Chat', 'Profile'];

Future<void> _pumpNav(
  WidgetTester tester,
  Widget navBar,
  AppLocale locale,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale.locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      localeResolutionCallback: (_, _) => locale.locale,
      home: Scaffold(bottomNavigationBar: navBar),
    ),
  );
  await tester.pumpAndSettle();
}

/// Labels in the order they are laid out on screen, left to right.
List<String> _labelsInVisualOrder(WidgetTester tester) {
  final texts = tester.widgetList<Text>(find.byType(Text)).toList();
  final entries = texts
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

void main() {
  group('Client bottom navigation is unaffected by language', () {
    for (final locale in AppLocale.values) {
      testWidgets('labels stay English in ${locale.storageValue}', (
        tester,
      ) async {
        await _pumpNav(tester, const ClientBottomNavBar(currentIndex: 0), locale);

        for (final label in clientTabs) {
          expect(find.text(label), findsOneWidget);
        }
      });

      testWidgets('tab order is unchanged in ${locale.storageValue}', (
        tester,
      ) async {
        await _pumpNav(tester, const ClientBottomNavBar(currentIndex: 0), locale);

        expect(_labelsInVisualOrder(tester), clientTabs);
      });

      testWidgets('renders left-to-right in ${locale.storageValue}', (
        tester,
      ) async {
        await _pumpNav(tester, const ClientBottomNavBar(currentIndex: 0), locale);

        final navContext = tester.element(find.text('Home'));
        expect(Directionality.of(navContext), TextDirection.ltr);
      });
    }

    testWidgets('icons are identical across all three languages', (
      tester,
    ) async {
      final byLocale = <String, List<IconData>>{};
      for (final locale in AppLocale.values) {
        await _pumpNav(
          tester,
          const ClientBottomNavBar(currentIndex: 0),
          locale,
        );
        byLocale[locale.storageValue] = _icons(tester);
      }

      expect(byLocale['ur'], byLocale['en']);
      expect(byLocale['ur_Latn'], byLocale['en']);
      expect(byLocale['en']!.length, clientTabs.length);
    });
  });

  group('Ustaad bottom navigation is unaffected by language', () {
    for (final locale in AppLocale.values) {
      testWidgets('labels stay English in ${locale.storageValue}', (
        tester,
      ) async {
        await _pumpNav(tester, const WorkerBottomNavBar(currentIndex: 0), locale);

        for (final label in workerTabs) {
          expect(find.text(label), findsOneWidget);
        }
      });

      testWidgets('tab order is unchanged in ${locale.storageValue}', (
        tester,
      ) async {
        await _pumpNav(tester, const WorkerBottomNavBar(currentIndex: 0), locale);

        expect(_labelsInVisualOrder(tester), workerTabs);
      });

      testWidgets('renders left-to-right in ${locale.storageValue}', (
        tester,
      ) async {
        await _pumpNav(tester, const WorkerBottomNavBar(currentIndex: 0), locale);

        final navContext = tester.element(find.text('My Jobs'));
        expect(Directionality.of(navContext), TextDirection.ltr);
      });
    }

    testWidgets('icons are identical across all three languages', (
      tester,
    ) async {
      final byLocale = <String, List<IconData>>{};
      for (final locale in AppLocale.values) {
        await _pumpNav(
          tester,
          const WorkerBottomNavBar(currentIndex: 0),
          locale,
        );
        byLocale[locale.storageValue] = _icons(tester);
      }

      expect(byLocale['ur'], byLocale['en']);
      expect(byLocale['ur_Latn'], byLocale['en']);
      expect(byLocale['en']!.length, workerTabs.length);
    });
  });

  test('no navigation label was moved into a translation file', () {
    // A label leaking into an ARB is the first step towards it being
    // translated, so the ARBs are checked directly.
    //
    // Only the distinctive multi-word labels are scanned: single common words
    // like "Chat" or "Home" legitimately appear as screen titles elsewhere, and
    // flagging those would be a false positive. The single words are covered
    // instead by the render assertions above and the source scan below, which
    // together prove the bar itself never consults a translation.
    final distinctiveLabels = {...clientTabs, ...workerTabs}
        .where((label) => label.contains(' '))
        .toSet();
    expect(distinctiveLabels, isNotEmpty);

    // Keys whose English legitimately reads the same as a tab label but which
    // belong to a different surface. The bars themselves consult no
    // localization at all (asserted below), so a shared phrase elsewhere
    // cannot reach them.
    const allowed = {
      'clientJobsTitle': 'My Jobs', // AppBar title of the Client Jobs page
      'workerNewJobsTitle': 'New Jobs', // Worker New Jobs page title
    };

    for (final name in ['app_en.arb', 'app_ur.arb', 'app_ur_Latn.arb']) {
      final arb = jsonDecode(File('lib/l10n/$name').readAsStringSync())
          as Map<String, dynamic>;
      final offenders = arb.entries
          .where((e) => !e.key.startsWith('@'))
          .where((e) => distinctiveLabels.contains(e.value))
          .where((e) => !allowed.containsKey(e.key))
          .map((e) => '${e.key} = "${e.value}"')
          .toList();

      expect(
        offenders,
        isEmpty,
        reason: 'Bottom-navigation labels must not be translated. Found in '
            '$name: $offenders',
      );
    }
  });

  test('no ARB key is named as if it belonged to the navigation bar', () {
    for (final name in ['app_en.arb', 'app_ur.arb', 'app_ur_Latn.arb']) {
      final arb = jsonDecode(File('lib/l10n/$name').readAsStringSync())
          as Map<String, dynamic>;
      final navKeys = arb.keys
          .where((k) => !k.startsWith('@'))
          .where((k) {
            final lower = k.toLowerCase();
            return lower.contains('bottomnav') || lower.contains('navlabel');
          })
          .toList();

      expect(
        navKeys,
        isEmpty,
        reason: 'Navigation labels must stay hard-coded, not live in $name',
      );
    }
  });

  test('the nav bar sources contain no localization lookup', () {
    for (final path in [
      'lib/features/client/presentation/widgets/client_bottom_nav_bar.dart',
      'lib/features/worker/presentation/widgets/worker_bottom_nav_bar.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('context.l10n')));
      expect(source, isNot(contains('AppLocalizations')));
      expect(
        source,
        contains('TextDirection.ltr'),
        reason: '$path must pin itself LTR so Urdu cannot reverse tab order',
      );
    }
  });
}
