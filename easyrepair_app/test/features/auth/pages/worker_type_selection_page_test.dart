import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/features/auth/presentation/pages/worker_type_selection_page.dart';

Widget _app(Map<String, WidgetBuilder> routes, {String initial = '/choice'}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: routes.entries
        .map((e) => GoRoute(path: e.key, builder: (ctx, _) => e.value(ctx)))
        .toList(),
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  group('WorkerTypeSelectionPage', () {
    testWidgets('tapping "new Ustaad" navigates to /auth/worker/register', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app({
          '/choice': (_) => const WorkerTypeSelectionPage(),
          '/auth/worker/register': (_) =>
              const Scaffold(body: Text('REGISTER_PAGE')),
        }),
      );

      await tester.tap(find.text('Main naya Ustaad hoon'));
      await tester.pumpAndSettle();

      expect(find.text('REGISTER_PAGE'), findsOneWidget);
    });

    testWidgets('tapping "existing Ustaad" navigates to /auth/worker/login', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app({
          '/choice': (_) => const WorkerTypeSelectionPage(),
          '/auth/worker/login': (_) =>
              const Scaffold(body: Text('LOGIN_PAGE')),
        }),
      );

      await tester.tap(find.text('Mera account pehle se bana hua hai'));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN_PAGE'), findsOneWidget);
    });

    testWidgets('back button pops without navigating to either choice', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app({
          '/entry': (_) => Builder(
                builder: (ctx) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => ctx.push('/choice'),
                    child: const Text('go to choice'),
                  ),
                ),
              ),
          '/choice': (_) => const WorkerTypeSelectionPage(),
        }, initial: '/entry'),
      );

      await tester.tap(find.text('go to choice'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkerTypeSelectionPage), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('go to choice'), findsOneWidget);
      expect(find.byType(WorkerTypeSelectionPage), findsNothing);
    });
  });
}
