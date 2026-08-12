import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/router/app_router.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';

/// Pins the central Worker-suspension lock — the ONLY place suspension is
/// enforced (see app_router.dart's redirect callback). A suspended Worker
/// must be redirected away from every route (deep link, notification tap,
/// bottom-nav destination — they all resolve to a `matchedLocation` here)
/// straight to /worker/suspended, and only ever back out once the account is
/// no longer SUSPENDED.
const _suspendedWorker = UserEntity(
  id: 'w1',
  phone: '+923001234567',
  role: 'WORKER',
  firstName: 'Bilal',
  lastName: 'Ahmed',
  workerStatus: 'SUSPENDED',
);

const _activeWorker = UserEntity(
  id: 'w2',
  phone: '+923001234568',
  role: 'WORKER',
  firstName: 'Ahmed',
  lastName: 'Raza',
  workerStatus: 'ACTIVE',
);

const _inactiveWorker = UserEntity(
  id: 'w3',
  phone: '+923001234569',
  role: 'WORKER',
  firstName: 'Usman',
  lastName: 'Tariq',
  workerStatus: 'INACTIVE',
);

const _client = UserEntity(
  id: 'c1',
  phone: '+923001234570',
  role: 'CLIENT',
  firstName: 'Ali',
  lastName: 'Khan',
);

void main() {
  group('logged out / no user', () {
    test('never applies when logged out', () {
      expect(
        resolveWorkerSuspendedRedirect(user: null, matchedLocation: '/worker/home'),
        isNull,
      );
    });
  });

  group('never applies to a CLIENT', () {
    test('a Client on any route is left alone', () {
      expect(
        resolveWorkerSuspendedRedirect(
          user: _client,
          matchedLocation: '/client/home',
        ),
        isNull,
      );
    });
  });

  group('SUSPENDED Worker — locked to /worker/suspended', () {
    for (final route in [
      '/worker/home',
      '/worker/jobs',
      '/worker/new-jobs',
      '/worker/chat',
      '/worker/chat/conv-1',
      '/worker/profile',
      '/worker/reviews',
      '/worker/job/booking-1',
      '/worker/job/booking-1/bid',
      '/worker/job/booking-1/inspection-report',
      '/notifications',
      '/splash',
      '/some/unknown/deep-link',
    ]) {
      test('redirects from $route to /worker/suspended', () {
        expect(
          resolveWorkerSuspendedRedirect(
            user: _suspendedWorker,
            matchedLocation: route,
          ),
          '/worker/suspended',
        );
      });
    }

    test('already on /worker/suspended is left alone (no redirect loop)', () {
      expect(
        resolveWorkerSuspendedRedirect(
          user: _suspendedWorker,
          matchedLocation: '/worker/suspended',
        ),
        isNull,
      );
    });
  });

  group('ACTIVE/INACTIVE Worker — normal access restored', () {
    test('an ACTIVE worker on a normal route is left alone', () {
      expect(
        resolveWorkerSuspendedRedirect(
          user: _activeWorker,
          matchedLocation: '/worker/home',
        ),
        isNull,
      );
    });

    test('an INACTIVE worker on a normal route is also left alone', () {
      expect(
        resolveWorkerSuspendedRedirect(
          user: _inactiveWorker,
          matchedLocation: '/worker/jobs',
        ),
        isNull,
      );
    });

    test(
      'an ACTIVE worker who lands on /worker/suspended (e.g. admin just '
      'restored them) is redirected to /worker/home on the next refresh',
      () {
        expect(
          resolveWorkerSuspendedRedirect(
            user: _activeWorker,
            matchedLocation: '/worker/suspended',
          ),
          '/worker/home',
        );
      },
    );

    test('the same restoration applies for INACTIVE', () {
      expect(
        resolveWorkerSuspendedRedirect(
          user: _inactiveWorker,
          matchedLocation: '/worker/suspended',
        ),
        '/worker/home',
      );
    });
  });
}
