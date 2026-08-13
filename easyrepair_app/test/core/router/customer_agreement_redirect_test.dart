import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/router/app_router.dart';
import 'package:handygo_app/features/client/domain/entities/customer_agreement_entity.dart';

/// Pins the mandatory Customer Terms gate's redirect decision — the router
/// logic that must fire on cold start, right after any CLIENT login/register
/// flow (OTP or password — both invalidate the same authStateProvider this
/// redirect reacts to), and on session restore, while never applying to a
/// WORKER and never letting a network/server error read as "accepted".
CustomerAgreementStatusEntity _status({required bool acceptanceRequired}) {
  return CustomerAgreementStatusEntity(
    acceptanceRequired: acceptanceRequired,
    agreement: const CustomerAgreementEntity(
      documentType: kCustomerTermsDocumentType,
      title: 'HandyGo Customer Terms, Booking Rules aur Privacy Notice',
      version: '1.0',
      agreementLocale: 'ur_Latn',
      sourceHash:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      contentText: 'Full legal text…',
      legalLanguageNoticeRequired: false,
      requestedAppLocale: 'ur_Latn',
    ),
    existingAcceptance: acceptanceRequired
        ? null
        : CustomerAgreementAcceptanceSummaryEntity(
            id: 'row-1',
            acceptanceId: 'HG-ACC-2026-ABCDEF123456',
            version: '1.0',
            acceptedAt: DateTime(2026, 8, 7),
          ),
  );
}

