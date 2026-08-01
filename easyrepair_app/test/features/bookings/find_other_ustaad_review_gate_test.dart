import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import '../../support/l10n_test_app.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/presentation/providers/review_prompt_controller.dart';

/// The completed inspection booking whose review gates the transition.
BookingEntity _inspection({BookingReviewEntity? review}) {
  return BookingEntity(
    id: 'inspection-1',
    referenceId: '#ER-INSP1',
    serviceCategory: 'AC Repair',
    serviceEmoji: '❄️',
    status: BookingStatus.completed,
    urgency: BookingUrgency.normal,
    createdAt: DateTime(2026, 7, 30, 9),
    completedAt: DateTime(2026, 7, 30, 11),
    lane: BookingLane.inspection,
    inspectionDecisionStatus: InspectionDecisionStatus.findOtherUstaad,
    isInspectionOnlyForCaller: true,
    linkedRepairBookingId: 'child-1',
    review: review,
    inspectingWorker: const AssignedWorkerEntity(
      id: 'inspector-1',
      firstName: 'Ali',
      lastName: 'Khan',
      rating: 4.6,
    ),
  );
}

/// Mirrors `_findOtherUstaad`'s ordering exactly, so the sequencing contract
/// is pinned independently of the page's rendering.
class _FindOtherUstaadFlow {
  _FindOtherUstaadFlow({
    required this.controller,
    required this.request,
    required this.loadInspection,
  });

  final ReviewPromptController controller;
  final Future<void> Function() request;
  final Future<BookingEntity> Function() loadInspection;

  bool navigated = false;
  final List<String> steps = [];

  Future<void> run(BuildContext context) async {
    // 1. RESERVE FIRST — before the request, because the completion push can
    //    beat its HTTP response.
    controller.reserveMandatory('inspection-1');
    steps.add('reserved');

    try {
      await request();
      steps.add('request-ok');
    } catch (_) {
      // 2. Request failed ⇒ release, do not navigate.
      controller.releaseReservation('inspection-1');
      steps.add('released');
      return;
    }

    final booking = await loadInspection();

    if (booking.review == null) {
      if (!context.mounted) return;
      final submitted = await controller.showMandatory(context, booking);
      steps.add('review-$submitted');
      // 3. Only a confirmed submission may continue.
      if (!submitted) return;
    } else {
      controller.releaseReservation('inspection-1');
      steps.add('already-reviewed');
    }

    navigated = true;
    steps.add('navigated');
  }
}

Future<({BuildContext context, ProviderContainer container})> _pumpHost(
  WidgetTester tester,
) async {
  late BuildContext ctx;
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      child: localizedApp(
         Consumer(
          builder: (context, ref, _) {
            ctx = context;
            container = ProviderScope.containerOf(context);
            return const Scaffold(body: Text('REPORT'));
          },
        ),
        locale: AppLocale.romanUrdu,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (context: ctx, container: container);
}

void main() {
  group('Find Other Ustaad → review gate', () {
    testWidgets(
      'reserves the guard BEFORE the request, so a completion push arriving '
      'mid-flight opens no competing modal',
      (tester) async {
        final host = await _pumpHost(tester);
        final controller =
            host.container.read(reviewPromptControllerProvider);

        final reservedDuringRequest = Completer<bool>();
        final flow = _FindOtherUstaadFlow(
          controller: controller,
          request: () async {
            // Simulates the push landing before the HTTP response.
            reservedDuringRequest.complete(
              controller.activeBookingId == 'inspection-1',
            );
            controller.enqueue(host.context, 'inspection-1');
            await Future<void>.delayed(const Duration(milliseconds: 20));
          },
          loadInspection: () async => _inspection(),
        );

        unawaited(flow.run(host.context));
        await tester.pump();

        // The guard was already held when the request was in flight…
        expect(await reservedDuringRequest.future, isTrue);
        await tester.pumpAndSettle();

        // …so the foreground enqueue was collapsed, not stacked: exactly one
        // modal, and it is the mandatory one (no "Baad Mein").
        expect(find.text('Review Submit Karein'), findsOneWidget);
        expect(find.text('Baad Mein'), findsNothing);
        expect(controller.queuedBookingIds, isEmpty);
        expect(flow.steps.first, 'reserved');
      },
    );

    testWidgets('a failed request releases the reservation and never navigates',
        (tester) async {
      final host = await _pumpHost(tester);
      final controller = host.container.read(reviewPromptControllerProvider);

      final flow = _FindOtherUstaadFlow(
        controller: controller,
        request: () async => throw Exception('network'),
        loadInspection: () async => _inspection(),
      );

      await flow.run(host.context);
      await tester.pumpAndSettle();

      expect(flow.navigated, isFalse);
      expect(controller.activeBookingId, isNull);
      expect(flow.steps, ['reserved', 'released']);
      expect(find.text('Review Submit Karein'), findsNothing);
    });

    testWidgets('an already-reviewed inspection navigates straight through', (
      tester,
    ) async {
      final host = await _pumpHost(tester);
      final controller = host.container.read(reviewPromptControllerProvider);

      final flow = _FindOtherUstaadFlow(
        controller: controller,
        request: () async {},
        loadInspection: () async => _inspection(
          review: BookingReviewEntity(
            id: 'review-1',
            rating: 5,
            comment: null,
            createdAt: DateTime(2026, 7, 30, 12),
          ),
        ),
      );

      await flow.run(host.context);
      await tester.pumpAndSettle();

      expect(find.text('Review Submit Karein'), findsNothing);
      expect(flow.navigated, isTrue);
      expect(flow.steps, ['reserved', 'request-ok', 'already-reviewed', 'navigated']);
      expect(controller.activeBookingId, isNull);
    });

    testWidgets(
      'the review is shown BEFORE navigating, and navigation waits for it',
      (tester) async {
        final host = await _pumpHost(tester);
        final controller =
            host.container.read(reviewPromptControllerProvider);

        final flow = _FindOtherUstaadFlow(
          controller: controller,
          request: () async {},
          loadInspection: () async => _inspection(),
        );

        unawaited(flow.run(host.context));
        await tester.pumpAndSettle();

        // Modal is up and nothing has navigated yet.
        expect(find.text('Review Submit Karein'), findsOneWidget);
        expect(flow.navigated, isFalse);
      },
    );

    testWidgets('the review targets the ORIGINAL inspection booking id', (
      tester,
    ) async {
      final host = await _pumpHost(tester);
      final controller = host.container.read(reviewPromptControllerProvider);

      final flow = _FindOtherUstaadFlow(
        controller: controller,
        request: () async {},
        loadInspection: () async => _inspection(),
      );

      unawaited(flow.run(host.context));
      await tester.pumpAndSettle();

      // Never the linked child booking ('child-1').
      expect(controller.activeBookingId, 'inspection-1');
      expect(controller.isMandatoryActive, isTrue);
    });
  });
}
