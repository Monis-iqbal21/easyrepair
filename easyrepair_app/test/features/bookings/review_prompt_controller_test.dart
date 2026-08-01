import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import '../../support/l10n_test_app.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/update_booking_request.dart';
import 'package:handygo_app/features/bookings/domain/repositories/booking_repository.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:handygo_app/features/bookings/presentation/providers/review_prompt_controller.dart';

BookingEntity _completed(String id, {BookingReviewEntity? review}) {
  return BookingEntity(
    id: id,
    referenceId: '#ER-${id.toUpperCase()}',
    serviceCategory: 'AC Repair',
    serviceEmoji: '❄️',
    status: BookingStatus.completed,
    urgency: BookingUrgency.normal,
    createdAt: DateTime(2026, 7, 30, 9),
    completedAt: DateTime(2026, 7, 30, 11),
    lane: BookingLane.inspection,
    finalPrice: 500,
    review: review,
    assignedWorker: const AssignedWorkerEntity(
      id: 'worker-1',
      firstName: 'Ali',
      lastName: 'Khan',
      rating: 4.6,
    ),
  );
}

/// Minimal fake: only the two methods the controller and modal use.
class _FakeBookingRepository implements BookingRepository {
  _FakeBookingRepository(this.pending);

  List<BookingEntity> pending;
  int pendingCalls = 0;
  int submitCalls = 0;
  Failure? submitFailure;

  @override
  Future<Either<Failure, List<BookingEntity>>> getPendingReviews() async {
    pendingCalls++;
    return Right(List.of(pending));
  }

