import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/data/cached_result.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/features/bookings/data/models/booking_model.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/worker/data/repositories/worker_repository_impl.dart';
import 'package:handygo_app/features/worker/domain/repositories/worker_repository.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_job_providers.dart';
import 'package:handygo_app/features/worker/presentation/utils/worker_status_labels.dart';
import 'package:handygo_app/l10n/app_localizations.dart';

/// My Jobs → Applied/Bids is derived from the worker's own bid history (see
/// WorkersService.getWorkerJobs on the backend) — this is account history,
/// never gated by ONLINE/OFFLINE availability. These tests cover the Flutter
/// wiring: the new filter reaches the backend with the right query value,
/// and its results flow through the same cache-aware pipeline every other
/// My Jobs filter already uses.
class _FakeWorkerRepository implements WorkerRepository {
  _FakeWorkerRepository(this._byFilter);
  final Map<String?, List<BookingEntity>> _byFilter;
  final List<String?> calls = [];

  @override
  Future<Either<Failure, CachedResult<List<BookingEntity>>>> getWorkerJobs(
    String? statusFilter,
  ) async {
    calls.add(statusFilter);
    return Right(CachedResult(_byFilter[statusFilter] ?? const []));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

BookingEntity _booking(String id, {BookingStatus status = BookingStatus.pending}) {
  return BookingEntity(
    id: id,
    referenceId: '#ER-$id',
    serviceCategory: 'Plumbing',
    serviceEmoji: '🔧',
    status: status,
    urgency: BookingUrgency.normal,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test("WorkerJobFilter.applied sends filter=applied to the backend", () async {
    final repo = _FakeWorkerRepository({
      'applied': [_booking('bid-job-1')],
    });
    final container = ProviderContainer(
      overrides: [workerRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    container.read(workerJobsProvider.notifier).setFilter(WorkerJobFilter.applied);
    final jobs = await container.read(workerJobsProvider.future);

    expect(repo.calls, contains('applied'));
    expect(jobs.map((j) => j.id), ['bid-job-1']);
  });

  test('a bid whose job was assigned to another worker still appears under '
      'Applied (booking status ACCEPTED, worker not the caller)', () async {
    final repo = _FakeWorkerRepository({
      'applied': [_booking('lost-bid', status: BookingStatus.accepted)],
    });
    final container = ProviderContainer(
      overrides: [workerRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    container.read(workerJobsProvider.notifier).setFilter(WorkerJobFilter.applied);
    final jobs = await container.read(workerJobsProvider.future);

    expect(jobs, hasLength(1));
    expect(jobs.single.status, BookingStatus.accepted);
  });

  test('switching between filters queries the correct backend value each time',
      () async {
    final repo = _FakeWorkerRepository({
      'active': [_booking('active-1')],
      'applied': [_booking('applied-1')],
      'completed': [_booking('completed-1')],
      'cancelled': [_booking('cancelled-1')],
    });
    final container = ProviderContainer(
      overrides: [workerRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(workerJobsProvider.notifier);
    for (final f in WorkerJobFilter.values) {
      notifier.setFilter(f);
      await container.read(workerJobsProvider.future);
    }

    expect(repo.calls, [null, 'active', 'applied', 'completed', 'cancelled']);
  });

  group('myBidStatus / myBidAmount parsing', () {
    Map<String, dynamic> appliedJson({
      required String bookingStatus,
      String? myBidStatus,
      num? myBidAmount,
    }) =>
        {
          'id': 'booking-1',
          'serviceCategory': 'Plumbing',
          'description': 'Fix the sink',
          'status': bookingStatus,
          'urgency': 'NORMAL',
          'city': 'Karachi',
          'createdAt': '2026-01-01T00:00:00.000Z',
          if (myBidStatus != null) 'myBidStatus': myBidStatus,
          if (myBidAmount != null) 'myBidAmount': myBidAmount,
        };

    test("a REJECTED bid on an ACCEPTED booking parses both independently — "
        "the booking moved on, this worker's own bid did not win", () {
      final entity = BookingModel.fromJson(
        appliedJson(
          bookingStatus: 'ACCEPTED',
          myBidStatus: 'REJECTED',
          myBidAmount: 1800,
        ),
      ).toEntity();

      expect(entity.status, BookingStatus.accepted);
      expect(entity.myBidStatus, BidOutcome.rejected);
      expect(entity.myBidAmount, 1800);
    });

    test('an ACCEPTED bid parses as accepted (this worker was hired)', () {
      final entity = BookingModel.fromJson(
        appliedJson(
          bookingStatus: 'ACCEPTED',
          myBidStatus: 'ACCEPTED',
          myBidAmount: 2000,
        ),
      ).toEntity();

      expect(entity.myBidStatus, BidOutcome.accepted);
    });

    test('a response without the bid fields (every non-Applied list/detail) '
        'leaves them null rather than defaulting to a status the worker '
        'does not have', () {
      final entity =
          BookingModel.fromJson(appliedJson(bookingStatus: 'COMPLETED'))
              .toEntity();

      expect(entity.myBidStatus, isNull);
      expect(entity.myBidAmount, isNull);
    });

    test('an unrecognized bid status is treated as absent, never guessed', () {
      final entity = BookingModel.fromJson(
        appliedJson(bookingStatus: 'PENDING', myBidStatus: 'SOMETHING_NEW'),
      ).toEntity();

      expect(entity.myBidStatus, isNull);
    });
  });

  group('workerJobFilterLabel — Applied', () {
    Future<AppLocalizations> l10nFor(AppLocale locale) =>
        AppLocalizations.delegate.load(locale.locale);

    test('every language has a real, non-empty label for it', () async {
      for (final locale in AppLocale.values) {
        final label =
            workerJobFilterLabel(await l10nFor(locale), WorkerJobFilter.applied);
        expect(label.trim(), isNotEmpty, reason: locale.storageValue);
      }
    });

    test('reuses the same wording as New Jobs "My Offers" filter (same '
        'concept, no duplicate English text)', () async {
      final l10n = await l10nFor(AppLocale.english);
      expect(
        workerJobFilterLabel(l10n, WorkerJobFilter.applied),
        l10n.workerFilterMyOffers,
      );
    });
  });
}
