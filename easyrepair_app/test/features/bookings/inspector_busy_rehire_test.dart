import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import '../../support/l10n_test_app.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/features/bids/domain/entities/bid_entity.dart';
import 'package:handygo_app/features/bids/domain/repositories/bid_repository.dart';
import 'package:handygo_app/features/bids/presentation/providers/bid_providers.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/inspection_report_entity.dart';
import 'package:handygo_app/core/l10n/locale_provider.dart';
import 'package:handygo_app/features/bookings/presentation/pages/worker_discovery_map_page.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kBusyMessage =
    'Inspection karne wala Ustaad abhi doosre kaam mein masroof hai. '
    'Neeche se koi aur Ustaad choose karein.';

/// The linked BIDDING repair booking the client lands on after "Find Other
/// Ustaad" — carries the pinned inspecting Ustaad resolved from the source
/// inspection booking.
BookingEntity _linkedRepairBooking() {
  return BookingEntity(
    id: 'child-1',
    referenceId: '#ER-CHILD1',
    serviceCategory: 'AC Repair',
    serviceEmoji: '❄️',
    description: 'Leaky pipe\n\nReplace pipe',
    status: BookingStatus.pending,
    urgency: BookingUrgency.normal,
    createdAt: DateTime(2026, 7, 30, 11),
    lane: BookingLane.bidding,
    city: 'Karachi',
    latitude: 24.86,
    longitude: 67.0,
    sourceInspectionBookingId: 'booking-1',
    inspectingWorker: const AssignedWorkerEntity(
      id: 'inspector-1',
      firstName: 'Ali',
      lastName: 'Khan',
      rating: 4.6,
    ),
  );
}

InspectionReportEntity _clientReport() => InspectionReportEntity(
      id: 'report-1',
      bookingId: 'booking-1',
      workerProfileId: 'inspector-1',
      issueFound: 'Leaky pipe',
      recommendedRepair: 'Replace pipe',
      labourCost: 3000,
      partsNeeded: false,
      partsTotal: 0,
      repairQuoteTotal: 3000,
      decisionStatus: InspectionDecisionStatus.findOtherUstaad,
      createdAt: DateTime(2026, 7, 30, 10),
      linkedRepairBookingId: 'child-1',
    );

BidWithWorkerEntity _otherBid({
  String id = 'bid-1',
  String workerProfileId = 'worker-2',
  String firstName = 'Bilal',
  double amount = 2500,
}) {
  return BidWithWorkerEntity(
    bid: BidEntity(
      id: id,
      bookingId: 'child-1',
      workerProfileId: workerProfileId,
      amount: amount,
      status: BidStatus.pending,
      editCount: 0,
      createdAt: DateTime(2026, 7, 30, 12),
      updatedAt: DateTime(2026, 7, 30, 12),
    ),
    workerProfileId: workerProfileId,
    firstName: firstName,
    lastName: 'Ahmed',
    rating: 4.2,
    completedJobs: 8,
    distanceKm: 3.1,
    skills: const ['AC Repair'],
    currentLat: 24.87,
    currentLng: 67.01,
  );
}

/// Always fails the rehire with INSPECTOR_BUSY, exactly as the backend's
/// controlled 409 does once mapped by dio_failure_mapper.
class _BusyInspectorDecisionNotifier extends InspectionDecisionNotifier {
  int hireCalls = 0;

  @override
  Future<void> build() async {}

  @override
  Future<void> hireInspectingWorker(String bookingId) async {
    hireCalls++;
    state = const AsyncLoading();
    const failure = InspectorBusyFailure(_kBusyMessage);
    state = AsyncError(failure, StackTrace.current);
    throw failure;
  }
}

