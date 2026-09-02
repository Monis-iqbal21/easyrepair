import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/data/cached_result.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/cash_payment_confirmation_entity.dart';
import 'package:handygo_app/features/bookings/domain/repositories/booking_repository.dart';
import 'package:handygo_app/features/bookings/domain/entities/update_booking_request.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:handygo_app/features/bookings/presentation/widgets/cash_payment_confirmation_card.dart';
import 'package:handygo_app/features/bookings/presentation/widgets/review_modal.dart';

import '../../support/l10n_test_app.dart';

const _bookingId = 'booking-1';

BookingEntity _booking({double? receivedAmount, String id = _bookingId}) =>
    BookingEntity(
      id: id,
      referenceId: '#ER-123456',
      serviceCategory: 'AC Technician',
      serviceEmoji: 'AC',
      status: BookingStatus.completed,
      urgency: BookingUrgency.normal,
      createdAt: DateTime(2026, 8, 20),
      lane: BookingLane.standard,
      finalPrice: 2500,
      receivedAmount: receivedAmount,
      expectedAmount: receivedAmount == null ? null : 2500,
      remainingAmount: receivedAmount == null ? null : 0,
      assignedWorker: const AssignedWorkerEntity(
        id: 'worker-1',
        firstName: 'Ali',
        lastName: 'Khan',
      ),
    );

class _CashRepository implements BookingRepository {
  final List<int> submittedAmounts = <int>[];
  final List<ReviewRequest> submittedReviews = <ReviewRequest>[];
  bool paymentConfirmed = false;
  int detailFetches = 0;

  /// The server already holds a current settlement (the Ustaad reported the
  /// cash first, say), so it refuses to write a second one.
  bool alreadySettledOnServer = false;

  /// Backend truth: once the settlement is recorded the booking comes back
  /// carrying `receivedAmount`, which is what `canClientConfirmCash` reads.
  @override
  Future<Either<Failure, CachedResult<BookingEntity>>> getBookingById(
    String bookingId,
  ) async {
    detailFetches++;
    return Right(
      CachedResult(_booking(receivedAmount: paymentConfirmed ? 2500 : null)),
    );
  }

  @override
  Future<Either<Failure, CashPaymentConfirmationEntity>> confirmCashPayment(
    String bookingId,
    int receivedCashTotal,
  ) async {
    submittedAmounts.add(receivedCashTotal);
    paymentConfirmed = true;
    if (alreadySettledOnServer) {
      return const Left(
        ConflictFailure('Booking already has a current settlement'),
      );
    }
    return Right(
      CashPaymentConfirmationEntity(
        settlementId: 'settlement-1',
        bookingId: bookingId,
        receivedCashTotal: receivedCashTotal,
        expectedTotal: 2500,
        shortfall: 0,
        recordedAt: DateTime.utc(2026, 8, 29),
        confirmationStatus: 'CONFIRMED',
        isCurrent: true,
      ),
    );
  }

  @override
  Future<Either<Failure, List<BookingEntity>>> getPendingReviews() async =>
      Right(paymentConfirmed && submittedReviews.isEmpty ? [_booking()] : []);

  @override
  Future<Either<Failure, BookingEntity>> submitReview(
    ReviewRequest request,
  ) async {
    submittedReviews.add(request);
    return Right(_booking(receivedAmount: 2500));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PromptHarness extends ConsumerStatefulWidget {
  const _PromptHarness({super.key, required this.booking});

  final BookingEntity booking;

  @override
  ConsumerState<_PromptHarness> createState() => _PromptHarnessState();
}

class _PromptHarnessState extends ConsumerState<_PromptHarness> {
  void rebuildFromProviderEvent() => setState(() {});

  Future<CashPaymentConfirmationEntity?> openManually() => ref
      .read(cashPaymentPromptControllerProvider)
      .showForBooking(context, widget.booking);

  @override
  Widget build(BuildContext context) {
    scheduleAutomaticCashPaymentPrompt(context, ref, widget.booking);
    return const Scaffold(body: Center(child: Text('BOOKING SURFACE')));
  }
}

Future<_CashRepository> _pumpHarness(
  WidgetTester tester,
  BookingEntity booking, {
  GlobalKey<_PromptHarnessState>? key,
}) async {
  final repository = _CashRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [bookingRepositoryProvider.overrideWithValue(repository)],
      child: localizedApp(_PromptHarness(key: key, booking: booking)),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

/// Renders whatever the backend currently says about the booking — the shape
/// every real surface has (My Bookings, Booking Detail, Track Worker all feed
/// the prompt from a provider, never from a captured entity).
class _BackendDrivenHarness extends ConsumerWidget {
  const _BackendDrivenHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingDetailProvider(_bookingId));
    return Scaffold(
      body: booking.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
        data: (value) {
          scheduleAutomaticCashPaymentPrompt(context, ref, value);
          return const Center(child: Text('BOOKING SURFACE'));
        },
      ),
    );
  }
}

