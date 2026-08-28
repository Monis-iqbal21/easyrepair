import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';
import 'package:handygo_app/core/l10n/locale_provider.dart';
import 'package:handygo_app/core/router/app_router.dart';
import 'package:handygo_app/core/storage/secure_storage_service.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:handygo_app/features/auth/domain/entities/auth_tokens_entity.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:handygo_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:handygo_app/features/auth/presentation/pages/language_selection_page.dart';
import 'package:handygo_app/features/auth/presentation/pages/welcome_page.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fresh-install startup routing.
///
/// The bug this pins: a brand-new install with no session was landing on the
/// splash Retry ("Dobara koshish karein") instead of the welcome screen,
/// because [AuthStateNotifier] could not tell "there is nothing to restore"
/// apart from "the session check failed". Having no session is an ANSWER,
/// so startup must resolve it locally and never depend on the backend.
///
/// The distinctions that must survive the fix are pinned here too: a real
/// stored session whose check fails transiently still gets the Retry (and
/// keeps its tokens), a genuine 401 still logs out, and errors raised by an
/// action the user actually performed still surface on that action's screen.

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

/// A fresh install: nothing has ever been written to the secure store.
class _EmptySecureStorage extends SecureStorageService {
  _EmptySecureStorage() : super(const FlutterSecureStorage());

  @override
  Future<String?> getAccessToken() async => null;
}

class _StoredSessionSecureStorage extends SecureStorageService {
  _StoredSessionSecureStorage() : super(const FlutterSecureStorage());

  @override
  Future<String?> getAccessToken() async => 'a-token';
}

/// The Android reality behind "sometimes": Auto Backup restores this app's
/// ciphertext onto a new device without the Keystore key that decrypts it,
/// or the read lands before the device has been unlocked. The plugin throws
/// a PlatformException — which says nothing about whether a session exists.
class _UnreadableSecureStorage extends SecureStorageService {
  _UnreadableSecureStorage() : super(const FlutterSecureStorage());

  bool cleared = false;

  @override
  Future<String?> getAccessToken() async =>
      throw PlatformException(code: 'Exception encountered', message: 'decrypt');

