import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';
import 'package:handygo_app/core/router/app_router.dart';
import 'package:handygo_app/core/router/page_not_available_page.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';

const _client = UserEntity(
  id: 'c1',
  phone: '+923001234567',
  role: 'CLIENT',
  firstName: 'Ali',
  lastName: 'Khan',
);

const _worker = UserEntity(
  id: 'w1',
  phone: '+923001234568',
  role: 'WORKER',
  firstName: 'Bilal',
  lastName: 'Ahmed',
);

const _suspendedWorker = UserEntity(
  id: 'w2',
  phone: '+923001234569',
  role: 'WORKER',
  firstName: 'Usman',
  lastName: 'Tariq',
  workerStatus: 'SUSPENDED',
);

Widget _stub(String label) => Scaffold(body: Center(child: Text(label)));

/// A minimal GoRouter carrying exactly the pieces this test exercises:
/// the same top-level `redirect` (built from the same exported pure
/// functions app_router.dart's real router uses) and the same
/// `errorBuilder`. Deliberately does not pull in the full page tree — this
/// is testing the *wiring* (does redirect run before/instead of the error
/// page; does the error page's Go Home button resolve correctly), which
/// the already-covered pure-function tests (auth_redirect_test.dart,
/// worker_suspension_redirect_test.dart) don't exercise on their own.
GoRouter _testRouter(ProviderContainer container, {String initialLocation = '/splash'}) {
  final refreshNotifier = ValueNotifier<bool>(false);
  container.listen(authStateProvider, (_, _) {
    refreshNotifier.value = !refreshNotifier.value;
  });

  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshNotifier,
    errorBuilder: (context, state) => const PageNotAvailablePage(),
    redirect: (context, state) {
      final authState = container.read(authStateProvider);
      final authRedirect = resolveAuthRedirect(
        authState: authState,
        matchedLocation: state.matchedLocation,
      );
      if (authRedirect != null) return authRedirect;

      final user = authState.valueOrNull;
      final suspensionRedirect = resolveWorkerSuspendedRedirect(
        user: user,
        matchedLocation: state.matchedLocation,
      );
      if (suspensionRedirect != null) return suspensionRedirect;

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => _stub('SPLASH')),
      GoRoute(path: '/welcome', builder: (_, _) => _stub('WELCOME')),
      GoRoute(path: '/auth/role-select', builder: (_, _) => _stub('ROLE_SELECT')),
      GoRoute(path: '/client/home', builder: (_, _) => _stub('CLIENT_HOME')),
      GoRoute(path: '/worker/home', builder: (_, _) => _stub('WORKER_HOME')),
      GoRoute(path: '/worker/suspended', builder: (_, _) => _stub('SUSPENDED')),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  UserEntity? user, {
  String initialLocation = '/splash',
}) async {
  final container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith(() => _FakeAuthStateNotifier(user)),
    ],
  );
  addTearDown(container.dispose);

  final router = _testRouter(container, initialLocation: initialLocation);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeAuthStateNotifier extends AuthStateNotifier {
  _FakeAuthStateNotifier(this._user);
  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

void main() {
  group('unknown route', () {
    testWidgets('a logged-in Client sees Page Not Available', (tester) async {
      await _pump(tester, _client, initialLocation: '/some/garbage/path');

      expect(find.byType(PageNotAvailablePage), findsOneWidget);
      expect(find.text('CLIENT_HOME'), findsNothing);
    });

    testWidgets(
      'a SUSPENDED Worker never sees Page Not Available — the suspension '
      'redirect wins first, exactly as it does for every other route',
      (tester) async {
        await _pump(tester, _suspendedWorker, initialLocation: '/some/garbage/path');

        expect(find.byType(PageNotAvailablePage), findsNothing);
        expect(find.text('SUSPENDED'), findsOneWidget);
      },
    );

    testWidgets('a logged-out visitor is sent to the branded welcome screen, '
        'never to the 404 page', (tester) async {
      await _pump(tester, null, initialLocation: '/some/garbage/path');

      expect(find.byType(PageNotAvailablePage), findsNothing);
      expect(find.text('WELCOME'), findsOneWidget);
    });
  });

  group('"Go to Home" button', () {
    testWidgets('routes a Client to Client Home', (tester) async {
      await _pump(tester, _client, initialLocation: '/some/garbage/path');
      expect(find.byType(PageNotAvailablePage), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('CLIENT_HOME'), findsOneWidget);
    });

    testWidgets('routes a Worker to Worker Home', (tester) async {
      await _pump(tester, _worker, initialLocation: '/some/garbage/path');
      expect(find.byType(PageNotAvailablePage), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('WORKER_HOME'), findsOneWidget);
    });
  });

  group('content', () {
    testWidgets('never exposes the attempted path or any exception text',
        (tester) async {
      await _pump(tester, _client, initialLocation: '/some/garbage/path');

      expect(find.textContaining('/some/garbage/path'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('Error:'), findsNothing);
    });
  });
}