void main() {
  group('a logged-out visitor or a WORKER', () {
    test('is never redirected to the gate — logged out', () {
      final redirect = resolveClientAgreementRedirect(
        isLoggedIn: false,
        isWorker: false,
        matchedLocation: '/client/home',
        agreementAsync: AsyncData(_status(acceptanceRequired: true)),
      );
      expect(redirect, isNull);
    });

    test('is never redirected to the gate — a WORKER, even mid-fetch', () {
      final redirect = resolveClientAgreementRedirect(
        isLoggedIn: true,
        isWorker: true,
        matchedLocation: '/worker/home',
        agreementAsync: const AsyncLoading(),
      );
      expect(redirect, isNull);
    });

    test('a WORKER is never redirected even if the status carries an error', () {
      final redirect = resolveClientAgreementRedirect(
        isLoggedIn: true,
        isWorker: true,
        matchedLocation: '/worker/jobs',
        agreementAsync: AsyncError('network down', StackTrace.empty),
      );
      expect(redirect, isNull);
    });
  });

  group('cold start / any CLIENT login flow (OTP or password) — pending agreement', () {
    test('a CLIENT with acceptanceRequired: true is sent to the gate', () {
      final redirect = resolveClientAgreementRedirect(
        isLoggedIn: true,
        isWorker: false,
        matchedLocation: '/client/home',
        agreementAsync: AsyncData(_status(acceptanceRequired: true)),
      );
      expect(redirect, '/client/agreement-gate');
    });

    test('a deep link into a booking is redirected to the gate too', () {
      // Deep links/notifications must never bypass the gate.
      final redirect = resolveClientAgreementRedirect(
        isLoggedIn: true,
        isWorker: false,
        matchedLocation: '/client/booking/xyz',
        agreementAsync: AsyncData(_status(acceptanceRequired: true)),
      );
      expect(redirect, '/client/agreement-gate');
    });

    test('bottom-nav tap to chat is redirected to the gate too', () {
      final redirect = resolveClientAgreementRedirect(
        isLoggedIn: true,
        isWorker: false,
        matchedLocation: '/client/chat',
        agreementAsync: AsyncData(_status(acceptanceRequired: true)),
      );
      expect(redirect, '/client/agreement-gate');
    });

    test('already sitting on the gate is not redirected again (null)', () {
      final redirect = resolveClientAgreementRedirect(
        isLoggedIn: true,
        isWorker: false,
        matchedLocation: '/client/agreement-gate',
        agreementAsync: AsyncData(_status(acceptanceRequired: true)),
      );
      expect(redirect, isNull);
    });
  });

  group('accepted CLIENT — no gate, on this device or another', () {
    test('acceptanceRequired: false lets navigation proceed untouched', () {
      final redirect = resolveClientAgreementRedirect(
        isLoggedIn: true,
        isWorker: false,
        matchedLocation: '/client/home',
        agreementAsync: AsyncData(_status(acceptanceRequired: false)),
      );
      expect(redirect, isNull);
    });

    test(
      'server confirms already accepted (e.g. from another device) — '
      'sitting on the gate route bounces to home instead of re-asking',
      () {
        final redirect = resolveClientAgreementRedirect(
          isLoggedIn: true,
          isWorker: false,
          matchedLocation: '/client/agreement-gate',
          agreementAsync: AsyncData(_status(acceptanceRequired: false)),
        );
        expect(redirect, '/client/home');
      },
    );

    test('logout then login again as the same accepted client asks nothing new', () {
      // Modeled as: after re-authentication, requiredCustomerAgreementProvider
      // resolves fresh from the backend to acceptanceRequired: false — the
      // exact same "accepted" branch as any other resolution. There is no
      // separate "remembered on this device" path to diverge from it.
      final redirect = resolveClientAgreementRedirect(
        isLoggedIn: true,
        isWorker: false,
        matchedLocation: '/client/home',
        agreementAsync: AsyncData(_status(acceptanceRequired: false)),
      );
      expect(redirect, isNull);
    });
  });

  group('still loading', () {
    test('stays on splash while the status is resolving', () {
      final redirect = resolveClientAgreementRedirect(
        isLoggedIn: true,
        isWorker: false,
        matchedLocation: '/splash',
        agreementAsync: const AsyncLoading(),
      );
      expect(redirect, isNull);
    });

    test('sends any other route to splash while resolving, never flashing content', () {
      final redirect = resolveClientAgreementRedirect(
        isLoggedIn: true,
        isWorker: false,
        matchedLocation: '/client/home',
        agreementAsync: const AsyncLoading(),
      );
      expect(redirect, '/splash');
    });
  });

  group('background refresh of an already-resolved status', () {
    // Regression coverage: requiredCustomerAgreementProvider is listened to
    // by routerProvider's refreshListenable, so an invalidation while the
    // client is deep in navigation (post-accept, or a locale change) puts it
    // into AsyncLoading with the previous status retained via
    // copyWithPrevious. That must never bounce the client to /splash.
    test(
      'a CLIENT on a nested route survives a refresh of an already-accepted '
      'status — route is preserved, not bounced to splash',
      () {
        final refreshing =
            AsyncLoading<CustomerAgreementStatusEntity?>().copyWithPrevious(
          AsyncData(_status(acceptanceRequired: false)),
        );

        final redirect = resolveClientAgreementRedirect(
          isLoggedIn: true,
          isWorker: false,
          matchedLocation: '/client/bookings/42',
          agreementAsync: refreshing,
        );

        expect(redirect, isNull);
      },
    );

    test(
      'a refresh of a still-required status keeps routing to the gate, not '
      'to splash',
      () {
        final refreshing =
            AsyncLoading<CustomerAgreementStatusEntity?>().copyWithPrevious(
          AsyncData(_status(acceptanceRequired: true)),
        );

        final redirect = resolveClientAgreementRedirect(
          isLoggedIn: true,
          isWorker: false,
          matchedLocation: '/client/home',
          agreementAsync: refreshing,
        );

        expect(redirect, '/client/agreement-gate');
      },
    );
  });

  group('a network/server error must never be read as accepted', () {
    test('an error resolving the required-status blocks access like required: true', () {
      final redirect = resolveClientAgreementRedirect(
        isLoggedIn: true,
        isWorker: false,
        matchedLocation: '/client/home',
        agreementAsync: AsyncError<CustomerAgreementStatusEntity?>(
          'network down',
          StackTrace.empty,
        ),
      );
      expect(redirect, '/client/agreement-gate');
    });

    test('an error does not bounce away from the gate route either', () {
      final redirect = resolveClientAgreementRedirect(
        isLoggedIn: true,
        isWorker: false,
        matchedLocation: '/client/agreement-gate',
        agreementAsync: AsyncError<CustomerAgreementStatusEntity?>(
          'network down',
          StackTrace.empty,
        ),
      );
      expect(redirect, isNull);
    });
  });
}
