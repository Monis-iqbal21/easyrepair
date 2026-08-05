import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/new_job_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_profile_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_stats_entity.dart';
import 'package:handygo_app/features/worker/presentation/pages/worker_jobs_page.dart';
import 'package:handygo_app/features/worker/presentation/pages/worker_new_jobs_page.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_job_providers.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_providers.dart';

/// New Jobs / My Jobs cards must show the real canonical price for each
/// lane — the fixed STANDARD total, the INSPECTION fee, the accepted bid
/// once hired — and no price at all for a still-open BIDDING job. Never an
/// "estimate".

// ── Fixtures ─────────────────────────────────────────────────────────────────

BookingEntity _job({
  required BookingLane lane,
  required BookingStatus status,
  double? finalPrice,
  double? acceptedBidAmount,
  double? inspectionFeeSnapshot,
  List<BookingStandardServiceItemEntity> standardServiceItems = const [],
  bool isInspectionOnlyForCaller = false,
  InspectionDecisionStatus? inspectionDecisionStatus,
}) {
  return BookingEntity(
    id: 'job-${lane.name}',
    referenceId: '#HG-${lane.name}',
    serviceCategory: 'Electrician',
    serviceEmoji: '⚡',
    status: status,
    urgency: BookingUrgency.normal,
    createdAt: DateTime(2026, 7, 1),
    lane: lane,
    finalPrice: finalPrice,
    acceptedBidAmount: acceptedBidAmount,
    inspectionFeeSnapshot: inspectionFeeSnapshot,
    standardServiceItems: standardServiceItems,
    isInspectionOnlyForCaller: isInspectionOnlyForCaller,
    inspectionDecisionStatus: inspectionDecisionStatus,
    assignedWorker: const AssignedWorkerEntity(
      id: 'w1',
      firstName: 'Ali',
      lastName: 'Khan',
    ),
  );
}

NewJobEntity _newJob({
  required BookingLane lane,
  double? inspectionFeeSnapshot,
  List<BookingStandardServiceItemEntity> standardServiceItems = const [],
}) {
  return NewJobEntity(
    id: 'new-${lane.name}',
    status: BookingStatus.pending,
    urgency: BookingUrgency.normal,
    city: 'Lahore',
    latitude: 0,
    longitude: 0,
    createdAt: DateTime(2026, 7, 1),
    category: const NewJobCategoryEntity(id: 'c1', name: 'Electrician'),
    client: const NewJobClientEntity(id: 'cl1', firstName: 'A', lastName: 'B'),
    bidCount: 0,
    lane: lane,
    inspectionFeeSnapshot: inspectionFeeSnapshot,
    standardServiceItems: standardServiceItems,
  );
}

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeWorkerJobsNotifier extends WorkerJobsNotifier {
  _FakeWorkerJobsNotifier(this._jobs);
  final List<BookingEntity> _jobs;

  @override
  Future<List<BookingEntity>> build() async => _jobs;
}

class _FakeNewJobsNotifier extends NewJobsNotifier {
  _FakeNewJobsNotifier(this._jobs);
  final List<NewJobEntity> _jobs;

  @override
  Future<List<NewJobEntity>> build() async => _jobs;
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

Widget _wrapMyJobs(List<BookingEntity> jobs) {
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
    child: MaterialApp.router(
      routerConfig: router,
      locale: AppLocale.english.locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      localeResolutionCallback: (_, _) => AppLocale.english.locale,
    ),
  );
}

