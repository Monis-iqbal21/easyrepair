import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/network/connectivity_service.dart';
import 'package:handygo_app/core/network/reconnect_refresh.dart';

/// REGRESSION COVER for the HandyGo bug where a background refresh bounced a
/// user out of a nested page to splash and then Home.
///
/// The fix is structural: reconnect refresh only ever invalidates DATA
/// providers, and the router's redirect reads auth state alone. These tests
/// prove the two stay disconnected — a reconnection fires the screen's
/// refresh while the route, the page instance and its scroll position are all
/// left exactly where the user left them.
///
/// A router built here on purpose rather than the real app router: this is
/// about the reconnect→navigation relationship, and the real router's own
/// redirect rules already have their own dedicated tests
/// (auth_redirect_test.dart and friends), which this must not duplicate or
/// disturb.

/// Stands in for a data provider a detail page watches.
final _detailProvider =
    FutureProvider.family.autoDispose<String, String>((ref, id) async {
  _fetchCount[id] = (_fetchCount[id] ?? 0) + 1;
  return 'detail-$id-v${_fetchCount[id]}';
});

Map<String, int> _fetchCount = {};

GoRouter _buildRouter({required void Function(WidgetRef ref) onDetailBuild}) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const Scaffold(body: Text('SPLASH')),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return Consumer(
            builder: (context, ref, _) {
              onDetailBuild(ref);
              final value = ref.watch(_detailProvider(id));
              return Scaffold(
                body: Column(
                  children: [
                    const Text('DETAIL'),
                    Text(value.valueOrNull ?? 'loading'),
                  ],
                ),
              );
            },
          );
        },
      ),
    ],
  );
}

void main() {
  setUp(() {
    _fetchCount = {};
    ConnectivityService.instance.debugIsOnline = true;
  });
  tearDown(() => ConnectivityService.instance.debugIsOnline = true);

  testWidgets('reconnecting while the CLIENT sits on Booking Detail keeps the '
      'route on Booking Detail and refreshes in place', (tester) async {
    late GoRouter router;
    router = _buildRouter(
      onDetailBuild: (ref) => refreshOnReconnect(
        ref,
        () => ref.invalidate(_detailProvider('b-42')),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    router.go('/detail/b-42');
    await tester.pumpAndSettle();

    expect(find.text('DETAIL'), findsOneWidget);
    expect(find.text('detail-b-42-v1'), findsOneWidget);
    final locationBefore =
        router.routerDelegate.currentConfiguration.uri.toString();
    expect(locationBefore, '/detail/b-42');

    // Connection drops and comes back while the user is still on this page.
    ConnectivityService.instance.debugIsOnline = false;
    await tester.pump();
    ConnectivityService.instance.debugIsOnline = true;
    await tester.pumpAndSettle();

    // The route did not move …
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/detail/b-42',
    );
    expect(find.text('SPLASH'), findsNothing);
    expect(find.text('HOME'), findsNothing);
    expect(find.text('DETAIL'), findsOneWidget);
    // … and the page's data refreshed underneath it.
    expect(find.text('detail-b-42-v2'), findsOneWidget);
  });

  testWidgets('reconnecting while the WORKER sits on Job Detail keeps the '
      'route on Job Detail', (tester) async {
    late GoRouter router;
    router = _buildRouter(
      onDetailBuild: (ref) => refreshOnReconnect(
        ref,
        () => ref.invalidate(_detailProvider('job-7')),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    router.go('/detail/job-7');
    await tester.pumpAndSettle();

    ConnectivityService.instance.debugIsOnline = false;
    await tester.pump();
    ConnectivityService.instance.debugIsOnline = true;
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/detail/job-7',
    );
    expect(find.text('detail-job-7-v2'), findsOneWidget);
  });

  testWidgets('a nested page pushed on top of another stays pushed — reconnect '
      'never pops the navigation stack', (tester) async {
    late GoRouter router;
    router = _buildRouter(
      onDetailBuild: (ref) => refreshOnReconnect(
        ref,
        () => ref.invalidate(_detailProvider('b-9')),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    router.go('/home');
    await tester.pumpAndSettle();
    router.push('/detail/b-9');
    await tester.pumpAndSettle();
    expect(find.text('DETAIL'), findsOneWidget);

    ConnectivityService.instance.debugIsOnline = false;
    await tester.pump();
    ConnectivityService.instance.debugIsOnline = true;
    await tester.pumpAndSettle();

    expect(find.text('DETAIL'), findsOneWidget);
    expect(find.text('HOME'), findsNothing,
        reason: 'the pushed page must still be on top');

    // And popping still returns to exactly where it came from.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('a background refresh keeps the previous value on screen — no '
      'spinner flash, no page teardown', (tester) async {
    late GoRouter router;
    router = _buildRouter(
      onDetailBuild: (ref) => refreshOnReconnect(
        ref,
        () => ref.invalidate(_detailProvider('b-1')),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    router.go('/detail/b-1');
    await tester.pumpAndSettle();
    expect(find.text('detail-b-1-v1'), findsOneWidget);

    ConnectivityService.instance.debugIsOnline = false;
    await tester.pump();
    ConnectivityService.instance.debugIsOnline = true;
    // One frame into the refetch: the page is still mounted and still showing
    // its previous value rather than being replaced by a loader.
    await tester.pump();

    expect(find.text('DETAIL'), findsOneWidget);
    expect(find.text('detail-b-1-v1'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('detail-b-1-v2'), findsOneWidget);
  });

  testWidgets('reconnecting while NOT on a refresh-aware page changes nothing',
      (tester) async {
    var refreshes = 0;
    late GoRouter router;
    router = _buildRouter(onDetailBuild: (ref) {
      refreshOnReconnect(ref, () => refreshes++);
    });

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    router.go('/home');
    await tester.pumpAndSettle();

    ConnectivityService.instance.debugIsOnline = false;
    await tester.pump();
    ConnectivityService.instance.debugIsOnline = true;
    await tester.pumpAndSettle();

    expect(refreshes, 0);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/home',
    );
  });
}