void main() {
  late _BusyInspectorDecisionNotifier decisionNotifier;
  late SharedPreferences testPrefs;

  // bookingRepositoryProvider's real datasource chain now reaches
  // LocalCacheService, which needs sharedPreferencesProvider — this
  // ProviderScope doesn't fully override bookingRepositoryProvider, so it
  // needs this in scope too, even though this test never exercises caching.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    testPrefs = await SharedPreferences.getInstance();
  });

  setUp(() {
    decisionNotifier = _BusyInspectorDecisionNotifier();
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1080, 2340);
    view.devicePixelRatio = 3.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> pumpBiddingPage(
    WidgetTester tester, {
    List<BidWithWorkerEntity>? bids,
  }) async {
    final booking = _linkedRepairBooking();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(testPrefs),
          bookingBidsProvider(
            booking.id,
          ).overrideWith((_) async => bids ?? [_otherBid()]),
          inspectionReportProvider(
            booking.id,
          ).overrideWith((_) async => _clientReport()),
          inspectionDecisionNotifierProvider
              .overrideWith(() => decisionNotifier),
        ],
        child: localizedApp(
          WorkerDiscoveryMapPage(booking: booking),
          // Asserts the Roman Urdu copy these flows shipped with.
          locale: AppLocale.romanUrdu,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The offers sheet opens at 20% of screen height (min == initial), which
    // leaves the pinned card and bid list below the fold and un-tappable.
    // Drag by roughly the 0.20→0.60 expansion distance — enough to open the
    // sheet fully without over-scrolling its content past the pinned card.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
    await tester.pumpAndSettle();
  }

  group('Client bidding list — pinned inspecting Ustaad', () {
    // ── #2 Client sees the pinned inspector card with their quote ──────────
    testWidgets(
      'shows the pinned inspector, their existing quote and the '
      '"Dobara Hire Karein" button',
      (tester) async {
        await pumpBiddingPage(tester);

        expect(find.text('IS KAAM KI INSPECTION KI'), findsOneWidget);
        expect(find.text('Ali Khan'), findsOneWidget);
        // The client (and only the client) sees the inspector's repair quote.
        expect(find.text('un ka quote'), findsOneWidget);
        expect(find.text('Dobara Hire Karein'), findsOneWidget);
      },
    );

    // ── #4 Optional report entry point ────────────────────────────────────
    testWidgets('offers an optional "Inspection Report Dekhein" link', (
      tester,
    ) async {
      await pumpBiddingPage(tester);
      expect(find.text('Inspection Report Dekhein'), findsOneWidget);
    });

    // ── #5/#6 Busy inspector: message shown, list and bids preserved ───────
    testWidgets(
      'a busy inspector shows the Roman Urdu message and keeps the client on '
      'the bidding list with every other bid still usable',
      (tester) async {
        await pumpBiddingPage(tester);

        await tester.tap(find.text('Dobara Hire Karein'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Hire karein'));
        await tester.pumpAndSettle();

        expect(decisionNotifier.hireCalls, 1);

        // The exact required Roman Urdu message.
        expect(find.text(_kBusyMessage), findsOneWidget);

        // Still on the bidding list — not navigated away, nothing hired, and
        // the rehire button is usable again rather than stuck loading.
        expect(find.byType(WorkerDiscoveryMapPage), findsOneWidget);
        expect(find.text('Dobara Hire Karein'), findsOneWidget);
        expect(find.text('Hire kiya ja raha hai…'), findsNothing);

        // The competing bid is still in the list, ready to hire instead.
        expect(find.text('Bilal Ahmed'), findsOneWidget);
      },
    );

    testWidgets(
      'after the busy message the client can still act on another bid '
      '(rehire never locked the list)',
      (tester) async {
        await pumpBiddingPage(
          tester,
          bids: [
            _otherBid(),
            _otherBid(
              id: 'bid-2',
              workerProfileId: 'worker-3',
              firstName: 'Kamran',
              amount: 2800,
            ),
          ],
        );

        await tester.tap(find.text('Dobara Hire Karein'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Hire karein'));
        await tester.pumpAndSettle();

        expect(find.text(_kBusyMessage), findsOneWidget);

        // The rehire button is re-enabled rather than stuck in a spinner, so
        // the client is never trapped by the failed attempt. The same
        // `isHiring` flag drives both the label and onPressed, so the idle
        // label being back means the button is tappable again.
        expect(find.text('Dobara Hire Karein'), findsOneWidget);
        expect(find.text('Hire kiya ja raha hai…'), findsNothing);

        // Both competing bids survive the failed rehire untouched and stay
        // reachable — the list was never invalidated or cleared.
        expect(find.text('Bilal Ahmed'), findsOneWidget);
        await tester.dragUntilVisible(
          find.text('Kamran Ahmed'),
          find.byType(CustomScrollView),
          const Offset(0, -60),
        );
        await tester.pumpAndSettle();
        expect(find.text('Kamran Ahmed'), findsOneWidget);
      },
    );
  });
}
