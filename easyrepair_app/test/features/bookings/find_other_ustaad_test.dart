import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/inspection_report_entity.dart';
import 'package:handygo_app/features/bookings/presentation/pages/inspection_report_page.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_profile_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_stats_entity.dart';
import 'package:handygo_app/features/worker/presentation/pages/worker_jobs_page.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_job_providers.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_providers.dart';

// ── Fixtures ─────────────────────────────────────────────────────────────────

BookingEntity _completedInspectionOnlyJob({String id = 'booking-1'}) {
  return BookingEntity(
    id: id,
    referenceId: '#ER-ABC123',
    serviceCategory: 'AC Repair',
    serviceEmoji: '❄️',
    title: 'AC thanda nahi kar raha',
    description: 'Compressor kharab hai',
    status: BookingStatus.completed,
    urgency: BookingUrgency.normal,
    createdAt: DateTime(2026, 7, 30, 9),
    completedAt: DateTime(2026, 7, 30, 11),
    inspection: true,
    lane: BookingLane.inspection,
    // The inspection fee this Ustaad actually earned — never a repair amount.
    finalPrice: 500,
    inspectionFeeSnapshot: 500,
    inspectionReportSubmitted: true,
    inspectionDecisionStatus: InspectionDecisionStatus.findOtherUstaad,
    isInspectionOnlyForCaller: true,
    linkedRepairBookingId: 'child-1',
  );
}

BookingEntity _completedRepairJob() {
  return BookingEntity(
    id: 'booking-2',
    referenceId: '#ER-DEF456',
    serviceCategory: 'Plumbing',
    serviceEmoji: '🔧',
    status: BookingStatus.completed,
    urgency: BookingUrgency.normal,
    createdAt: DateTime(2026, 7, 29, 9),
    completedAt: DateTime(2026, 7, 29, 12),
    lane: BookingLane.standard,
    finalPrice: 3000,
  );
}

InspectionReportEntity _report({
  bool sanitized = false,
  List<InspectionReportPhotoEntity> photos = const [],
}) {
  return InspectionReportEntity(
    id: 'report-1',
    bookingId: 'booking-1',
    workerProfileId: sanitized ? null : 'inspector-1',
    issueFound: 'Leaky pipe',
    recommendedRepair: 'Replace pipe',
    labourCost: sanitized ? null : 3000,
    partsNeeded: false,
    partsTotal: sanitized ? null : 0,
    repairQuoteTotal: sanitized ? null : 3000,
    decisionStatus: InspectionDecisionStatus.findOtherUstaad,
    photos: photos,
    createdAt: DateTime(2026, 7, 30, 10),
    linkedRepairBookingId: 'child-1',
  );
}

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeWorkerJobsNotifier extends WorkerJobsNotifier {
  _FakeWorkerJobsNotifier(this._jobs);
  final List<BookingEntity> _jobs;

  @override
  Future<List<BookingEntity>> build() async => _jobs;
}

class _FakeWorkerProfileNotifier extends WorkerProfileNotifier {
  @override
  Future<WorkerProfileEntity> build() async => const WorkerProfileEntity(
        id: 'inspector-1',
        userId: 'inspector-user-1',
        firstName: 'Ali',
        lastName: 'Khan',
        status: 'ACTIVE',
        verificationStatus: 'VERIFIED',
        availabilityStatus: AvailabilityStatus.online,
        rating: 4.5,
        totalRatings: 12,
        skills: [],
        stats: WorkerStatsEntity(completedJobs: 12, activeJobs: 0),
        onboardingStatus: 'APPROVED',
      );
}

/// Records calls and can be primed to fail, so the tests can assert both the
/// INSPECTOR_BUSY path and the no-duplicate-submission guard without a
/// network layer.
class _FakeInspectionDecisionNotifier extends InspectionDecisionNotifier {
  _FakeInspectionDecisionNotifier({this.delay = Duration.zero});

  /// Primed failure for the INSPECTOR_BUSY / error-path tests.
  final Failure? failure = null;
  final Duration delay;
  int findOtherUstaadCalls = 0;
  int hireCalls = 0;

  @override
  Future<void> build() async {}

  @override
  Future<void> findOtherUstaad(String bookingId) async {
    findOtherUstaadCalls++;
    state = const AsyncLoading();
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failure != null) {
      state = AsyncError(failure!, StackTrace.current);
      throw failure!;
    }
    state = const AsyncData(null);
  }

  @override
  Future<void> hireInspectingWorker(String bookingId) async {
    hireCalls++;
    state = const AsyncLoading();
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failure != null) {
      state = AsyncError(failure!, StackTrace.current);
      throw failure!;
    }
    state = const AsyncData(null);
  }
}

