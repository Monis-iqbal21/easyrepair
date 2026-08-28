import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/presentation/pages/track_worker_page.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:handygo_app/features/bookings/domain/entities/cash_payment_confirmation_entity.dart';
import 'package:handygo_app/features/bookings/presentation/widgets/cash_payment_confirmation_card.dart';

import '../../support/l10n_test_app.dart';

const _bookingId = 'booking-1';

const _worker = AssignedWorkerEntity(
  id: 'worker-1',
  firstName: 'Ali',
  lastName: 'Khan',
  phone: '+923001234567',
);

BookingEntity _booking({
  BookingLane lane = BookingLane.standard,
  BookingStatus status = BookingStatus.accepted,
  AssignedWorkerEntity? worker = _worker,
  DateTime? acceptedAt,
  DateTime? enRouteAt,
  DateTime? arrivedAt,
  DateTime? startedAt,
  bool hasLocation = false,
  double? receivedAmount,
}) {
  return BookingEntity(
    id: _bookingId,
    referenceId: '#ER-123456',
    serviceCategory: 'AC Technician',
    serviceEmoji: '❄️',
    status: status,
    urgency: BookingUrgency.normal,
    createdAt: DateTime(2026, 8, 1),
    lane: lane,
    assignedWorker: worker,
    acceptedAt: acceptedAt,
    enRouteAt: enRouteAt,
    arrivedAt: arrivedAt,
    startedAt: startedAt,
    hasLocation: hasLocation,
    latitude: hasLocation ? 31.5204 : 0,
    longitude: hasLocation ? 74.3587 : 0,
    address: hasLocation ? 'Lahore' : null,
    receivedAmount: receivedAmount,
  );
}

class _StubDetailNotifier extends BookingDetailNotifier {
  _StubDetailNotifier(this.booking);

  final BookingEntity booking;

  @override
  Future<BookingEntity> build(String arg) async => booking;
}

class _FailingDetailNotifier extends BookingDetailNotifier {
  @override
  Future<BookingEntity> build(String arg) async {
    throw Exception('raw tracking stack details');
  }
}

class _NoopCashPaymentPromptController implements CashPaymentPromptController {
  @override
  String? get activeBookingId => null;

  @override
  bool get isShowing => false;

  @override
  Future<void> get whenIdle => Future<void>.value();

  @override
  Future<CashPaymentConfirmationEntity?> showForBooking(
    BuildContext context,
    BookingEntity booking, {
    bool automatic = false,
  }) async => null;
}

