import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/router/app_router.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';

/// Pins the central Client account-restriction lock — the Client-side
/// analogue of worker_suspension_redirect_test.dart. A restricted Client
/// must be redirected away from every route (deep link, notification tap,
/// bottom-nav destination — they all resolve to a `matchedLocation` here)
/// straight to /client/restricted, and only ever back out once the account
/// is no longer SUSPENDED.
const _restrictedClient = UserEntity(
  id: 'c1',
  phone: '+923001234567',
  role: 'CLIENT',
  firstName: 'Sara',
  lastName: 'Ahmed',
  accountStatus: 'SUSPENDED',
);

const _activeClient = UserEntity(
  id: 'c2',
  phone: '+923001234568',
  role: 'CLIENT',
  firstName: 'Ali',
  lastName: 'Khan',
  accountStatus: 'ACTIVE',
);

const _defaultClient = UserEntity(
  id: 'c3',
  phone: '+923001234569',
  role: 'CLIENT',
  firstName: 'Bilal',
  lastName: 'Raza',
);

const _worker = UserEntity(
  id: 'w1',
  phone: '+923001234570',
  role: 'WORKER',
  firstName: 'Usman',
  lastName: 'Tariq',
  workerStatus: 'ACTIVE',
);

void main() {
  group('logged out / no user', () {
    test('never applies when logged out', () {
      expect(
        resolveClientRestrictedRedirect(
          user: null,
          matchedLocation: '/client/home',
        ),
        isNull,
      );
    });
  });

  group('never applies to a WORKER', () {
    test('a Worker on any route is left alone, even with accountStatus somehow set', () {
      expect(
        resolveClientRestrictedRedirect(
          user: _worker,
          matchedLocation: '/worker/home',
        ),
        isNull,
      );
    });
  });

  group('SUSPENDED Client — locked to /client/restricted', () {
    for (final route in [
      '/client/home',
      '/client/jobs',
      '/client/chat',
      '/client/chat/conv-1',
      '/client/profile',
      '/client/booking/booking-1',
      '/client/booking/booking-1/inspection-report',
      '/client/post-job',
      '/client/track/booking-1',
      '/client/agreement-gate',
      '/notifications',
      '/splash',
      '/some/unknown/deep-link',
    ]) {
      test('redirects from $route to /client/restricted', () {
        expect(
          resolveClientRestrictedRedirect(
            user: _restrictedClient,
            matchedLocation: route,
          ),
          '/client/restricted',
        );
      });
    }

    test('already on /client/restricted is left alone (no redirect loop)', () {
      expect(
        resolveClientRestrictedRedirect(
          user: _restrictedClient,
          matchedLocation: '/client/restricted',
        ),
        isNull,
      );
    });
  });

  group('ACTIVE Client — normal access', () {
    test('an ACTIVE client on a normal route is left alone', () {
      expect(
        resolveClientRestrictedRedirect(
          user: _activeClient,
          matchedLocation: '/client/home',
        ),
        isNull,
      );
    });

    test('a client with no accountStatus set (defaults to ACTIVE) is left alone', () {
      expect(
        resolveClientRestrictedRedirect(
          user: _defaultClient,
          matchedLocation: '/client/home',
        ),
        isNull,
      );
    });

    test(
      'an ACTIVE client who lands on /client/restricted (e.g. admin just '
      'reactivated them) is redirected to /client/home on the next refresh',
      () {
        expect(
          resolveClientRestrictedRedirect(
            user: _activeClient,
            matchedLocation: '/client/restricted',
          ),
          '/client/home',
        );
      },
    );
  });
}
