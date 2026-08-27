import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/presentation/utils/booking_timeline.dart';
import 'package:handygo_app/features/bookings/presentation/widgets/detail/booking_timeline_section.dart';
import 'package:handygo_app/l10n/app_localizations.dart';

import '../../support/l10n_test_app.dart';

/// The Booking Detail progress timeline: connected dots, lane-specific
/// wording, no per-step timestamps, and never a step marked done that the
/// booking has not actually reached.

BookingEntity _booking({
  BookingLane lane = BookingLane.standard,
  BookingStatus status = BookingStatus.accepted,
  AssignedWorkerEntity? worker = const AssignedWorkerEntity(
    id: 'worker-1',
    firstName: 'Ali',
    lastName: 'Khan',
  ),
  DateTime? acceptedAt,
  DateTime? enRouteAt,
  DateTime? arrivedAt,
  DateTime? startedAt,
}) {
  return BookingEntity(
    id: 'booking-1',
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
  );
}

/// Resolves real localizations so the assertions read the shipped wording
/// rather than a duplicated copy of it.
Future<AppLocalizations> _l10n(
  WidgetTester tester, {
  AppLocale locale = AppLocale.english,
}) async {
  late AppLocalizations resolved;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale.locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      localeResolutionCallback: (_, _) => locale.locale,
      home: Builder(
        builder: (context) {
          resolved = AppLocalizations.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return resolved;
}

List<BookingTimelineStepState> _states(
  AppLocalizations l10n,
  BookingEntity booking,
) => bookingTimelineSteps(l10n, booking).map((s) => s.state).toList();

const _complete = BookingTimelineStepState.complete;
const _current = BookingTimelineStepState.current;
const _pending = BookingTimelineStepState.pending;

Future<void> _pumpTimeline(
  WidgetTester tester,
  BookingEntity booking, {
  AppLocale locale = AppLocale.english,
  ThemeData? theme,
  Size surface = const Size(390, 900),
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    localizedApp(
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: BookingTimelineSection(booking: booking),
        ),
      ),
      locale: locale,
      theme: theme ?? AppTheme.lightTheme,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('step progression follows the booking status, and only that', () {
    testWidgets('each live status marks exactly the steps it has reached', (
      tester,
    ) async {
      final l10n = await _l10n(tester);

      // PENDING: nothing has happened. No step may claim otherwise.
      expect(
        _states(l10n, _booking(status: BookingStatus.pending, worker: null)),
        [_pending, _pending, _pending, _pending, _pending],
      );
      expect(
        _states(l10n, _booking(status: BookingStatus.accepted)),
        [_current, _pending, _pending, _pending, _pending],
      );
      expect(
        _states(l10n, _booking(status: BookingStatus.enRoute)),
        [_complete, _current, _pending, _pending, _pending],
      );
      expect(
        _states(l10n, _booking(status: BookingStatus.arrived)),
        [_complete, _complete, _current, _pending, _pending],
      );
      expect(
        _states(l10n, _booking(status: BookingStatus.inProgress)),
        [_complete, _complete, _complete, _current, _pending],
      );
    });

    testWidgets('the whole completed family shows every step done and none '
        'current', (tester) async {
      final l10n = await _l10n(tester);
      for (final status in const [
        BookingStatus.completed,
        BookingStatus.awaitingConfirmation,
        BookingStatus.settled,
      ]) {
        expect(
          _states(l10n, _booking(status: status)),
          [_complete, _complete, _complete, _complete, _complete],
          reason: '$status is the completed family',
        );
      }
    });

    testWidgets('a cancelled job freezes where it actually stopped, with no '
        'current step', (tester) async {
      final l10n = await _l10n(tester);
      // Cancelled after the Ustaad arrived but before work began.
      final cancelled = _booking(
        status: BookingStatus.cancelled,
        acceptedAt: DateTime(2026, 8, 17, 9),
        enRouteAt: DateTime(2026, 8, 17, 10),
        arrivedAt: DateTime(2026, 8, 17, 11),
      );
      expect(_states(l10n, cancelled), [
        _complete,
        _complete,
        _complete,
        // Nothing is in progress on a cancelled job.
        _pending,
        _pending,
      ]);
    });

    testWidgets('a status never drags a later step along with it', (
      tester,
    ) async {
      final l10n = await _l10n(tester);
      for (final booking in [
        _booking(status: BookingStatus.accepted),
        _booking(status: BookingStatus.enRoute),
        _booking(status: BookingStatus.arrived),
        _booking(status: BookingStatus.inProgress),
      ]) {
        final states = _states(l10n, booking);
        final lastDone = states.lastIndexWhere((s) => s != _pending);
        // Everything after the furthest reached step is strictly pending.
        expect(
          states.skip(lastDone + 1).every((s) => s == _pending),
          isTrue,
          reason: '${booking.status} must not complete anything beyond itself',
        );
      }
    });
  });

  group('lane-specific wording', () {
    testWidgets('STANDARD', (tester) async {
      await _pumpTimeline(tester, _booking(lane: BookingLane.standard));
      expect(find.text('Work confirmed'), findsOneWidget);
      expect(find.text('On the way'), findsOneWidget);
      expect(find.text('Arrived'), findsOneWidget);
      expect(find.text('Work started'), findsOneWidget);
      expect(find.text('Work completed'), findsOneWidget);
    });

    testWidgets('INSPECTION', (tester) async {
      await _pumpTimeline(tester, _booking(lane: BookingLane.inspection));
      expect(find.text('Inspection confirmed'), findsOneWidget);
      expect(find.text('On the way'), findsOneWidget);
      expect(find.text('Arrived'), findsOneWidget);
      expect(find.text('Inspection started'), findsOneWidget);
      expect(find.text('Inspection completed'), findsOneWidget);
      // Inspection never borrows the repair-work wording.
      expect(find.text('Work confirmed'), findsNothing);
      expect(find.text('Work started'), findsNothing);
    });

    testWidgets('BIDDING with an Ustaad hired', (tester) async {
      await _pumpTimeline(tester, _booking(lane: BookingLane.bidding));
      expect(find.text('Ustaad hired'), findsOneWidget);
      expect(find.text('On the way'), findsOneWidget);
      expect(find.text('Arrived'), findsOneWidget);
      expect(find.text('Work started'), findsOneWidget);
      expect(find.text('Work completed'), findsOneWidget);
    });

    testWidgets('Roman Urdu matches the agreed wording', (tester) async {
      await _pumpTimeline(
        tester,
        _booking(lane: BookingLane.standard),
        locale: AppLocale.romanUrdu,
      );
      expect(find.text('Kaam confirm hua'), findsOneWidget);
      expect(find.text('Raaste mein'), findsOneWidget);
      expect(find.text('Pohanch gaya'), findsOneWidget);
      expect(find.text('Kaam shuru'), findsOneWidget);
      expect(find.text('Kaam complete'), findsOneWidget);

      await _pumpTimeline(
        tester,
        _booking(lane: BookingLane.inspection),
        locale: AppLocale.romanUrdu,
      );
      expect(find.text('Inspection confirm hui'), findsOneWidget);
      expect(find.text('Inspection shuru'), findsOneWidget);
      expect(find.text('Inspection complete'), findsOneWidget);

      await _pumpTimeline(
        tester,
        _booking(lane: BookingLane.bidding),
        locale: AppLocale.romanUrdu,
      );
      expect(find.text('Ustaad hire hua'), findsOneWidget);
    });

    testWidgets('no step carries a timestamp', (tester) async {
      await _pumpTimeline(
        tester,
        _booking(
          status: BookingStatus.inProgress,
          acceptedAt: DateTime(2026, 8, 17, 9, 30),
          enRouteAt: DateTime(2026, 8, 17, 10, 15),
          arrivedAt: DateTime(2026, 8, 17, 11),
          startedAt: DateTime(2026, 8, 17, 11, 20),
        ),
      );
      // The stamps drive the frozen-progress rule but are never rendered.
      expect(find.textContaining('AM'), findsNothing);
      expect(find.textContaining('PM'), findsNothing);
      expect(find.textContaining('Aug'), findsNothing);
    });
  });

  group('BIDDING before anyone is hired', () {
    testWidgets('shows the waiting message AND the five pending steps', (
      tester,
    ) async {
      final booking = _booking(
        lane: BookingLane.bidding,
        status: BookingStatus.pending,
        worker: null,
      );
      expect(bookingTimelineAwaitsWorker(booking), isTrue);

      await _pumpTimeline(tester, booking);
      // The note explains why nothing has progressed…
      expect(find.byKey(const Key('booking-timeline-awaiting')), findsOneWidget);
      expect(find.text('Waiting for an Ustaad'), findsOneWidget);
      // …and the lane's own five steps are still there, all of them pending.
      expect(find.byKey(const Key('booking-timeline-section')), findsOneWidget);
      expect(find.text('Ustaad hired'), findsOneWidget);
      expect(find.text('On the way'), findsOneWidget);
      expect(find.text('Arrived'), findsOneWidget);
      expect(find.text('Work started'), findsOneWidget);
      expect(find.text('Work completed'), findsOneWidget);
      // Nothing is ticked off: no step is faked as done or in progress.
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('STANDARD and INSPECTION show their steps while pending, with '
        'no waiting note — those lanes hire directly', (tester) async {
      for (final lane in const [BookingLane.standard, BookingLane.inspection]) {
        final booking = _booking(
          lane: lane,
          status: BookingStatus.pending,
          worker: null,
        );
        expect(bookingTimelineAwaitsWorker(booking), isFalse, reason: '$lane');
        await _pumpTimeline(tester, booking);
        expect(
          find.byKey(const Key('booking-timeline-section')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('booking-timeline-awaiting')), findsNothing);
      }
    });

    testWidgets('once a bid is accepted the waiting note goes away', (
      tester,
    ) async {
      final booking = _booking(
        lane: BookingLane.bidding,
        status: BookingStatus.accepted,
      );
      expect(bookingTimelineAwaitsWorker(booking), isFalse);
      await _pumpTimeline(tester, booking);
      expect(find.text('Ustaad hired'), findsOneWidget);
      expect(find.byKey(const Key('booking-timeline-awaiting')), findsNothing);
    });
  });

  group('terminal bookings keep their timeline', () {
    testWidgets('cancelled, rejected or expired before any progress shows all '
        'five steps pending — never hidden, never faked', (tester) async {
      for (final status in const [
        BookingStatus.cancelled,
        BookingStatus.rejected,
        BookingStatus.expired,
      ]) {
        for (final lane in BookingLane.values) {
          final booking = _booking(status: status, lane: lane, worker: null);

          final l10n = await _l10n(tester);
          expect(
            _states(l10n, booking),
            [_pending, _pending, _pending, _pending, _pending],
            reason: '$status / $lane: no progress happened',
          );

          await _pumpTimeline(tester, booking);
          // The timeline stays on the page for every lane.
          expect(
            find.byKey(const Key('booking-timeline-section')),
            findsOneWidget,
            reason: '$status / $lane must keep its timeline',
          );
          // Nothing complete, nothing current.
          expect(
            find.byIcon(Icons.check_rounded),
            findsNothing,
            reason: '$status / $lane must not tick any step',
          );
          // A finished booking is not waiting for anybody.
          expect(
            find.byKey(const Key('booking-timeline-awaiting')),
            findsNothing,
            reason: '$status / $lane is over, not waiting',
          );
        }
      }
    });

    testWidgets('each lane keeps its own wording when terminal', (
      tester,
    ) async {
      await _pumpTimeline(
        tester,
        _booking(
          lane: BookingLane.inspection,
          status: BookingStatus.expired,
          worker: null,
        ),
      );
      expect(find.text('Inspection confirmed'), findsOneWidget);
      expect(find.text('Inspection started'), findsOneWidget);
      expect(find.text('Inspection completed'), findsOneWidget);

      await _pumpTimeline(
        tester,
        _booking(
          lane: BookingLane.bidding,
          status: BookingStatus.rejected,
          worker: null,
        ),
      );
      expect(find.text('Ustaad hired'), findsOneWidget);
      expect(find.text('Work completed'), findsOneWidget);
    });

    testWidgets('a booking cancelled mid-job freezes at its real progress', (
      tester,
    ) async {
      final booking = _booking(
        status: BookingStatus.cancelled,
        acceptedAt: DateTime(2026, 8, 17, 9),
        enRouteAt: DateTime(2026, 8, 17, 10),
      );
      final l10n = await _l10n(tester);
      // Confirmed and on the way really happened; nothing after them did, and
      // nothing is "current" on a cancelled job.
      expect(_states(l10n, booking), [
        _complete,
        _complete,
        _pending,
        _pending,
        _pending,
      ]);

      await _pumpTimeline(tester, booking);
      expect(find.byKey(const Key('booking-timeline-section')), findsOneWidget);
      expect(find.text('Work confirmed'), findsOneWidget);
      expect(find.text('Work completed'), findsOneWidget);
      // Exactly the two steps that happened are ticked.
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('responsive and theming', () {
    testWidgets('no overflow from 320 to 600 px in any lane', (tester) async {
      for (final width in const [320.0, 360.0, 390.0, 430.0, 600.0]) {
        for (final lane in BookingLane.values) {
          await _pumpTimeline(
            tester,
            _booking(lane: lane, status: BookingStatus.inProgress),
            surface: Size(width, 900),
          );
          expect(tester.takeException(), isNull, reason: '$lane at $width');
        }
      }
    });

    testWidgets('Roman Urdu wording survives 320 px', (tester) async {
      await _pumpTimeline(
        tester,
        _booking(lane: BookingLane.bidding, status: BookingStatus.arrived),
        locale: AppLocale.romanUrdu,
        surface: const Size(320, 900),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders from semantic tokens in dark theme', (tester) async {
      await _pumpTimeline(
        tester,
        _booking(status: BookingStatus.enRoute),
        theme: AppTheme.darkTheme,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('booking-timeline-section')), findsOneWidget);
      expect(find.text('On the way'), findsOneWidget);
    });

    testWidgets('the waiting note and its steps render in dark theme too', (
      tester,
    ) async {
      await _pumpTimeline(
        tester,
        _booking(
          lane: BookingLane.bidding,
          status: BookingStatus.pending,
          worker: null,
        ),
        theme: AppTheme.darkTheme,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('booking-timeline-awaiting')), findsOneWidget);
      expect(find.byKey(const Key('booking-timeline-section')), findsOneWidget);
    });

    testWidgets('a terminal booking with no progress fits every width', (
      tester,
    ) async {
      for (final width in const [320.0, 360.0, 390.0, 430.0, 600.0]) {
        await _pumpTimeline(
          tester,
          _booking(
            lane: BookingLane.bidding,
            status: BookingStatus.expired,
            worker: null,
          ),
          surface: Size(width, 900),
        );
        expect(tester.takeException(), isNull, reason: 'expired at $width');
      }
    });
  });
}