Widget _wrapNewJobs(List<NewJobEntity> jobs) {
  final router = GoRouter(
    initialLocation: '/worker/jobs/new',
    routes: [
      GoRoute(
        path: '/worker/jobs/new',
        builder: (_, _) => const WorkerNewJobsPage(),
      ),
      GoRoute(
        path: '/worker/job/:id',
        builder: (_, _) => const Scaffold(body: Text('JOB_DETAIL')),
      ),
      GoRoute(
        path: '/worker/job/:id/bid',
        builder: (_, _) => const Scaffold(body: Text('BID_PAGE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      newJobsProvider.overrideWith(() => _FakeNewJobsNotifier(jobs)),
      workerProfileProvider.overrideWith(_FakeWorkerProfileNotifier.new),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: AppLocale.english.locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      localeResolutionCallback: (_, _) => AppLocale.english.locale,
    ),
  );
}

void main() {
  // The default 800x600 test surface is shorter than any real phone and
  // makes these pages' fixed header + filter tabs + bottom nav overflow
  // regardless of the cards under test. Pump at a realistic portrait phone
  // size instead (same fix as find_other_ustaad_test.dart).
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2340);
    view.devicePixelRatio = 3.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('Worker My Jobs card price', () {
    testWidgets('STANDARD: shows the hired fixed price', (tester) async {
      await tester.pumpWidget(_wrapMyJobs([
        _job(
          lane: BookingLane.standard,
          status: BookingStatus.accepted,
          finalPrice: 2500,
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Rs 2,500'), findsOneWidget);
    });

    testWidgets('INSPECTION-only completed: shows the fee', (tester) async {
      await tester.pumpWidget(_wrapMyJobs([
        _job(
          lane: BookingLane.inspection,
          status: BookingStatus.completed,
          finalPrice: 500,
          inspectionFeeSnapshot: 500,
          isInspectionOnlyForCaller: true,
          inspectionDecisionStatus: InspectionDecisionStatus.findOtherUstaad,
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Rs 500'), findsOneWidget);
    });

    testWidgets('BIDDING: shows the accepted bid', (tester) async {
      await tester.pumpWidget(_wrapMyJobs([
        _job(
          lane: BookingLane.bidding,
          status: BookingStatus.accepted,
          acceptedBidAmount: 4500,
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Rs 4,500'), findsOneWidget);
    });

    testWidgets('never shows "Estimated"/"Estimate" wording', (tester) async {
      await tester.pumpWidget(_wrapMyJobs([
        _job(
          lane: BookingLane.standard,
          status: BookingStatus.accepted,
          finalPrice: 2500,
        ),
        _job(
          lane: BookingLane.bidding,
          status: BookingStatus.accepted,
          acceptedBidAmount: 4500,
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.textContaining('Estimat'), findsNothing);
    });
  });

  group('Worker New Jobs card price', () {
    testWidgets('STANDARD: shows the fixed job price', (tester) async {
      await tester.pumpWidget(_wrapNewJobs([
        _newJob(
          lane: BookingLane.standard,
          standardServiceItems: const [
            BookingStandardServiceItemEntity(
              id: 'i1',
              nameSnapshot: 'AC Service',
              priceSnapshot: 2200,
            ),
          ],
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Rs 2,200'), findsOneWidget);
    });

    testWidgets('INSPECTION: shows the fee', (tester) async {
      await tester.pumpWidget(_wrapNewJobs([
        _newJob(lane: BookingLane.inspection, inspectionFeeSnapshot: 500),
      ]));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rs 500'), findsOneWidget);
    });

    testWidgets(
      'BIDDING: shows no job price and never "Bid: No" as an amount',
      (tester) async {
        await tester.pumpWidget(_wrapNewJobs([
          _newJob(lane: BookingLane.bidding),
        ]));
        await tester.pumpAndSettle();

        expect(find.textContaining('Rs '), findsNothing);
        expect(find.textContaining('Bid: No'), findsNothing);
      },
    );

    testWidgets('never shows "Estimated"/"Estimate" wording', (tester) async {
      await tester.pumpWidget(_wrapNewJobs([
        _newJob(
          lane: BookingLane.standard,
          standardServiceItems: const [
            BookingStandardServiceItemEntity(
              id: 'i1',
              nameSnapshot: 'AC Service',
              priceSnapshot: 2200,
            ),
          ],
        ),
        _newJob(lane: BookingLane.inspection, inspectionFeeSnapshot: 500),
        _newJob(lane: BookingLane.bidding),
      ]));
      await tester.pumpAndSettle();

      expect(find.textContaining('Estimat'), findsNothing);
    });
  });
}