void main() {
  testWidgets(
    'COMPLETED outstanding auto-opens once across repeated rebuilds',
    (tester) async {
      final key = GlobalKey<_PromptHarnessState>();
      await _pumpHarness(tester, _booking(), key: key);

      expect(find.byType(CashPaymentConfirmationCard), findsOneWidget);
      key.currentState!.rebuildFromProviderEvent();
      key.currentState!.rebuildFromProviderEvent();
      await tester.pumpAndSettle();

      expect(find.byType(CashPaymentConfirmationCard), findsOneWidget);
    },
  );

  testWidgets('authoritatively settled booking never auto-opens', (
    tester,
  ) async {
    await _pumpHarness(tester, _booking(receivedAmount: 2500));

    expect(find.byType(CashPaymentConfirmationCard), findsNothing);
  });

  testWidgets(
    'post-cash CTA opens the canonical review flow and persists the review',
    (tester) async {
      final repository = await _pumpHarness(tester, _booking());

      expect(find.byType(ReviewModal), findsNothing);
      await tester.enterText(find.byType(TextFormField), '2500');
      await tester.tap(find.byKey(const Key('cash-payment-submit-button')));
      await tester.pumpAndSettle();

      expect(repository.submittedAmounts, [2500]);
      expect(find.text('Cash payment confirmed'), findsOneWidget);
      expect(find.byType(ReviewModal), findsNothing);

      await tester.tap(find.text('Continue to review'));
      await tester.pumpAndSettle();
      expect(find.byType(CashPaymentConfirmationCard), findsNothing);
      expect(find.byType(ReviewModal), findsOneWidget);

      await tester.tap(find.byIcon(Icons.star_rounded).at(4));
      await tester.tap(find.byKey(const Key('review-submit-button')));
      await tester.pumpAndSettle();

      expect(repository.submittedReviews, hasLength(1));
      expect(repository.submittedReviews.single.bookingId, _bookingId);
      expect(repository.submittedReviews.single.rating, 5);
      expect(find.byType(ReviewModal), findsNothing);
    },
  );

  testWidgets('"Later" closes the prompt and it stays closed', (tester) async {
    // A customer with several unsettled bookings used to be locked out of the
    // app: the prompt refused the back button and the barrier, so the only way
    // forward was to pay every one of them. Closing it must be allowed, and
    // must not immediately reopen on the next provider rebuild.
    final key = GlobalKey<_PromptHarnessState>();
    await _pumpHarness(tester, _booking(), key: key);
    expect(find.byType(CashPaymentConfirmationCard), findsOneWidget);

    await tester.tap(find.byKey(const Key('cash-payment-later-button')));
    await tester.pumpAndSettle();
    expect(find.byType(CashPaymentConfirmationCard), findsNothing);

    key.currentState!.rebuildFromProviderEvent();
    key.currentState!.rebuildFromProviderEvent();
    await tester.pumpAndSettle();
    expect(find.byType(CashPaymentConfirmationCard), findsNothing);

    final manualPrompt = key.currentState!.openManually();
    await tester.pumpAndSettle();
    expect(find.byType(CashPaymentConfirmationCard), findsOneWidget);
    await tester.tap(find.byKey(const Key('cash-payment-later-button')));
    await tester.pumpAndSettle();
    await manualPrompt;
  });

  testWidgets('outside tap dismisses once and does not reopen on rebuild', (
    tester,
  ) async {
    final key = GlobalKey<_PromptHarnessState>();
    await _pumpHarness(tester, _booking(), key: key);
    expect(find.byType(CashPaymentConfirmationCard), findsOneWidget);

    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.byType(CashPaymentConfirmationCard), findsNothing);

    key.currentState!.rebuildFromProviderEvent();
    await tester.pumpAndSettle();
    expect(find.byType(CashPaymentConfirmationCard), findsNothing);
  });

  testWidgets('Android back dismisses once and does not reopen on rebuild', (
    tester,
  ) async {
    final key = GlobalKey<_PromptHarnessState>();
    await _pumpHarness(tester, _booking(), key: key);
    expect(find.byType(CashPaymentConfirmationCard), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CashPaymentConfirmationCard), findsNothing);

    key.currentState!.rebuildFromProviderEvent();
    await tester.pumpAndSettle();
    expect(find.byType(CashPaymentConfirmationCard), findsNothing);
  });

  testWidgets(
    'a receipt closed without the CTA still refreshes settlement truth, so the '
    'prompt cannot come back for that booking',
    (tester) async {
      // The recurrence: the payment IS persisted, but the dialog only reports
      // the "Continue to review" CTA. Closing the receipt with the barrier
      // therefore left every surface rendering a booking whose
      // `receivedAmount` was still null — i.e. still owing cash — so the modal
      // was free to open itself again the moment the session guard was gone
      // (app restart, relogin, a rebuilt provider container).
      final repository = _CashRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [bookingRepositoryProvider.overrideWithValue(repository)],
          child: localizedApp(const _BackendDrivenHarness()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CashPaymentConfirmationCard), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '2500');
      await tester.tap(find.byKey(const Key('cash-payment-submit-button')));
      await tester.pumpAndSettle();
      expect(repository.submittedAmounts, [2500]);
      expect(find.text('Cash payment confirmed'), findsOneWidget);

      // Dismiss the receipt instead of tapping "Continue to review".
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.byType(CashPaymentConfirmationCard), findsNothing);

      // The surface must now be rendering the settled booking, not the stale
      // one it was built from.
      final element = tester.element(find.text('BOOKING SURFACE'));
      final booking = ProviderScope.containerOf(
        element,
      ).read(bookingDetailProvider(_bookingId)).requireValue;
      expect(booking.receivedAmount, 2500);
      expect(booking.canClientConfirmCash, isFalse);
    },
  );

  testWidgets(
    'a fresh session over the same settled booking never auto-opens, and an '
    'unsettled sibling booking still does',
    (tester) async {
      // Restart / relogin: a brand new provider container, so nothing is left
      // of the session guard. Suppression has to come from the backend's
      // settlement record alone.
      final repository = _CashRepository()..paymentConfirmed = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [bookingRepositoryProvider.overrideWithValue(repository)],
          child: localizedApp(const _BackendDrivenHarness()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CashPaymentConfirmationCard), findsNothing);

      // Independence: another booking with no settlement of its own is
      // unaffected by this one's.
      await _pumpHarness(tester, _booking(id: 'booking-2'));
      await tester.pumpAndSettle();
      expect(find.byType(CashPaymentConfirmationCard), findsOneWidget);
    },
  );

  testWidgets(
    'a 409 already-settled refusal refreshes settlement truth without faking '
    'a success',
    (tester) async {
      // The server holds a settlement somebody else recorded, so it refuses to
      // write a second one. Nothing was created or overwritten — but the
      // booking IS settled, and the surface must stop asking for cash on it.
      final repository = _CashRepository()..alreadySettledOnServer = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [bookingRepositoryProvider.overrideWithValue(repository)],
          child: localizedApp(const _BackendDrivenHarness()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CashPaymentConfirmationCard), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '2500');
      await tester.tap(find.byKey(const Key('cash-payment-submit-button')));
      await tester.pumpAndSettle();

      // Exactly one attempt, refused — and the refusal is shown as such.
      expect(repository.submittedAmounts, [2500]);
      expect(find.text('Cash payment confirmed'), findsNothing);
      expect(
        find.textContaining('Payment was already confirmed'),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();

      final element = tester.element(find.text('BOOKING SURFACE'));
      final booking = ProviderScope.containerOf(
        element,
      ).read(bookingDetailProvider(_bookingId)).requireValue;
      expect(booking.receivedAmount, 2500);
      expect(booking.canClientConfirmCash, isFalse);
    },
  );
}
