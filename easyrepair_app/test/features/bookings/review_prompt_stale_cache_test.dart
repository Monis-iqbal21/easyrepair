import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/domain/repositories/booking_repository.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:handygo_app/features/bookings/presentation/providers/review_prompt_controller.dart';

import '../../support/l10n_test_app.dart';

/// The review popup and the "Review Worker" button both queue through
/// [ReviewPromptController], which asked the backend whether the booking was
/// still unreviewed.
///
/// That answer was read from a cache the controller itself keeps alive. At
/// launch nothing is pending, so the cached list is empty — and every booking
/// queued afterwards looked "already reviewed" and was dropped in silence.
/// These tests pin the fix: a cache MISS must re-read backend truth before
/// concluding a review exists.
BookingEntity _booking(String id) => BookingEntity(
      id: id,
      referenceId: 'HG-$id',
      serviceCategory: 'Electrician',
      serviceEmoji: '⚡',
      status: BookingStatus.completed,
      urgency: BookingUrgency.normal,
      createdAt: DateTime(2026, 7, 1),
    );

/// Serves a list that changes between calls, exactly like the real endpoint
/// once a job completes after launch.
class _FakeBookingRepository implements BookingRepository {
  _FakeBookingRepository(this.responses);

  /// One entry per call; the last is reused once exhausted.
  final List<List<BookingEntity>> responses;
  int calls = 0;

  @override
  Future<Either<Failure, List<BookingEntity>>> getPendingReviews() async {
    final index = calls < responses.length ? calls : responses.length - 1;
    calls++;
    return Right(responses[index]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

Future<(ProviderContainer, BuildContext)> _pump(
  WidgetTester tester,
  _FakeBookingRepository repo,
) async {
  final container = ProviderContainer(
    overrides: [bookingRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedApp(const Scaffold(body: SizedBox())),
    ),
  );
  await tester.pumpAndSettle();
  return (container, tester.element(find.byType(Scaffold)));
}

void main() {
  testWidgets(
    'a booking completed after launch still opens its review modal',
    (tester) async {
      // First call: nothing pending (app just started).
      // Second call: the job has since completed.
      final repo = _FakeBookingRepository([
        const <BookingEntity>[],
        [_booking('b1')],
      ]);
      final (container, context) = await _pump(tester, repo);
      final controller = container.read(reviewPromptControllerProvider);

      // Warm the cache with the empty list, as app launch does.
      await container.read(pendingReviewsProvider.future);

      controller.enqueueFront(context, 'b1');
      await tester.pumpAndSettle();

      expect(
        controller.activeBookingId,
        'b1',
        reason: 'the prompt was dropped against a stale empty cache',
      );
      expect(repo.calls, greaterThan(1), reason: 'backend was never re-read');
    },
  );

  testWidgets('an already-reviewed booking is still never re-prompted', (
    tester,
  ) async {
    // The backend consistently says nothing is pending — the review exists.
    final repo = _FakeBookingRepository([const <BookingEntity>[]]);
    final (container, context) = await _pump(tester, repo);
    final controller = container.read(reviewPromptControllerProvider);

    controller.enqueueFront(context, 'reviewed-1');
    await tester.pumpAndSettle();

    expect(controller.activeBookingId, isNull);
    expect(controller.queuedBookingIds, isEmpty);
  });

  testWidgets('the modal opens only once for one completed booking', (
    tester,
  ) async {
    final repo = _FakeBookingRepository([
      [_booking('b1')],
    ]);
    final (container, context) = await _pump(tester, repo);
    final controller = container.read(reviewPromptControllerProvider);

    // Completion push, notification tap and the Review Worker button can all
    // fire for the same booking.
    controller.enqueueFront(context, 'b1');
    controller.enqueueFront(context, 'b1');
    controller.enqueue(context, 'b1');
    await tester.pumpAndSettle();

    expect(controller.activeBookingId, 'b1');
    expect(controller.queuedBookingIds, isEmpty);
  });

  testWidgets('a failed fetch is never mistaken for "already reviewed"', (
    tester,
  ) async {
    final repo = _FakeBookingRepository([
      [_booking('b1')],
    ]);
    final (container, context) = await _pump(tester, repo);
    final controller = container.read(reviewPromptControllerProvider);

    controller.enqueueFront(context, 'b1');
    await tester.pumpAndSettle();

    // Still offered, rather than silently discarded.
    expect(controller.activeBookingId, 'b1');
  });
}
