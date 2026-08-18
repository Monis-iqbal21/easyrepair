import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/data/cache_policy.dart';
import 'package:handygo_app/core/data/cached_result.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/network/connectivity_service.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_profile_entity.dart';
import 'package:handygo_app/features/worker/data/repositories/worker_repository_impl.dart';
import 'package:handygo_app/features/worker/domain/repositories/worker_repository.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_job_providers.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_providers.dart';

/// WORKER offline behaviour.
///
/// The single most important property here is the one the presence work
/// depends on: **device connectivity is not availability**. A Worker with no
/// signal is still ONLINE as far as the server is concerned (their presence
/// lease handles staleness separately), and losing or regaining a connection
/// must never write an availability change.
class _FakeWorkerRepository implements WorkerRepository {
  _FakeWorkerRepository();

  final Map<String?, List<Either<Failure, CachedResult<List<BookingEntity>>>>>
      jobsByFilter = {};
  final List<Either<Failure, CachedResult<BookingEntity>>> jobDetailResults =
      [];
  /// Every availability write that reached the repository. Must stay empty
  /// across connectivity changes.
  final List<AvailabilityStatus> availabilityWrites = [];

  @override
  Future<Either<Failure, CachedResult<List<BookingEntity>>>> getWorkerJobs(
    String? statusFilter,
  ) async {
    final queue = jobsByFilter[statusFilter];
    if (queue == null || queue.isEmpty) return Right(CachedResult(const []));
    return queue.length == 1 ? queue.first : queue.removeAt(0);
  }

  @override
  Future<Either<Failure, CachedResult<BookingEntity>>> getWorkerJobById(
    String bookingId,
  ) async {
    if (jobDetailResults.isEmpty) {
      return Left(NetworkFailure('', code: FailureCode.noInternet));
    }
    return jobDetailResults.length == 1
        ? jobDetailResults.first
        : jobDetailResults.removeAt(0);
  }

