import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/router/app_router.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';

/// Pins the top-level login/logout redirect decision — the part of the
/// router that must never mistake a transient /auth/me failure (no
/// internet, a timeout, a 5xx) for a logout, while still sending a
/// genuinely logged-out user to role-select and dispatching a confirmed
/// user to the right home.
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

void main() {
  group('still resolving', () {
    test('stays on splash while loading', () {
      final redirect = resolveAuthRedirect(
        authState: const AsyncLoading(),
        matchedLocation: '/splash',
      );
      expect(redirect, isNull);
    });

    test('sends any other route to splash while loading', () {
      final redirect = resolveAuthRedirect(
        authState: const AsyncLoading(),
        matchedLocation: '/client/home',
      );
      expect(redirect, '/splash');
    });
  });

  group('transient failure with nothing previously confirmed', () {
    test(
      'a cold-start network failure on the very first check is treated '
      'like still-loading, never like a logout',
      () {
        final redirect = resolveAuthRedirect(
          authState: AsyncError<UserEntity?>(
            const NetworkFailure('', code: FailureCode.noInternet),
            StackTrace.empty,
          ),
          matchedLocation: '/client/home',
        );
        expect(redirect, '/splash');
      },
    );

    test('stays on splash rather than bouncing to role-select', () {
      final redirect = resolveAuthRedirect(
        authState: AsyncError<UserEntity?>(
          const ServerFailure(''),
          StackTrace.empty,
        ),
        matchedLocation: '/splash',
      );
      expect(redirect, isNull);
    });
  });

  group('transient failure with a previously-confirmed user', () {
    test(
      'a network blip after a confirmed CLIENT session leaves navigation '
      'alone — the session is not destroyed by a timeout',
      () {
        // Models AsyncError.hasValue == true, which is exactly what Riverpod
        // produces when a rebuild throws after a prior successful build
        // (see AuthStateNotifier) — copyWithPrevious carries `_client`
        // forward onto the error state, via the same public API Riverpod's
        // framework uses internally.
        final errored = AsyncError<UserEntity?>(
          const ServerFailure(''),
          StackTrace.empty,
        ).copyWithPrevious(const AsyncData<UserEntity?>(_client));

        final redirect = resolveAuthRedirect(
          authState: errored,
          matchedLocation: '/client/home',
        );

        expect(redirect, isNull);
      },
    );

    test('the same holds for a confirmed WORKER session', () {
      final errored = AsyncError<UserEntity?>(
        const NetworkFailure('', code: FailureCode.timeout),
        StackTrace.empty,
      ).copyWithPrevious(const AsyncData<UserEntity?>(_worker));

      final redirect = resolveAuthRedirect(
        authState: errored,
        matchedLocation: '/worker/jobs',
      );

      expect(redirect, isNull);
    });

    test(
      'still dispatches away from an /auth route to the right home, even '
      'while errored, as long as a user was already confirmed',
      () {
        final errored = AsyncError<UserEntity?>(
          const ServerFailure(''),
          StackTrace.empty,
        ).copyWithPrevious(const AsyncData<UserEntity?>(_client));

        final redirect = resolveAuthRedirect(
          authState: errored,
          matchedLocation: '/auth/role-select',
        );

        expect(redirect, '/client/home');
      },
    );
  });

  group('genuinely logged out', () {
    test('a null user (definite logout) sends any non-auth route to role-select', () {
      final redirect = resolveAuthRedirect(
        authState: const AsyncData<UserEntity?>(null),
        matchedLocation: '/client/home',
      );
      expect(redirect, '/auth/role-select');
    });

    test('an already-on-/auth route with no user is left alone', () {
      final redirect = resolveAuthRedirect(
        authState: const AsyncData<UserEntity?>(null),
        matchedLocation: '/auth/client',
      );
      expect(redirect, isNull);
    });

    test('splash with no user dispatches to role-select', () {
      final redirect = resolveAuthRedirect(
        authState: const AsyncData<UserEntity?>(null),
        matchedLocation: '/splash',
      );
      expect(redirect, '/auth/role-select');
    });
  });

  group('confirmed session dispatch', () {
    test('splash + CLIENT → /client/home', () {
      final redirect = resolveAuthRedirect(
        authState: const AsyncData<UserEntity?>(_client),
        matchedLocation: '/splash',
      );
      expect(redirect, '/client/home');
    });

    test('splash + WORKER → /worker/home', () {
      final redirect = resolveAuthRedirect(
        authState: const AsyncData<UserEntity?>(_worker),
        matchedLocation: '/splash',
      );
      expect(redirect, '/worker/home');
    });

    test('a confirmed user already on an app route is left alone', () {
      final redirect = resolveAuthRedirect(
        authState: const AsyncData<UserEntity?>(_client),
        matchedLocation: '/client/jobs',
      );
      expect(redirect, isNull);
    });

    test('a confirmed user stuck on an /auth route is dispatched home', () {
      final redirect = resolveAuthRedirect(
        authState: const AsyncData<UserEntity?>(_worker),
        matchedLocation: '/auth/worker/login',
      );
      expect(redirect, '/worker/home');
    });
  });
}