Future<void> _pumpTrackWorker(
  WidgetTester tester,
  BookingEntity booking, {
  ThemeData? theme,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookingDetailProvider.overrideWith(() => _StubDetailNotifier(booking)),
        cashPaymentPromptControllerProvider.overrideWithValue(
          _NoopCashPaymentPromptController(),
        ),
      ],
      child: localizedApp(
        const TrackWorkerPage(bookingId: _bookingId),
        theme: theme ?? AppTheme.lightTheme,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _timelineChecks() => find.descendant(
  of: find.byKey(const Key('track-worker-timeline')),
  matching: find.byIcon(Icons.check_rounded),
);

Finder _timelineCurrent() => find.descendant(
  of: find.byKey(const Key('track-worker-timeline')),
  matching: find.byKey(const Key('track-worker-timeline-current')),
);

void main() {
  testWidgets('uses Booking Detail labels for every booking lane', (
    tester,
  ) async {
    const expectedByLane = {
      BookingLane.standard: [
        'Work confirmed',
        'On the way',
        'Arrived',
        'Work started',
        'Work completed',
      ],
      BookingLane.inspection: [
        'Inspection confirmed',
        'On the way',
        'Arrived',
        'Inspection started',
        'Inspection completed',
      ],
      BookingLane.bidding: [
        'Ustaad hired',
        'On the way',
        'Arrived',
        'Work started',
        'Work completed',
      ],
    };

    for (final entry in expectedByLane.entries) {
      await _pumpTrackWorker(tester, _booking(lane: entry.key));
      expect(find.byKey(const Key('track-worker-timeline')), findsOneWidget);
      for (final label in entry.value) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: '${entry.key}: $label',
        );
      }
    }
  });

  testWidgets('uses Booking Detail lifecycle progression for every status', (
    tester,
  ) async {
    const completedStepsByStatus = {
      BookingStatus.pending: 0,
      BookingStatus.accepted: 0,
      BookingStatus.enRoute: 1,
      BookingStatus.arrived: 2,
      BookingStatus.inProgress: 3,
      BookingStatus.completed: 5,
      BookingStatus.awaitingConfirmation: 5,
      BookingStatus.settled: 5,
    };

    for (final entry in completedStepsByStatus.entries) {
      await _pumpTrackWorker(
        tester,
        _booking(
          status: entry.key,
          worker: entry.key == BookingStatus.pending ? null : _worker,
        ),
      );
      expect(
        _timelineChecks(),
        findsNWidgets(entry.value),
        reason: '${entry.key} must match Booking Detail progression',
      );
      final currentSteps = switch (entry.key) {
        BookingStatus.accepted ||
        BookingStatus.enRoute ||
        BookingStatus.arrived ||
        BookingStatus.inProgress => 1,
        _ => 0,
      };
      expect(
        _timelineCurrent(),
        findsNWidgets(currentSteps),
        reason: '${entry.key} must match Booking Detail current step',
      );
    }
  });

  testWidgets('terminal state freezes at furthest real lifecycle timestamp', (
    tester,
  ) async {
    for (final status in [
      BookingStatus.cancelled,
      BookingStatus.rejected,
      BookingStatus.expired,
    ]) {
      await _pumpTrackWorker(
        tester,
        _booking(
          status: status,
          acceptedAt: DateTime(2026, 8, 17, 9),
          enRouteAt: DateTime(2026, 8, 17, 10),
          arrivedAt: DateTime(2026, 8, 17, 11),
        ),
      );

      expect(
        _timelineChecks(),
        findsNWidgets(3),
        reason: '$status must freeze after Arrived',
      );
      expect(_timelineCurrent(), findsNothing);
      expect(find.text('Work started'), findsOneWidget);
      expect(find.text('Work completed'), findsOneWidget);
    }
  });

  testWidgets('timeline has no timestamps and Call/Chat remain available', (
    tester,
  ) async {
    await _pumpTrackWorker(
      tester,
      _booking(
        status: BookingStatus.inProgress,
        acceptedAt: DateTime(2026, 8, 17, 9, 30),
        enRouteAt: DateTime(2026, 8, 17, 10, 15),
        arrivedAt: DateTime(2026, 8, 17, 11),
        startedAt: DateTime(2026, 8, 17, 11, 20),
      ),
    );

    expect(find.textContaining('AM'), findsNothing);
    expect(find.textContaining('PM'), findsNothing);
    expect(find.byTooltip('Chat'), findsOneWidget);
    expect(find.byTooltip('Call'), findsOneWidget);
  });

  testWidgets('map remains present and semantic colors render in dark theme', (
    tester,
  ) async {
    await _pumpTrackWorker(
      tester,
      _booking(hasLocation: true, worker: null),
      theme: AppTheme.darkTheme,
    );

    expect(find.byType(GoogleMap), findsOneWidget);
    expect(find.byKey(const Key('track-worker-timeline')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed tracking exposes cash recovery CTA until settlement', (
    tester,
  ) async {
    await _pumpTrackWorker(tester, _booking(status: BookingStatus.completed));
    expect(find.byKey(const Key('track-confirm-cash-button')), findsOneWidget);

    await _pumpTrackWorker(
      tester,
      _booking(status: BookingStatus.completed, receivedAmount: 2500),
    );
    expect(find.byKey(const Key('track-confirm-cash-button')), findsNothing);

    await _pumpTrackWorker(tester, _booking(status: BookingStatus.inProgress));
    expect(find.byKey(const Key('track-confirm-cash-button')), findsNothing);
  });

  testWidgets('tracking load failure uses friendly copy and hides raw errors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingDetailProvider.overrideWith(_FailingDetailNotifier.new),
          cashPaymentPromptControllerProvider.overrideWithValue(
            _NoopCashPaymentPromptController(),
          ),
        ],
        child: localizedApp(
          const TrackWorkerPage(bookingId: _bookingId),
          theme: AppTheme.darkTheme,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load tracking'), findsOneWidget);
    expect(find.text('Failed to load tracking data.'), findsOneWidget);
    expect(find.textContaining('raw tracking stack details'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