  @override
  Future<void> clearTokens() async => cleared = true;
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.getCurrentUserResult, this.loginResult});

  final Future<Either<Failure, UserEntity>> Function()? getCurrentUserResult;
  final Future<Either<Failure, AuthTokensEntity>> Function()? loginResult;

  int getCurrentUserCalls = 0;

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() {
    getCurrentUserCalls++;
    return getCurrentUserResult!();
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> login({
    required String phone,
    required String password,
  }) => loginResult!();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

ProviderContainer _container({
  required SecureStorageService storage,
  _FakeAuthRepository? repository,
  SharedPreferences? prefs,
}) {
  final repo = repository ?? _FakeAuthRepository();
  final container = ProviderContainer(
    overrides: [
      secureStorageServiceProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repo),
      loginUseCaseProvider.overrideWithValue(LoginUseCase(repo)),
      if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _stub(String label) => Scaffold(body: Center(child: Text(label)));

/// Drives the REAL [resolveAuthRedirect] over the REAL [WelcomePage] and
/// [LanguageSelectionPage], so what is asserted is production routing, not a
/// restatement of it.
GoRouter _router(ProviderContainer container) {
  final refresh = ValueNotifier<bool>(false);
  container.listen(authStateProvider, (_, _) => refresh.value = !refresh.value);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => resolveAuthRedirect(
      authState: container.read(authStateProvider),
      matchedLocation: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => _stub('SPLASH')),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
      GoRoute(
        path: '/auth/language',
        builder: (_, _) => const LanguageSelectionPage(),
      ),
      GoRoute(
        path: '/auth/role-select',
        builder: (_, _) => _stub('ROLE_SELECT'),
      ),
      GoRoute(path: '/auth/client', builder: (_, _) => _stub('CLIENT_LOGIN')),
      GoRoute(path: '/client/home', builder: (_, _) => _stub('CLIENT_HOME')),
      GoRoute(path: '/worker/home', builder: (_, _) => _stub('WORKER_HOME')),
    ],
  );
}

Future<GoRouter> _pumpStartup(
  WidgetTester tester,
  ProviderContainer container,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = _router(container);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('fresh install with no stored session', () {
    testWidgets('lands on Shuru karein, never the Retry splash', (tester) async {
      final container = _container(storage: _EmptySecureStorage());

      final router = await _pumpStartup(tester, container);

      expect(find.text('Shuru karein'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/welcome',
      );
    });

    testWidgets('still lands on Shuru karein when the backend is unavailable',
        (tester) async {
      final repository = _FakeAuthRepository(
        getCurrentUserResult: () async => const Left(ServerFailure('502')),
      );
      final container = _container(
        storage: _EmptySecureStorage(),
        repository: repository,
      );

      await _pumpStartup(tester, container);

      expect(find.text('Shuru karein'), findsOneWidget);
      // The point of the fix: with nothing to restore, startup never asks
      // the server anything, so the server cannot hold the user back.
      expect(repository.getCurrentUserCalls, 0);
    });

    testWidgets('still lands on Shuru karein with no connectivity',
        (tester) async {
      final repository = _FakeAuthRepository(
        getCurrentUserResult: () async =>
            const Left(NetworkFailure('', code: FailureCode.noInternet)),
      );
      final container = _container(
        storage: _EmptySecureStorage(),
        repository: repository,
      );

      await _pumpStartup(tester, container);

      expect(find.text('Shuru karein'), findsOneWidget);
      expect(repository.getCurrentUserCalls, 0);
    });

    testWidgets(
      'an unreadable secure store is treated as no session, not as an error, '
      'and the stored bytes are left alone',
      (tester) async {
        final storage = _UnreadableSecureStorage();
        final repository = _FakeAuthRepository(
          getCurrentUserResult: () async => const Left(ServerFailure('')),
        );
        final container = _container(
          storage: storage,
          repository: repository,
        );

        await _pumpStartup(tester, container);

        expect(find.text('Shuru karein'), findsOneWidget);
        expect(repository.getCurrentUserCalls, 0);
        // Never destroy credentials we merely failed to read — a later
        // launch that CAN read them must restore the session.
        expect(storage.cleared, isFalse);
      },
    );

    testWidgets('Shuru karein reaches the existing role selection screen',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = _container(
        storage: _EmptySecureStorage(),
        prefs: await SharedPreferences.getInstance(),
      );

      await _pumpStartup(tester, container);

      await tester.tap(find.text('Shuru karein'));
      await tester.pumpAndSettle();

      // The existing onboarding language step, unchanged...
      expect(find.byType(LanguageSelectionPage), findsOneWidget);

      await tester.tap(
        find.byType(ElevatedButton).hitTestable().last,
      );
      await tester.pumpAndSettle();

      // ...then the EXISTING role picker. No new screen was introduced.
      expect(find.text('ROLE_SELECT'), findsOneWidget);
    });

    testWidgets('settles without a loading/retry/redirect loop', (tester) async {
      final container = _container(storage: _EmptySecureStorage());
      final router = await _pumpStartup(tester, container);

      final settled = router.routerDelegate.currentConfiguration.uri.path;
      expect(settled, '/welcome');

      // Re-running the production redirect from where it landed must be a
      // fixed point: anything else is the loop.
      expect(
        resolveAuthRedirect(
          authState: container.read(authStateProvider),
          matchedLocation: settled,
        ),
        isNull,
      );
    });

    test('cold start and app resume agree that there is no session', () async {
      final container = _container(storage: _EmptySecureStorage());

      expect(await container.read(authStateProvider.future), isNull);
      expect(
        resolveAuthRedirect(
          authState: container.read(authStateProvider),
          matchedLocation: '/splash',
        ),
        '/welcome',
      );

      // A resume re-runs the same check; an unauthenticated app must not
      // change its mind about where it belongs.
      container.invalidate(authStateProvider);
      expect(await container.read(authStateProvider.future), isNull);
      expect(
        resolveAuthRedirect(
          authState: container.read(authStateProvider),
          matchedLocation: '/welcome',
        ),
        isNull,
      );
    });
  });

  group('a stored session still restores', () {
    testWidgets('a valid CLIENT session goes to the client app', (tester) async {
      final container = _container(
        storage: _StoredSessionSecureStorage(),
        repository: _FakeAuthRepository(
          getCurrentUserResult: () async => const Right(_client),
        ),
      );

      final router = await _pumpStartup(tester, container);

      expect(router.routerDelegate.currentConfiguration.uri.path, '/client/home');
      expect(find.text('CLIENT_HOME'), findsOneWidget);
    });

    testWidgets('a valid WORKER session goes to the worker app', (tester) async {
      final container = _container(
        storage: _StoredSessionSecureStorage(),
        repository: _FakeAuthRepository(
          getCurrentUserResult: () async => const Right(_worker),
        ),
      );

      final router = await _pumpStartup(tester, container);

      expect(router.routerDelegate.currentConfiguration.uri.path, '/worker/home');
      expect(find.text('WORKER_HOME'), findsOneWidget);
    });

    test(
      'a transient failure while restoring a REAL session is not read as '
      'logged out — it holds on splash for a retry',
      () async {
        final container = _container(
          storage: _StoredSessionSecureStorage(),
          repository: _FakeAuthRepository(
            getCurrentUserResult: () async =>
                const Left(NetworkFailure('', code: FailureCode.noInternet)),
          ),
        );

        await expectLater(
          container.read(authStateProvider.future),
          throwsA(isA<NetworkFailure>()),
        );

        final state = container.read(authStateProvider);
        expect(state.hasError, isTrue);
        expect(state.hasValue, isFalse);
        // Crucially NOT '/welcome': the session was never disproved.
        expect(
          resolveAuthRedirect(authState: state, matchedLocation: '/splash'),
          isNull,
        );
      },
    );

    testWidgets(
      'a definitively invalid/expired session follows the existing logout '
      'path back to the unauthenticated entry flow',
      (tester) async {
        final container = _container(
          storage: _StoredSessionSecureStorage(),
          repository: _FakeAuthRepository(
            getCurrentUserResult: () async =>
                const Left(UnauthorizedFailure('')),
          ),
        );

        final router = await _pumpStartup(tester, container);

        expect(router.routerDelegate.currentConfiguration.uri.path, '/welcome');
        expect(find.text('Shuru karein'), findsOneWidget);
      },
    );
  });

  group('network errors the user actually asked for', () {
    test(
      'a failed login surfaces on the auth flow and leaves routing there',
      () async {
        final container = _container(
          storage: _EmptySecureStorage(),
          repository: _FakeAuthRepository(
            loginResult: () async =>
                const Left(NetworkFailure('', code: FailureCode.noInternet)),
          ),
        );

        expect(await container.read(authStateProvider.future), isNull);

        await container
            .read(loginNotifierProvider.notifier)
            .login('+923001234567', 'secret');

        // The error belongs to the action, on the action's screen.
        final loginState = container.read(loginNotifierProvider);
        expect(loginState.hasError, isTrue);
        expect(loginState.error, isA<NetworkFailure>());

        // And it never becomes a startup problem: the user stays exactly
        // where they were in the auth flow.
        expect(
          resolveAuthRedirect(
            authState: container.read(authStateProvider),
            matchedLocation: '/auth/client',
          ),
          isNull,
        );
      },
    );
  });
}
