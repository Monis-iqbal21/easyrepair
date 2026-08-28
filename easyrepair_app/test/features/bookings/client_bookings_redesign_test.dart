import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:handygo_app/features/bookings/presentation/widgets/booking_card.dart';

import '../../support/l10n_test_app.dart';

const _worker = AssignedWorkerEntity(
  id: 'worker-1',
  firstName: 'Ali',
  lastName: 'Khan',
);

BookingEntity _booking({
  BookingLane lane = BookingLane.standard,
  BookingStatus status = BookingStatus.pending,
  String? title,
  String? description,
  DateTime? scheduledDate,
  TimeSlot? timeSlot = TimeSlot.afternoon,
  BookingUrgency urgency = BookingUrgency.normal,
  AssignedWorkerEntity? worker,
  double? finalPrice,
  double? acceptedBidAmount,
  double? inspectionFeeSnapshot,
  List<BookingStandardServiceItemEntity> items = const [],
  PaymentDisplayStatus payment = PaymentDisplayStatus.unpaid,
  double? receivedAmount,
  double? expectedAmount,
  double? remainingAmount,
  bool inspectionReportSubmitted = false,
  InspectionDecisionStatus? inspectionDecisionStatus,
}) {
  return BookingEntity(
    id: 'booking-123456',
    referenceId: '#ER-123456',
    serviceCategory: 'AC Technician',
    serviceEmoji: '❄️',
    title: title,
    description: description,
    status: status,
    urgency: urgency,
    timeSlot: timeSlot,
    scheduledDate: scheduledDate ?? DateTime(2026, 8, 17),
    createdAt: DateTime(2026, 8, 1),
    lane: lane,
    assignedWorker: worker,
    finalPrice: finalPrice,
    acceptedBidAmount: acceptedBidAmount,
    inspectionFeeSnapshot: inspectionFeeSnapshot,
    standardServiceItems: items,
    paymentDisplayStatus: payment,
    receivedAmount: receivedAmount,
    expectedAmount: expectedAmount,
    remainingAmount: remainingAmount,
    inspectionReportSubmitted: inspectionReportSubmitted,
    inspectionDecisionStatus: inspectionDecisionStatus,
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  BookingEntity booking, {
  AppLocale locale = AppLocale.english,
  ThemeData? theme,
  VoidCallback? onTap,
  VoidCallback? onCancel,
  VoidCallback? onChat,
  VoidCallback? onEdit,
  VoidCallback? onFindWorkers,
  VoidCallback? onTrackWorker,
  VoidCallback? onConfirmCash,
}) async {
  await tester.pumpWidget(
    localizedApp(
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: BookingCard(
            booking: booking,
            onTap: onTap ?? () {},
            onCancel: onCancel,
            onChat: onChat,
            onEdit: onEdit,
            onFindWorkers: onFindWorkers,
            onTrackWorker: onTrackWorker,
            onConfirmCash: onConfirmCash,
          ),
        ),
      ),
      locale: locale,
      theme: theme,
    ),
  );
}