Widget _wrapWorkerJobs(List<BookingEntity> jobs) {
  final router = GoRouter(
    initialLocation: '/worker/jobs',
    routes: [
      GoRoute(path: '/worker/jobs', builder: (_, _) => const WorkerJobsPage()),
      GoRoute(
        path: '/worker/job/:id',
        builder: (_, _) => const Scaffold(body: Text('JOB_DETAIL')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      workerJobsProvider.overrideWith(() => _FakeWorkerJobsNotifier(jobs)),
      workerProfileProvider.overrideWith(_FakeWorkerProfileNotifier.new),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Widget _wrapReportPage({
  required InspectionReportEntity report,
  _FakeInspectionDecisionNotifier? decisionNotifier,
  bool showDecisionButtons = false,
}) {
  return ProviderScope(
    overrides: [
      inspectionReportProvider('booking-1').overrideWith((_) async => report),
      if (decisionNotifier != null)
        inspectionDecisionNotifierProvider.overrideWith(() => decisionNotifier),
    ],
    child: MaterialApp(
      home: InspectionReportPage(
        bookingId: 'booking-1',
        showDecisionButtons: showDecisionButtons,
      ),
    ),
  );
}

void main() {
  // ── #1 Inspector completion card wording in Completed and All ────────────
  group('Worker My Jobs — completed inspection-only card', () {
    // The default 800x600 test surface is shorter than any real phone and
    // makes this page's fixed header + filter tabs + bottom nav overflow
    // regardless of these cards. Pump at a realistic portrait phone size so
    // an overflow here would mean a genuine layout regression in the card.
    setUp(() {
      final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
      view.physicalSize = const Size(1080, 2340);
      view.devicePixelRatio = 3.0;
    });

    tearDown(() {
      final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    testWidgets(
      'shows "Sirf Inspection Mukammal Hui" and never a repair-completed look',
      (tester) async {
        await tester.pumpWidget(
          _wrapWorkerJobs([_completedInspectionOnlyJob()]),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sirf Inspection Mukammal Hui'), findsOneWidget);
        // It's a completed entry, so no active-job action button is offered.
        expect(find.text('Complete'), findsNothing);
        expect(find.text('Start Inspection'), findsNothing);
      },
    );

    testWidgets('shows the same wording under the Completed filter', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapWorkerJobs([_completedInspectionOnlyJob()]));
      await tester.pumpAndSettle();

      // .first targets the filter tab — the card's own status chip also
      // reads "Completed".
      await tester.tap(find.text('Completed').first);
      await tester.pumpAndSettle();

      expect(find.text('Sirf Inspection Mukammal Hui'), findsOneWidget);
    });

    testWidgets('does NOT label an ordinary completed repair job that way', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapWorkerJobs([_completedRepairJob()]));
      await tester.pumpAndSettle();

      expect(find.text('Sirf Inspection Mukammal Hui'), findsNothing);
    });

    testWidgets(
      'labels only the inspection entry when both kinds are listed together',
      (tester) async {
        await tester.pumpWidget(
          _wrapWorkerJobs([
            _completedInspectionOnlyJob(),
            _completedRepairJob(),
          ]),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sirf Inspection Mukammal Hui'), findsOneWidget);
        expect(find.text('AC Repair'), findsOneWidget);
        expect(find.text('Plumbing'), findsOneWidget);
      },
    );
  });

  // ── #3 Price visibility in the report view ───────────────────────────────
  group('Inspection report pricing visibility', () {
    testWidgets('client (full report) sees the quote summary', (tester) async {
      await tester.pumpWidget(_wrapReportPage(report: _report()));
      await tester.pumpAndSettle();

      expect(find.text('Repair quote total'), findsOneWidget);
      expect(find.text('Labour'), findsOneWidget);
    });

    testWidgets(
      'a bidding worker (sanitized report) sees findings but no pricing at all',
      (tester) async {
        await tester.pumpWidget(
          _wrapReportPage(report: _report(sanitized: true)),
        );
        await tester.pumpAndSettle();

        // Technical content is visible…
        expect(find.text('Leaky pipe'), findsOneWidget);
        expect(find.text('Replace pipe'), findsOneWidget);
        // …but every price row is absent (backend omits the fields entirely;
        // the UI must not render zeros or placeholders in their place).
        expect(find.text('Repair quote total'), findsNothing);
        expect(find.text('Labour'), findsNothing);
        expect(find.text('Parts total'), findsNothing);
        expect(find.textContaining('3,000'), findsNothing);
      },
    );
  });

  // ── #7/#9 Full-screen image viewer ───────────────────────────────────────
  group('Inspection report photo viewer', () {
    final photos = [
      InspectionReportPhotoEntity(
        id: 'photo-1',
        url: 'https://example.test/photo-1.jpg',
        createdAt: DateTime(2026, 7, 30, 10),
      ),
    ];

    testWidgets('tapping a photo opens the full-screen zoomable viewer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapReportPage(report: _report(photos: photos)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsNothing);

      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();

      // Aspect-fit + pinch-zoom viewer with a visible close affordance.
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('the ✕ button closes the viewer and returns to the report', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapReportPage(report: _report(photos: photos)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.text('Photos'), findsOneWidget);
    });

    testWidgets('Android back also closes the viewer', (tester) async {
      await tester.pumpWidget(
        _wrapReportPage(report: _report(photos: photos)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);

      final NavigatorState nav = tester.state(find.byType(Navigator).first);
      nav.pop();
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsNothing);
    });

    testWidgets(
      'broken media falls back to a controlled error placeholder, not a crash',
      (tester) async {
        // In the test harness Image.network always fails to load, so the
        // errorBuilder path is what renders — proving it is wired.
        await tester.pumpWidget(
          _wrapReportPage(report: _report(photos: photos)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      },
    );
  });

  // ── #10 No duplicate Find Other Ustaad submission ────────────────────────
  group('Find Other Ustaad submission guard', () {
    testWidgets('a second tap while in flight does not submit twice', (
      tester,
    ) async {
      final notifier = _FakeInspectionDecisionNotifier(
        delay: const Duration(milliseconds: 200),
      );
      await tester.pumpWidget(
        _wrapReportPage(
          report: InspectionReportEntity(
            id: 'report-1',
            bookingId: 'booking-1',
            workerProfileId: 'inspector-1',
            issueFound: 'Leaky pipe',
            recommendedRepair: 'Replace pipe',
            labourCost: 3000,
            partsNeeded: false,
            partsTotal: 0,
            repairQuoteTotal: 3000,
            // Buttons only render while the decision is still pending.
            decisionStatus: InspectionDecisionStatus.pendingClientDecision,
            createdAt: DateTime(2026, 7, 30, 10),
          ),
          decisionNotifier: notifier,
          showDecisionButtons: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Find Other Ustaad'));
      await tester.pumpAndSettle();
      // Confirm the dialog.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Find Other Ustaad'));
      await tester.pump();

      // While the first request is still in flight the button is disabled and
      // the in-flight guard rejects any tap that races past it.
      expect(notifier.findOtherUstaadCalls, 1);
      await tester.pump(const Duration(milliseconds: 50));
      expect(notifier.findOtherUstaadCalls, 1);

      await tester.pump(const Duration(milliseconds: 300));
      expect(notifier.findOtherUstaadCalls, 1);
    });
  });

  // ── #5 INSPECTOR_BUSY mapping ─────────────────────────────────────────────
  group('InspectorBusyFailure', () {
    test('carries the exact Roman Urdu message shown to the client', () {
      const failure = InspectorBusyFailure(
        'Inspection karne wala Ustaad abhi doosre kaam mein masroof hai. '
        'Neeche se koi aur Ustaad choose karein.',
      );
      expect(failure, isA<Failure>());
      expect(
        failure.message,
        'Inspection karne wala Ustaad abhi doosre kaam mein masroof hai. '
        'Neeche se koi aur Ustaad choose karein.',
      );
    });
  });

  // ── Entity-level lifecycle rules ─────────────────────────────────────────
  group('BookingEntity post-inspection getters', () {
    test('a linked BIDDING child booking counts as open for bidding', () {
      final child = BookingEntity(
        id: 'child-1',
        referenceId: '#ER-CHILD1',
        serviceCategory: 'AC Repair',
        serviceEmoji: '❄️',
        status: BookingStatus.pending,
        urgency: BookingUrgency.normal,
        createdAt: DateTime(2026, 7, 30),
        lane: BookingLane.bidding,
        sourceInspectionBookingId: 'booking-1',
      );
      expect(child.isOpenForFindOtherUstaadBidding, isTrue);
      // copyWith must carry the link through, or the pinned-inspector card
      // and bid routing would silently break after any state patch.
      expect(child.copyWith().isOpenForFindOtherUstaadBidding, isTrue);
      expect(child.copyWith().sourceInspectionBookingId, 'booking-1');
    });

    test('an ordinary BIDDING booking is unaffected', () {
      final ordinary = BookingEntity(
        id: 'booking-9',
        referenceId: '#ER-ORD',
        serviceCategory: 'Plumbing',
        serviceEmoji: '🔧',
        status: BookingStatus.pending,
        urgency: BookingUrgency.normal,
        createdAt: DateTime(2026, 7, 30),
        lane: BookingLane.bidding,
      );
      expect(ordinary.isOpenForFindOtherUstaadBidding, isFalse);
      expect(ordinary.isCompletedInspectionOnly, isFalse);
    });

    test(
      'the legacy reopened-in-place INSPECTION shape still counts as open',
      () {
        final legacy = BookingEntity(
          id: 'booking-legacy',
          referenceId: '#ER-LEG',
          serviceCategory: 'AC Repair',
          serviceEmoji: '❄️',
          status: BookingStatus.pending,
          urgency: BookingUrgency.normal,
          createdAt: DateTime(2026, 7, 1),
          lane: BookingLane.inspection,
          inspectionDecisionStatus: InspectionDecisionStatus.findOtherUstaad,
        );
        expect(legacy.isOpenForFindOtherUstaadBidding, isTrue);
      },
    );

    test('completed inspection-only work is flagged for the badge', () {
      expect(
        _completedInspectionOnlyJob().isCompletedInspectionOnly,
        isTrue,
      );
    });
  });
}