  @override
  Future<Either<Failure, AvailabilityStatus>> updateAvailability({
    required AvailabilityStatus status,
    double? lat,
    double? lng,
  }) async {
    availabilityWrites.add(status);
    return Right(status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

BookingEntity _job(
  String id, {
  BookingStatus status = BookingStatus.accepted,
}) {
  return BookingEntity(
    id: id,
    referenceId: '#ER-$id',
    serviceCategory: 'Plumbing',
    serviceEmoji: '🔧',
    status: status,
    urgency: BookingUrgency.normal,
    createdAt: DateTime(2026, 8, 1),
  );
}

ProviderContainer _container(_FakeWorkerRepository repo) {
  final container = ProviderContainer(
    overrides: [workerRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => ConnectivityService.instance.debugIsOnline = true);
  tearDown(() => ConnectivityService.instance.debugIsOnline = true);

  group('availability is NEVER driven by device connectivity', () {
    test('losing the connection writes no availability change', () async {
      final repo = _FakeWorkerRepository();
      final container = _container(repo);
      // Materialise the providers that could plausibly react.
      container.read(workerJobsProvider);

      ConnectivityService.instance.debugIsOnline = false;
      await Future<void>.delayed(Duration.zero);

      expect(repo.availabilityWrites, isEmpty,
          reason: 'no internet must not mean availabilityStatus = OFFLINE');
    });

    test('reconnecting does not force the Worker ONLINE', () async {
      final repo = _FakeWorkerRepository();
      final container = _container(repo);
      container.read(workerJobsProvider);

      ConnectivityService.instance.debugIsOnline = false;
      await Future<void>.delayed(Duration.zero);
      ConnectivityService.instance.debugIsOnline = true;
      await Future<void>.delayed(Duration.zero);

      expect(repo.availabilityWrites, isEmpty,
          reason: 'reconnect refreshes DATA only — going online is a '
              'deliberate Worker action, never an automatic one');
    });

    test('a manually OFFLINE Worker stays OFFLINE across a reconnection',
        () async {
      final repo = _FakeWorkerRepository();
      _container(repo);

      ConnectivityService.instance.debugIsOnline = false;
      await Future<void>.delayed(Duration.zero);
      ConnectivityService.instance.debugIsOnline = true;
      await Future<void>.delayed(Duration.zero);

      // Manual OFFLINE (marketplace browsing) and "no internet" remain two
      // completely separate concepts — nothing above touched either.
      expect(repo.availabilityWrites, isEmpty);
    });
  });

  group('My Jobs history stays visible offline', () {
    test('the Active filter renders its cached rows', () async {
      final repo = _FakeWorkerRepository()
        ..jobsByFilter['active'] = [
          Right(CachedResult([_job('active-1')], isStale: true)),
        ];
      final container = _container(repo);
      container.read(workerJobsProvider.notifier).setFilter(
            WorkerJobFilter.active,
          );

      final jobs = await container.read(workerJobsProvider.future);

      expect(jobs.map((j) => j.id), ['active-1']);
      expect(container.read(workerJobsIsOfflineProvider), isTrue);
    });

    test('Applied / Completed / Cancelled each keep their OWN cached rows — '
        'one filter can never render another\'s', () async {
      final repo = _FakeWorkerRepository()
        ..jobsByFilter['applied'] = [
          Right(CachedResult([_job('bid-1')], isStale: true)),
        ]
        ..jobsByFilter['completed'] = [
          Right(CachedResult([_job('done-1', status: BookingStatus.completed)],
              isStale: true)),
        ]
        ..jobsByFilter['cancelled'] = [
          Right(CachedResult([_job('cx-1', status: BookingStatus.cancelled)],
              isStale: true)),
        ];
      final container = _container(repo);
      final notifier = container.read(workerJobsProvider.notifier);

      notifier.setFilter(WorkerJobFilter.applied);
      expect((await container.read(workerJobsProvider.future)).map((j) => j.id),
          ['bid-1']);

      notifier.setFilter(WorkerJobFilter.completed);
      expect((await container.read(workerJobsProvider.future)).map((j) => j.id),
          ['done-1']);

      notifier.setFilter(WorkerJobFilter.cancelled);
      expect((await container.read(workerJobsProvider.future)).map((j) => j.id),
          ['cx-1']);
    });

    test('history is NOT subject to the New Jobs 24h window', () {
      // My Jobs is account history: the last known snapshot stays available
      // however old it is. Only the live marketplace expires.
      expect(CachePolicy.accountHistory.maxAge, isNull);
      expect(CachePolicy.newJobs.maxAge, const Duration(hours: 24));
    });
  });

  group('Worker Job Detail offline', () {
    test('a previously loaded job renders from cache and is flagged stale',
        () async {
      final repo = _FakeWorkerRepository()
        ..jobDetailResults.add(
          Right(CachedResult(_job('job-1'), isStale: true)),
        );
      final container = _container(repo);

      final job = await container.read(workerJobDetailProvider('job-1').future);

      expect(job.id, 'job-1');
      expect(container.read(workerJobDetailIsOfflineProvider('job-1')), isTrue);
    });

    test('a job never opened before has nothing to show offline', () async {
      final container = _container(_FakeWorkerRepository());

      await expectLater(
        container.read(workerJobDetailProvider('never-opened').future),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('a cached job detail does not authorize a lifecycle transition — '
        'completing is a write and is blocked offline', () async {
      ConnectivityService.instance.debugIsOnline = false;
      final repo = _FakeWorkerRepository()
        ..jobDetailResults.add(
          Right(CachedResult(_job('job-1'), isStale: true)),
        );
      final container = _container(repo);
      await container.read(workerJobDetailProvider('job-1').future);

      // Whatever the cached status says, the server has to confirm the
      // transition. The offline guard refuses before any request is made.
      expect(offlineActionGuard(), isNotNull);
      expect(offlineActionGuard()!.code, FailureCode.offlineActionBlocked);
    });
  });

  group('reconnect refreshes Worker data in place', () {
    test('stale cached jobs are replaced by authoritative server state',
        () async {
      final repo = _FakeWorkerRepository()
        ..jobsByFilter['active'] = [
          Right(CachedResult([_job('job-1')], isStale: true)),
          Right(CachedResult(
            [_job('job-1', status: BookingStatus.completed)],
          )),
        ];
      final container = _container(repo);
      container.read(workerJobsProvider.notifier).setFilter(
            WorkerJobFilter.active,
          );

      var jobs = await container.read(workerJobsProvider.future);
      expect(jobs.single.status, BookingStatus.accepted);
      expect(container.read(workerJobsIsOfflineProvider), isTrue);

      await container.read(workerJobsProvider.notifier).refresh();

      jobs = container.read(workerJobsProvider).requireValue;
      expect(jobs.single.status, BookingStatus.completed);
      expect(container.read(workerJobsIsOfflineProvider), isFalse);
      // …and still no availability write anywhere in that flow.
      expect(repo.availabilityWrites, isEmpty);
    });
  });
}
