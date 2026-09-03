import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/auth/presentation/pages/role_selection_page.dart';

/// The role-selection screen: its bilingual copy, its navigation targets, and
/// that every colour on it comes from the central palette rather than a
/// literal baked into the page.
///
/// Only TWO languages reach this screen through onboarding — Roman Urdu +
/// Easy English, and English — so those are the two asserted here. The Urdu
/// locale still exists in the ARB files and is exercised by the l10n parity
/// tests; it is simply not an onboarding choice.

// ── Approved copy ───────────────────────────────────────────────────────────
// Spelled out verbatim rather than read back from AppLocalizations: reading
// the same source the page reads would pass no matter what the wording became.
const _romanUrdu = (
  heading: 'Aap kya karna chahte hain?',
  subtitle: 'Aik chunein',
  clientTitle: 'Ghar ka kaam karwana hai',
  clientSubtitle:
      'Marammat, safai ya nayi cheez lagwane ke liye Ustaad bulwayein.',
  workerTitle: 'Main Ustaad hoon',
  workerSubtitle: 'Kaam dhoondne ke liye account banayein.',
);

const _english = (
  heading: 'What would you like to do?',
  subtitle: 'Choose an option',
  clientTitle: 'I need a home service',
  clientSubtitle: 'Book an Ustaad for repair, service, or installation.',
  workerTitle: 'I am an Ustaad',
  workerSubtitle: 'Register to find and accept jobs.',
);