  @override
  Future<Either<Failure, BookingEntity>> submitReview(
    ReviewRequest request,
  ) async {
    submitCalls++;
    if (submitFailure != null) return Left(submitFailure!);
    // Mirror the backend: the booking leaves the pending list once reviewed.
    pending = pending.where((b) => b.id != request.bookingId).toList();
    return Right(
      _completed(
        request.bookingId,
        review: BookingReviewEntity(
          id: 'review-1',
          rating: request.rating,
          comment: request.comment,
          createdAt: DateTime(2026, 7, 30, 12),
        ),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

/// Harness that exposes a live BuildContext plus the container.
class _Harness {
  _Harness(this.container, this.context, this.repo);
  final ProviderContainer container;
  final BuildContext context;
  final _FakeBookingRepository repo;

  ReviewPromptController get controller =>
      container.read(reviewPromptControllerProvider);
}

Future<_Harness> _pump(
  WidgetTester tester, {
  required List<BookingEntity> pending,
}) async {
  final repo = _FakeBookingRepository(pending);
  late BuildContext ctx;
  late ProviderContainer container;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [bookingRepositoryProvider.overrideWithValue(repo)],
      child: localizedApp(
         Consumer(
          builder: (context, ref, _) {
            ctx = context;
            container = ProviderScope.containerOf(context);
            return const Scaffold(body: Text('HOME'));
          },
        ),
        locale: AppLocale.romanUrdu,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(container, ctx, repo);
}

Future<void> _submitReview(WidgetTester tester, {int stars = 5}) async {
  await tester.tap(find.byIcon(Icons.star_rounded).at(stars - 1));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Review Submit Karein'));
  await tester.pumpAndSettle();
}

void main() {
  // ── One modal at a time ───────────────────────────────────────────────────
  group('single active guard', () {
    testWidgets('a mandatory reservation blocks a foreground enqueue for the '
        'same booking (no stacking)', (tester) async {
      final h = await _pump(tester, pending: [_completed('booking-1')]);

      // Reserved BEFORE the network call, exactly as _findOtherUstaad does.
      expect(h.controller.reserveMandatory('booking-1'), isTrue);
      expect(h.controller.activeBookingId, 'booking-1');
      expect(h.controller.isMandatoryActive, isTrue);

      // The completion push lands mid-flight — it must open nothing.
      h.controller.enqueue(h.context, 'booking-1');
      await tester.pumpAndSettle();

      expect(h.controller.queuedBookingIds, isEmpty);
      expect(find.text('Review Submit Karein'), findsNothing);
    });

    testWidgets('a second reservation for a different booking is refused', (
      tester,
    ) async {
      final h = await _pump(tester, pending: [_completed('booking-1')]);

      expect(h.controller.reserveMandatory('booking-1'), isTrue);
      expect(h.controller.reserveMandatory('booking-2'), isFalse);
      expect(h.controller.activeBookingId, 'booking-1');
    });

    testWidgets('releaseReservation frees the guard after a failed request', (
      tester,
    ) async {
      final h = await _pump(tester, pending: [_completed('booking-1')]);

      h.controller.reserveMandatory('booking-1');
      h.controller.releaseReservation('booking-1');

      expect(h.controller.activeBookingId, isNull);
      expect(h.controller.isMandatoryActive, isFalse);
      // …and the guard is available again.
      expect(h.controller.reserveMandatory('booking-2'), isTrue);
    });
  });

  // ── Mandatory review semantics ────────────────────────────────────────────
  group('showMandatory', () {
    testWidgets('has no "Baad Mein" escape and cannot be dismissed', (
      tester,
    ) async {
      final booking = _completed('booking-1');
      final h = await _pump(tester, pending: [booking]);

      unawaited(h.controller.showMandatory(h.context, booking));
      await tester.pumpAndSettle();

      expect(find.text('Review Submit Karein'), findsOneWidget);
      expect(find.text('Baad Mein'), findsNothing);

      // System back must not close it.
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Review Submit Karein'), findsOneWidget);
    });

    testWidgets('resolves true only after a successful submission', (
      tester,
    ) async {
      final booking = _completed('booking-1');
      final h = await _pump(tester, pending: [booking]);

      bool? resolved;
      unawaited(
        h.controller
            .showMandatory(h.context, booking)
            .then((v) => resolved = v),
      );
      await tester.pumpAndSettle();
      expect(resolved, isNull, reason: 'must not resolve while showing');

      await _submitReview(tester);

      expect(resolved, isTrue);
      expect(h.repo.submitCalls, 1);
      expect(h.controller.activeBookingId, isNull);
    });

    testWidgets(
      'a FAILED submission keeps the modal open, keeps the guard held and '
      'leaves the Future pending',
      (tester) async {
        final booking = _completed('booking-1');
        final h = await _pump(tester, pending: [booking]);
        h.repo.submitFailure = const ServerFailure('network down');

        bool? resolved;
        unawaited(
          h.controller
              .showMandatory(h.context, booking)
              .then((v) => resolved = v),
        );
        await tester.pumpAndSettle();

        await _submitReview(tester);

        // Still on screen…
        expect(find.text('Review Submit Karein'), findsOneWidget);
        // …guard still held…
        expect(h.controller.activeBookingId, 'booking-1');
        // …and crucially the Future has NOT resolved, so the caller cannot
        // navigate on to the linked bidding page.
        expect(resolved, isNull);

        // A later successful retry resolves it.
        h.repo.submitFailure = null;
        await _submitReview(tester);
        expect(resolved, isTrue);
      },
    );
  });

  // ── Queue behaviour ───────────────────────────────────────────────────────
  group('queue', () {
    testWidgets('multiple pending reviews open sequentially, never stacked', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        pending: [_completed('booking-1'), _completed('booking-2')],
      );

      h.controller.enqueue(h.context, 'booking-1');
      h.controller.enqueue(h.context, 'booking-2');
      await tester.pumpAndSettle();

      // Exactly one modal on screen.
      expect(find.text('Review Submit Karein'), findsOneWidget);
      expect(h.controller.activeBookingId, 'booking-1');

      await _submitReview(tester);

      // The next one opens only after the first closed — still just one.
      expect(find.text('Review Submit Karein'), findsOneWidget);
      expect(h.controller.activeBookingId, 'booking-2');

      await _submitReview(tester);
      expect(find.text('Review Submit Karein'), findsNothing);
      expect(h.repo.submitCalls, 2);
    });

    testWidgets('a notification tap jumps that booking to the FRONT', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        pending: [
          _completed('older-1'),
          _completed('older-2'),
          _completed('tapped'),
        ],
      );

      // Two older reviews queued by the resume sweep…
      h.controller.enqueue(h.context, 'older-1');
      h.controller.enqueue(h.context, 'older-2');
      // …then the client taps the notification for a different booking.
      h.controller.enqueueFront(h.context, 'tapped');
      await tester.pumpAndSettle();

      // The tapped booking is shown first, ahead of the older ones.
      expect(h.controller.activeBookingId, 'tapped');
    });

    testWidgets('enqueueing the booking already on screen does nothing', (
      tester,
    ) async {
      final h = await _pump(tester, pending: [_completed('booking-1')]);

      h.controller.enqueue(h.context, 'booking-1');
      await tester.pumpAndSettle();
      expect(h.controller.activeBookingId, 'booking-1');

      h.controller.enqueue(h.context, 'booking-1');
      await tester.pumpAndSettle();

      expect(find.text('Review Submit Karein'), findsOneWidget);
      expect(h.controller.queuedBookingIds, isEmpty);
    });
  });

  // ── Deferral is not suppression ───────────────────────────────────────────
  group('dismissed / failed reviews stay pending', () {
    testWidgets(
      'a dismissed ordinary review is deferred (no loop) but re-offered after '
      'resume, and is never treated as reviewed',
      (tester) async {
        final h = await _pump(tester, pending: [_completed('booking-1')]);

        h.controller.enqueue(h.context, 'booking-1');
        await tester.pumpAndSettle();
        expect(find.text('Review Submit Karein'), findsOneWidget);

        // Client taps "Baad Mein".
        await tester.tap(find.text('Baad Mein'));
        await tester.pumpAndSettle();

        expect(find.text('Review Submit Karein'), findsNothing);
        expect(h.repo.submitCalls, 0);
        // Deferred for this session so it cannot immediately reopen…
        expect(h.controller.isDeferred('booking-1'), isTrue);

        h.controller.enqueue(h.context, 'booking-1');
        await tester.pumpAndSettle();
        expect(find.text('Review Submit Karein'), findsNothing);

        // …but the app-resume sweep clears deferrals and re-offers it.
        h.controller.clearSessionDeferrals();
        await h.controller.refreshAndPrompt(h.context);
        await tester.pumpAndSettle();

        expect(find.text('Review Submit Karein'), findsOneWidget);
        expect(h.controller.activeBookingId, 'booking-1');
      },
    );

    testWidgets('backend truth decides: a reviewed booking is never prompted', (
      tester,
    ) async {
      // Backend no longer lists it ⇒ its review exists ⇒ forget it for good.
      final h = await _pump(tester, pending: const []);

      h.controller.enqueue(h.context, 'already-reviewed');
      await tester.pumpAndSettle();

      expect(find.text('Review Submit Karein'), findsNothing);
      expect(h.controller.activeBookingId, isNull);
    });

    testWidgets('refreshAndPrompt queues everything the backend still lists', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        pending: [_completed('booking-1'), _completed('booking-2')],
      );

      await h.controller.refreshAndPrompt(h.context);
      await tester.pumpAndSettle();

      expect(h.repo.pendingCalls, greaterThan(0));
      expect(h.controller.activeBookingId, 'booking-1');
    });
  });

  // ── Roman Urdu wording ────────────────────────────────────────────────────
  testWidgets('review modal wording is Roman Urdu', (tester) async {
    final h = await _pump(tester, pending: [_completed('booking-1')]);
    h.controller.enqueue(h.context, 'booking-1');
    await tester.pumpAndSettle();

    expect(find.text('Review Submit Karein'), findsOneWidget);
    expect(find.text('Baad Mein'), findsOneWidget);
    expect(find.text('Kaam kaisa raha?'), findsOneWidget);
  });
}