void main() {
  group('shared Client BookingCard lane content', () {
    testWidgets('STANDARD shows selected services, canonical total and slot', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _booking(
          items: const [
            BookingStandardServiceItemEntity(
              id: '1',
              nameSnapshot: 'AC General Service',
              priceSnapshot: 2500,
            ),
            BookingStandardServiceItemEntity(
              id: '2',
              nameSnapshot: 'Split AC Installation',
              priceSnapshot: 3500,
            ),
          ],
        ),
      );

      expect(
        find.text('AC General Service, Split AC Installation'),
        findsOneWidget,
      );
      expect(find.text('Rs 6,000'), findsOneWidget);
      expect(find.text('Standard · 17 Aug · Afternoon'), findsOneWidget);
    });

    testWidgets('INSPECTION shows client problem, Inspection and current fee', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _booking(
          lane: BookingLane.inspection,
          description: 'AC se pani leak ho raha hai',
          inspectionFeeSnapshot: 500,
        ),
      );

      expect(find.text('AC se pani leak ho raha hai'), findsOneWidget);
      expect(find.textContaining('Inspection ·'), findsOneWidget);
      expect(find.textContaining('Muaina'), findsNothing);
      expect(find.text('Rs 500'), findsOneWidget);
    });

    testWidgets('BIDDING shows client title and no fake pre-acceptance price', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _booking(
          lane: BookingLane.bidding,
          title: 'Kitchen ki custom cabinets',
          description: 'Need custom work',
        ),
      );

      expect(find.text('Kitchen ki custom cabinets'), findsOneWidget);
      expect(find.textContaining('Bidding ·'), findsOneWidget);
      expect(find.textContaining('Rs '), findsNothing);
      expect(find.text('Searching for workers...'), findsOneWidget);
    });

    testWidgets('BIDDING shows accepted authoritative amount after hire', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _booking(
          lane: BookingLane.bidding,
          status: BookingStatus.accepted,
          title: 'Custom shelves',
          acceptedBidAmount: 4500,
          worker: _worker,
        ),
      );

      expect(find.text('Rs 4,500'), findsOneWidget);
      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('Details →'), findsOneWidget);
    });
  });

  group('status wording', () {
    final cases = <BookingStatus, String>{
      BookingStatus.accepted: 'Assigned',
      BookingStatus.enRoute: 'On the way',
      BookingStatus.arrived: 'Arrived',
      BookingStatus.inProgress: 'Work in progress',
      BookingStatus.completed: 'Completed',
      BookingStatus.cancelled: 'Cancelled',
      BookingStatus.expired: 'Expired',
    };

    for (final entry in cases.entries) {
      testWidgets('${entry.key} stays distinct', (tester) async {
        await _pumpCard(tester, _booking(status: entry.key));
        expect(find.text(entry.value), findsOneWidget);
      });
    }

    testWidgets('Roman Urdu preserves detailed lifecycle wording', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _booking(status: BookingStatus.enRoute, worker: _worker),
        locale: AppLocale.romanUrdu,
      );
      expect(find.text('Raaste mein'), findsOneWidget);
      expect(find.text('Assign hua'), findsNothing);
    });

    testWidgets('real inspection decision state says Waiting for quote', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _booking(
          lane: BookingLane.inspection,
          status: BookingStatus.inProgress,
          description: 'Unknown noise',
          inspectionFeeSnapshot: 500,
          inspectionReportSubmitted: true,
          inspectionDecisionStatus:
              InspectionDecisionStatus.pendingClientDecision,
        ),
      );
      expect(find.text('Waiting for quote'), findsOneWidget);
    });
  });

  group('payment display', () {
    testWidgets('ongoing UNPAID uses after-work wording', (tester) async {
      await _pumpCard(tester, _booking(status: BookingStatus.inProgress));
      expect(find.text('Cash — after work'), findsOneWidget);
    });

    testWidgets('recorded zero on completed booking says Nothing paid', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _booking(
          status: BookingStatus.completed,
          receivedAmount: 0,
          expectedAmount: 1000,
          remainingAmount: 1000,
        ),
      );
      expect(find.text('Nothing paid'), findsOneWidget);
    });

    testWidgets('PARTIAL shows received and remaining settlement amounts', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _booking(
          status: BookingStatus.completed,
          payment: PaymentDisplayStatus.partial,
          receivedAmount: 400,
          expectedAmount: 1000,
          remainingAmount: 600,
        ),
      );
      expect(find.text('Rs 400 paid · Rs 600 remaining'), findsOneWidget);
    });

    testWidgets('PAID has a semantic success tick', (tester) async {
      await _pumpCard(
        tester,
        _booking(
          status: BookingStatus.completed,
          payment: PaymentDisplayStatus.paid,
          receivedAmount: 1000,
          expectedAmount: 1000,
          remainingAmount: 0,
        ),
      );
      expect(find.text('✓ Paid'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });

  group('frozen action visibility and tap behavior', () {
    testWidgets('pending unassigned keeps Edit, Cancel and Choose Ustaad', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _booking(),
        onEdit: () {},
        onCancel: () {},
        onFindWorkers: () {},
      );
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Choose Ustaad'), findsOneWidget);
      expect(find.text('Track Worker'), findsNothing);
    });

    testWidgets('assigned keeps Chat, eligible Cancel and Track Worker', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _booking(status: BookingStatus.accepted, worker: _worker),
        onChat: () {},
        onCancel: () {},
        onTrackWorker: () {},
      );
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Track Worker'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('nested action does not trigger whole-card navigation', (
      tester,
    ) async {
      var cardTaps = 0;
      var editTaps = 0;
      await _pumpCard(
        tester,
        _booking(),
        onTap: () => cardTaps++,
        onEdit: () => editTaps++,
      );

      await tester.tap(find.text('Edit'));
      await tester.pump();
      expect(editTaps, 1);
      expect(cardTaps, 0);

      await tester.tap(find.text('AC Technician'));
      await tester.pump();
      expect(cardTaps, 1);
    });

    testWidgets('completed unpaid card exposes nested cash confirmation only', (
      tester,
    ) async {
      var cardTaps = 0;
      var confirmationTaps = 0;
      await _pumpCard(
        tester,
        _booking(status: BookingStatus.completed, worker: _worker),
        onTap: () => cardTaps++,
        onConfirmCash: () => confirmationTaps++,
      );

      expect(
        find.byKey(const Key('booking-card-confirm-cash-button')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('booking-card-confirm-cash-button')),
      );
      await tester.pump();
      expect(confirmationTaps, 1);
      expect(cardTaps, 0);

      await _pumpCard(
        tester,
        _booking(status: BookingStatus.inProgress, worker: _worker),
        onConfirmCash: () {},
      );
      expect(
        find.byKey(const Key('booking-card-confirm-cash-button')),
        findsNothing,
      );
    });
  });

  test('four Client filters map to the existing status groups exactly', () {
    final bookings = BookingStatus.values
        .map((status) => _booking(status: status))
        .toList();

    final active = bookings
        .where((b) => bookingMatchesClientTab(b, BookingTab.live))
        .map((b) => b.status)
        .toSet();
    expect(active, {
      BookingStatus.pending,
      BookingStatus.accepted,
      BookingStatus.enRoute,
      BookingStatus.arrived,
      BookingStatus.inProgress,
    });
    // AWAITING_CONFIRMATION and SETTLED are post-work settlement states on
    // the backend (grouped with COMPLETED in admin-operations), so they file
    // under Completed here — never under Active.
    expect(
      bookings
          .where((b) => bookingMatchesClientTab(b, BookingTab.completed))
          .map((b) => b.status)
          .toSet(),
      {
        BookingStatus.completed,
        BookingStatus.awaitingConfirmation,
        BookingStatus.settled,
      },
    );
    expect(
      bookings
          .where((b) => bookingMatchesClientTab(b, BookingTab.cancelled))
          .map((b) => b.status)
          .toSet(),
      {BookingStatus.rejected, BookingStatus.cancelled, BookingStatus.expired},
    );
  });

  for (final width in [320.0, 360.0, 390.0, 430.0, 600.0]) {
    testWidgets('card has no overflow at ${width.toInt()} px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpCard(
        tester,
        _booking(
          status: BookingStatus.accepted,
          worker: const AssignedWorkerEntity(
            id: 'long-worker',
            firstName: 'Muhammad Abdullah',
            lastName: 'Khan Ustaad Services',
          ),
          items: const [
            BookingStandardServiceItemEntity(
              id: 'long-service',
              nameSnapshot:
                  'Split AC Installation With Extra Long Service Description',
              priceSnapshot: 125000,
            ),
          ],
        ),
        onChat: () {},
        onCancel: () {},
        onTrackWorker: () {},
      );

      final layoutError = tester.takeException();
      expect(
        layoutError,
        isNull,
        reason: layoutError is FlutterError
            ? layoutError.toStringDeep()
            : layoutError?.toString(),
      );
    });
  }

  testWidgets('card renders from semantic tokens in dark theme', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _booking(
        status: BookingStatus.completed,
        payment: PaymentDisplayStatus.paid,
      ),
      theme: AppTheme.darkTheme,
    );
    expect(find.text('✓ Paid'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
