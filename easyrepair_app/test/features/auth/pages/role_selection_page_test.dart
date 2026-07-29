import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/features/auth/presentation/pages/role_selection_page.dart';

Widget _app(String initialLocation, Map<String, WidgetBuilder> routes) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: routes.entries
        .map((e) => GoRoute(path: e.key, builder: (ctx, _) => e.value(ctx)))
        .toList(),
  );
  return MaterialApp.router(routerConfig: router);
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
}
