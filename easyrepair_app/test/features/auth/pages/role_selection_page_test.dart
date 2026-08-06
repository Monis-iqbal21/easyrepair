import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/features/auth/presentation/pages/role_selection_page.dart';

Widget _app(String initialLocation, Map<String, WidgetBuilder> routes) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: routes.entries
        .map((e) => GoRoute(path: e.key, builder: (ctx, _) => e.value(ctx)))
        .toList(),
  );
  return MaterialApp.router(
      routerConfig: router,
      locale: AppLocale.romanUrdu.locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      localeResolutionCallback: (_, _) => AppLocale.romanUrdu.locale,
    );
}

void main() {
  group('RoleSelectionPage', () {
    testWidgets('tapping the Client card navigates to /auth/client', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app('/auth/role-select', {
          '/auth/role-select': (_) => const RoleSelectionPage(),
          '/auth/client': (_) => const Scaffold(body: Text('CLIENT_PAGE')),
          '/auth/worker/choice': (_) =>
              const Scaffold(body: Text('WORKER_CHOICE_PAGE')),
        }),
      );

      expect(
        find.text('Mujhe ghar ke kaam ke liye Ustaad chahiye'),
        findsOneWidget,
      );
      await tester.tap(
        find.text('Mujhe ghar ke kaam ke liye Ustaad chahiye'),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT_PAGE'), findsOneWidget);
    });

    testWidgets('tapping the Ustaad card navigates to /auth/worker/choice', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app('/auth/role-select', {
          '/auth/role-select': (_) => const RoleSelectionPage(),
          '/auth/client': (_) => const Scaffold(body: Text('CLIENT_PAGE')),
          '/auth/worker/choice': (_) =>
              const Scaffold(body: Text('WORKER_CHOICE_PAGE')),
        }),
      );

      await tester.tap(
        find.text('Main Ustaad hoon aur kaam hasil karna chahta hoon'),
      );
      await tester.pumpAndSettle();

      expect(find.text('WORKER_CHOICE_PAGE'), findsOneWidget);
    });

    testWidgets('a rapid double tap only navigates once (no duplicate push)', (
      tester,
    ) async {
      var buildCount = 0;
      await tester.pumpWidget(
        _app('/auth/role-select', {
          '/auth/role-select': (_) => const RoleSelectionPage(),
          '/auth/client': (_) {
            buildCount++;
            return const Scaffold(body: Text('CLIENT_PAGE'));
          },
        }),
      );

      final clientCard =
          find.text('Mujhe ghar ke kaam ke liye Ustaad chahiye');
      await tester.tap(clientCard);
      await tester.tap(clientCard); // second tap before the 140ms delay elapses
      await tester.pumpAndSettle();

      expect(buildCount, 1);
    });
  });

  group('a stale selection never survives Back', () {
    const clientCardText = 'Mujhe ghar ke kaam ke liye Ustaad chahiye';
    const workerCardText = 'Main Ustaad hoon aur kaam hasil karna chahta hoon';

    testWidgets(
      'Worker selected, Back, then Client selected → Client auth opens',
      (tester) async {
        await tester.pumpWidget(
          _app('/auth/role-select', {
            '/auth/role-select': (_) => const RoleSelectionPage(),
            '/auth/client': (_) => const Scaffold(body: Text('CLIENT_PAGE')),
            '/auth/worker/choice': (context) => Scaffold(
                  appBar: AppBar(
                    leading: BackButton(onPressed: () => context.pop()),
                  ),
                  body: const Text('WORKER_CHOICE_PAGE'),
                ),
          }),
        );

        // Select Worker — pushes /auth/worker/choice.
        await tester.tap(find.text(workerCardText));
        await tester.pumpAndSettle();
        expect(find.text('WORKER_CHOICE_PAGE'), findsOneWidget);

        // Back to role selection. RoleSelectionPage's State was never
        // disposed (push doesn't dispose the page underneath), so without
        // the fix `_selected` is still 'worker' here.
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text(workerCardText), findsOneWidget);

        // The bug: tapping Client now did nothing at all, because the
        // guard `if (_selected != null) return;` was still tripped by the
        // leftover 'worker' value.
        await tester.tap(find.text(clientCardText));
        await tester.pumpAndSettle();

        expect(find.text('CLIENT_PAGE'), findsOneWidget);
      },
    );

    testWidgets(
      'Client selected, Back, then Worker selected → Worker choice opens',
      (tester) async {
        await tester.pumpWidget(
          _app('/auth/role-select', {
            '/auth/role-select': (_) => const RoleSelectionPage(),
            '/auth/client': (context) => Scaffold(
                  appBar: AppBar(
                    leading: BackButton(onPressed: () => context.pop()),
                  ),
                  body: const Text('CLIENT_PAGE'),
                ),
            '/auth/worker/choice': (_) =>
                const Scaffold(body: Text('WORKER_CHOICE_PAGE')),
          }),
        );

        await tester.tap(find.text(clientCardText));
        await tester.pumpAndSettle();
        expect(find.text('CLIENT_PAGE'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text(clientCardText), findsOneWidget);

        await tester.tap(find.text(workerCardText));
        await tester.pumpAndSettle();

        expect(find.text('WORKER_CHOICE_PAGE'), findsOneWidget);
      },
    );

    testWidgets(
      'a freshly pumped page (app restart) has no temporary role selected — '
      'the very first tap navigates immediately',
      (tester) async {
        await tester.pumpWidget(
          _app('/auth/role-select', {
            '/auth/role-select': (_) => const RoleSelectionPage(),
            '/auth/client': (_) => const Scaffold(body: Text('CLIENT_PAGE')),
          }),
        );

        await tester.tap(find.text(clientCardText));
        await tester.pumpAndSettle();

        expect(find.text('CLIENT_PAGE'), findsOneWidget);
      },
    );
  });
}