Widget _app(
  String initialLocation,
  Map<String, WidgetBuilder> routes, {
  AppLocale locale = AppLocale.romanUrdu,
  ThemeData? theme,
  double textScale = 1.0,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: routes.entries
        .map((e) => GoRoute(path: e.key, builder: (ctx, _) => e.value(ctx)))
        .toList(),
  );
  return MaterialApp.router(
    theme: theme ?? AppTheme.lightTheme,
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
}

/// The page plus stub destinations, so navigation is asserted on the real
/// route strings the page pushes.
Map<String, WidgetBuilder> _routes() => {
      '/auth/role-select': (_) => const RoleSelectionPage(),
      '/auth/client': (_) => const Scaffold(body: Text('CLIENT_PAGE')),
      '/auth/worker/login': (_) =>
          const Scaffold(body: Text('USTAAD_LOGIN_PAGE')),
      // Still routed for old deep links, but the flow must never reach it.
      '/auth/worker/choice': (_) =>
          const Scaffold(body: Text('OBSOLETE_CHOICE_PAGE')),
    };

Future<void> _pump(
  WidgetTester tester, {
  AppLocale locale = AppLocale.romanUrdu,
  ThemeData? theme,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app(
    '/auth/role-select',
    _routes(),
    locale: locale,
    theme: theme,
    textScale: textScale,
  ));
  await tester.pumpAndSettle();
}

/// The bordered box of the card carrying [title] — where the emphasis
/// treatment lives.
BoxDecoration _cardDecoration(WidgetTester tester, String title) {
  final container = tester.widget<AnimatedContainer>(
    find
        .ancestor(
          of: find.text(title),
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  return container.decoration! as BoxDecoration;
}

AppSemanticColors _colors(WidgetTester tester) =>
    tester.element(find.byType(RoleSelectionPage)).semanticColors;

void main() {
  group('Roman Urdu + Easy English copy', () {
    testWidgets('shows the approved wording, exactly', (tester) async {
      await _pump(tester);

      expect(find.text(_romanUrdu.heading), findsOneWidget);
      expect(find.text(_romanUrdu.subtitle), findsOneWidget);
      expect(find.text(_romanUrdu.clientTitle), findsOneWidget);
      expect(find.text(_romanUrdu.clientSubtitle), findsOneWidget);
      expect(find.text(_romanUrdu.workerTitle), findsOneWidget);
      expect(find.text(_romanUrdu.workerSubtitle), findsOneWidget);
    });

    testWidgets('shows no Urdu script — Roman Urdu is a Latin-script choice',
        (tester) async {
      await _pump(tester);

      final urduScript = RegExp(r'[؀-ۿ]');
      final rendered = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((s) => urduScript.hasMatch(s))
          .toList();

      expect(rendered, isEmpty);
    });
  });

  group('English copy', () {
    testWidgets('the whole screen becomes English', (tester) async {
      await _pump(tester, locale: AppLocale.english);

      expect(find.text(_english.heading), findsOneWidget);
      expect(find.text(_english.subtitle), findsOneWidget);
      expect(find.text(_english.clientTitle), findsOneWidget);
      expect(find.text(_english.clientSubtitle), findsOneWidget);
      expect(find.text(_english.workerTitle), findsOneWidget);
      expect(find.text(_english.workerSubtitle), findsOneWidget);
    });

    testWidgets('no Roman Urdu wording leaks through', (tester) async {
      await _pump(tester, locale: AppLocale.english);

      expect(find.text(_romanUrdu.heading), findsNothing);
      expect(find.text(_romanUrdu.clientTitle), findsNothing);
      expect(find.text(_romanUrdu.workerTitle), findsNothing);
    });
  });

  group('navigation is unchanged', () {
    testWidgets('tapping the Client card navigates to /auth/client',
        (tester) async {
      await _pump(tester);

      await tester.tap(find.text(_romanUrdu.clientTitle));
      await tester.pumpAndSettle();

      expect(find.text('CLIENT_PAGE'), findsOneWidget);
    });

    testWidgets('tapping the Ustaad card opens Ustaad Login directly — the '
        'new-or-existing question in between is gone', (tester) async {
      await _pump(tester);

      await tester.tap(find.text(_romanUrdu.workerTitle));
      await tester.pumpAndSettle();

      expect(find.text('USTAAD_LOGIN_PAGE'), findsOneWidget);
      expect(find.text('OBSOLETE_CHOICE_PAGE'), findsNothing,
          reason: 'the obsolete page must never be visited by the flow');
    });

    testWidgets('the same routes are used in English', (tester) async {
      await _pump(tester, locale: AppLocale.english);

      await tester.tap(find.text(_english.workerTitle));
      await tester.pumpAndSettle();

      expect(find.text('USTAAD_LOGIN_PAGE'), findsOneWidget);
    });

    testWidgets('the whole card is tappable, not just its title',
        (tester) async {
      await _pump(tester);

      // The subtitle is inside the same InkWell; tapping it must navigate.
      await tester.tap(find.text(_romanUrdu.clientSubtitle));
      await tester.pumpAndSettle();

      expect(find.text('CLIENT_PAGE'), findsOneWidget);
    });

    testWidgets('a rapid double tap only navigates once (no duplicate push)',
        (tester) async {
      var buildCount = 0;
      await tester.pumpWidget(_app('/auth/role-select', {
        '/auth/role-select': (_) => const RoleSelectionPage(),
        '/auth/client': (_) {
          buildCount++;
          return const Scaffold(body: Text('CLIENT_PAGE'));
        },
      }));

      final clientCard = find.text(_romanUrdu.clientTitle);
      await tester.tap(clientCard);
      await tester.tap(clientCard); // second tap before the 140ms delay elapses
      await tester.pumpAndSettle();

      expect(buildCount, 1);
    });
  });

  group('a stale selection never survives Back', () {
    testWidgets(
      'Worker selected, Back, then Client selected → Client auth opens',
      (tester) async {
        await tester.pumpWidget(_app('/auth/role-select', {
          '/auth/role-select': (_) => const RoleSelectionPage(),
          '/auth/client': (_) => const Scaffold(body: Text('CLIENT_PAGE')),
          '/auth/worker/login': (context) => Scaffold(
                appBar: AppBar(
                  leading: BackButton(onPressed: () => context.pop()),
                ),
                body: const Text('USTAAD_LOGIN_PAGE'),
              ),
        }));

        // Select Worker — pushes Ustaad Login.
        await tester.tap(find.text(_romanUrdu.workerTitle));
        await tester.pumpAndSettle();
        expect(find.text('USTAAD_LOGIN_PAGE'), findsOneWidget);

        // Back to role selection. RoleSelectionPage's State was never
        // disposed (push doesn't dispose the page underneath), so without
        // the fix `_selected` is still 'worker' here.
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text(_romanUrdu.workerTitle), findsOneWidget);

        // The bug: tapping Client now did nothing at all, because the
        // guard `if (_selected != null) return;` was still tripped by the
        // leftover 'worker' value.
        await tester.tap(find.text(_romanUrdu.clientTitle));
        await tester.pumpAndSettle();

        expect(find.text('CLIENT_PAGE'), findsOneWidget);
      },
    );

    testWidgets(
      'Client selected, Back, then Worker selected → Worker choice opens',
      (tester) async {
        await tester.pumpWidget(_app('/auth/role-select', {
          '/auth/role-select': (_) => const RoleSelectionPage(),
          '/auth/client': (context) => Scaffold(
                appBar: AppBar(
                  leading: BackButton(onPressed: () => context.pop()),
                ),
                body: const Text('CLIENT_PAGE'),
              ),
          '/auth/worker/login': (_) =>
              const Scaffold(body: Text('USTAAD_LOGIN_PAGE')),
        }));

        await tester.tap(find.text(_romanUrdu.clientTitle));
        await tester.pumpAndSettle();
        expect(find.text('CLIENT_PAGE'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text(_romanUrdu.clientTitle), findsOneWidget);

        await tester.tap(find.text(_romanUrdu.workerTitle));
        await tester.pumpAndSettle();

        expect(find.text('USTAAD_LOGIN_PAGE'), findsOneWidget);
      },
    );

    testWidgets(
      'a freshly pumped page (app restart) has no temporary role selected — '
      'the very first tap navigates immediately',
      (tester) async {
        await tester.pumpWidget(_app('/auth/role-select', {
          '/auth/role-select': (_) => const RoleSelectionPage(),
          '/auth/client': (_) => const Scaffold(body: Text('CLIENT_PAGE')),
        }));

        await tester.tap(find.text(_romanUrdu.clientTitle));
        await tester.pumpAndSettle();

        expect(find.text('CLIENT_PAGE'), findsOneWidget);
      },
    );
  });

  // A source audit, not a widget test: a widget test cannot observe a colour
  // that was never used, and this page's whole contract is that it uses none.
  // Plain `test`, because `testWidgets` runs inside FakeAsync where real file
  // I/O never completes.
  test('the page source names no palette literal of its own', () {
    // Comments are stripped first: this page's docs describe the rule it
    // follows, so a prose mention of a banned token must not read as a use.
    final source = File(
      'lib/features/auth/presentation/pages/role_selection_page.dart',
    )
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join(' ');

    expect(source, isNot(contains('Color(0x')));
    for (final banned in const [
      'Colors.orange',
      'Colors.green',
      'Colors.teal',
      'Colors.white',
      'Colors.black',
      'Colors.grey',
      'kAuthAccent',
      'kAuthDark',
      'kAuthBg',
      'kAuthGray',
      'kAuthBorder',
    ]) {
      expect(source, isNot(contains(banned)), reason: '$banned is a literal');
    }
    expect(source, isNot(contains('Brightness.dark')),
        reason: 'no page-level dark-mode branching');
  });

  group('colour architecture', () {
    testWidgets('the page background is the semantic background token',
        (tester) async {
      await _pump(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, _colors(tester).background);
    });

    testWidgets('the Client card carries the primary emphasis treatment',
        (tester) async {
      await _pump(tester);
      final colors = _colors(tester);

      final decoration = _cardDecoration(tester, _romanUrdu.clientTitle);
      expect((decoration.border! as Border).top.color, colors.primary);

      // Icon tile is softTeal, icon itself is primary.
      final tile = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.home_rounded),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((tile.decoration! as BoxDecoration).color, colors.softTeal);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.home_rounded)).color,
        colors.primary,
      );
    });

    testWidgets('the Ustaad card stays neutral', (tester) async {
      await _pump(tester);
      final colors = _colors(tester);

      final decoration = _cardDecoration(tester, _romanUrdu.workerTitle);
      expect((decoration.border! as Border).top.color, colors.border);

      final tile = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.handyman_rounded),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((tile.decoration! as BoxDecoration).color, colors.surfaceSubtle);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.handyman_rounded)).color,
        colors.textSecondary,
      );
    });

    testWidgets('headings and body text use the text tokens', (tester) async {
      await _pump(tester);
      final colors = _colors(tester);

      expect(
        tester.widget<Text>(find.text(_romanUrdu.heading)).style!.color,
        colors.textPrimary,
      );
      expect(
        tester.widget<Text>(find.text(_romanUrdu.subtitle)).style!.color,
        colors.textSecondary,
      );
      expect(
        tester.widget<Text>(find.text(_romanUrdu.clientTitle)).style!.color,
        colors.textPrimary,
      );
      expect(
        tester.widget<Text>(find.text(_romanUrdu.clientSubtitle)).style!.color,
        colors.textSecondary,
      );
    });

    testWidgets('changing the central palette repaints the page — no page '
        'edit required', (tester) async {
      // Proves the indirection is real: swap ONLY the theme extension and the
      // background and the emphasized border follow.
      const swappedPrimary = Color(0xFF123456);
      const swappedBackground = Color(0xFF654321);

      final base = AppTheme.lightTheme;
      await _pump(
        tester,
        theme: base.copyWith(
          extensions: <ThemeExtension<dynamic>>[
            AppSemanticColors.light.copyWith(
              primary: swappedPrimary,
              background: swappedBackground,
            ),
          ],
        ),
      );

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        swappedBackground,
      );
      final decoration = _cardDecoration(tester, _romanUrdu.clientTitle);
      expect((decoration.border! as Border).top.color, swappedPrimary);
    });

  });

  group('dark mode needs no page-level logic', () {
    testWidgets('the same page renders from the dark palette', (tester) async {
      await _pump(tester, theme: AppTheme.darkTheme);

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppSemanticColors.dark.background,
      );
      final decoration = _cardDecoration(tester, _romanUrdu.clientTitle);
      expect(
        (decoration.border! as Border).top.color,
        AppSemanticColors.dark.primary,
      );
      expect(
        tester.widget<Text>(find.text(_romanUrdu.heading)).style!.color,
        AppSemanticColors.dark.textPrimary,
      );
    });
  });

  group('responsive — no overflow on any supported size', () {
    const sizes = <String, Size>{
      'iPhone SE / small Android 320x568': Size(320, 568),
      'common Android 360x640': Size(360, 640),
      'iPhone 14 390x844': Size(390, 844),
      'iPhone 16 Pro Max 430x932': Size(430, 932),
      'tablet-ish 768x1024': Size(768, 1024),
    };

    sizes.forEach((name, size) {
      testWidgets('$name lays out without overflow', (tester) async {
        await _pump(tester, size: size);

        expect(tester.takeException(), isNull);
        expect(find.text(_romanUrdu.clientTitle), findsOneWidget);
        expect(find.text(_romanUrdu.workerTitle), findsOneWidget);
      });
    });

    testWidgets('cards are constrained on a tablet rather than stretched',
        (tester) async {
      await _pump(tester, size: const Size(768, 1024));

      final card = tester.getRect(
        find
            .ancestor(
              of: find.text(_romanUrdu.clientTitle),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(card.width, lessThanOrEqualTo(460.0 - 48));
    });

    testWidgets('cards keep an accessible tap target', (tester) async {
      await _pump(tester);

      for (final title in [_romanUrdu.clientTitle, _romanUrdu.workerTitle]) {
        final card = tester.getRect(
          find
              .ancestor(of: find.text(title), matching: find.byType(InkWell))
              .first,
        );
        expect(card.height, greaterThanOrEqualTo(48.0));
      }
    });

    for (final scale in const [1.3, 1.6, 2.0]) {
      testWidgets('text scale ${scale}x does not overflow or clip',
          (tester) async {
        await _pump(
          tester,
          size: const Size(320, 568),
          textScale: scale,
        );

        expect(tester.takeException(), isNull);
        expect(find.text(_romanUrdu.clientTitle), findsOneWidget);
        expect(find.text(_romanUrdu.workerTitle), findsOneWidget);
      });
    }

    testWidgets('an extreme text scale scrolls rather than overflowing',
        (tester) async {
      await _pump(tester, size: const Size(320, 568), textScale: 3.0);

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('each option is one button node carrying its full wording',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);

      for (final (title, subtitle) in [
        (_romanUrdu.clientTitle, _romanUrdu.clientSubtitle),
        (_romanUrdu.workerTitle, _romanUrdu.workerSubtitle),
      ]) {
        expect(
          find.bySemanticsLabel('$title\n$subtitle'),
          findsOneWidget,
          reason: 'the card reads as a single labelled control',
        );
      }

      handle.dispose();
    });
  });
}
