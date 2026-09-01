import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bookings/domain/entities/booking_entity.dart';
import '../../data/repositories/worker_repository_impl.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/new_job_entity.dart';
import '../../domain/entities/worker_payment_report_entity.dart';
import 'worker_providers.dart'; // for workerProfileProvider

// ── Filter ────────────────────────────────────────────────────────────────────

enum WorkerJobFilter { all, active, applied, completed, cancelled }

extension WorkerJobFilterX on WorkerJobFilter {
  // Visible wording: workerJobFilterLabel() in presentation/utils/worker_labels.dart.

  String? get apiValue => switch (this) {
    WorkerJobFilter.all => null,
    WorkerJobFilter.active => 'active',
    // Account history derived from this worker's own Bid rows — see
    // WorkersService.getWorkerJobs. Never gated by ONLINE/OFFLINE and
    // never disappears just because the job was later assigned to
    // someone else (see job-visibility task).
    WorkerJobFilter.applied => 'applied',
    WorkerJobFilter.completed => 'completed',
    WorkerJobFilter.cancelled => 'cancelled',
  };
}

// ── Jobs list notifier ────────────────────────────────────────────────────────

/// True while [workerJobsProvider] is showing the last cached list because
/// the live fetch failed.
final workerJobsIsOfflineProvider = StateProvider<bool>((ref) => false);

class WorkerJobsNotifier extends AsyncNotifier<List<BookingEntity>> {
  WorkerJobFilter _filter = WorkerJobFilter.all;

  WorkerJobFilter get currentFilter => _filter;

  @override
  Future<List<BookingEntity>> build() {
    final timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!state.isLoading) ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);
    return _fetch();
  }

  Future<List<BookingEntity>> _fetch() async {
    final result = await ref
        .read(workerRepositoryProvider)
        .getWorkerJobs(_filter.apiValue);
    return result.fold((f) => throw f, (cached) {
      ref.read(workerJobsIsOfflineProvider.notifier).state = cached.isStale;
      return cached.data;
    });
  }

  void setFilter(WorkerJobFilter newFilter) {
    if (_filter == newFilter) return;
    _filter = newFilter;
    // ref.invalidateSelf() re-runs build() (reading the new _filter) via
    // Riverpod's safe isRefreshing/copyWithPrevious path, so the list stays
    // visible instead of flashing to a skeleton while refetching.
    ref.invalidateSelf();
  }

  /// Background/pull-to-refresh reload — see BookingsNotifier.refresh() for
  /// why invalidateSelf() is used instead of a manual AsyncLoading reset.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // Swallowed — a background failure keeps the previous list visible.
    }
  }
}

final workerJobsProvider =
    AsyncNotifierProvider<WorkerJobsNotifier, List<BookingEntity>>(
      WorkerJobsNotifier.new,
    );

// ── Single job detail ─────────────────────────────────────────────────────────

/// True while [workerJobDetailProvider] for a given job id is showing the
/// last cached detail because the live fetch failed.
final workerJobDetailIsOfflineProvider = StateProvider.family<bool, String>(
  (ref, jobId) => false,
);

final workerJobDetailProvider = FutureProvider.family<BookingEntity, String>((
  ref,
  jobId,
) async {
  debugPrint('[workerJobDetailProvider] fetching job detail for jobId=$jobId');
  final result = await ref
      .read(workerRepositoryProvider)
      .getWorkerJobById(jobId);
  return result.fold(
    (f) {
      debugPrint(
        '[workerJobDetailProvider] failed for jobId=$jobId error=${f.message}',
      );
      throw f;
    },
    (cached) {
      ref.read(workerJobDetailIsOfflineProvider(jobId).notifier).state =
          cached.isStale;
      final job = cached.data;
      debugPrint(
        '[workerJobDetailProvider] success jobId=$jobId status=${job.status}',
      );
      return job;
    },
  );
});

// ── Complete job action ───────────────────────────────────────────────────────

class CompleteJobNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> complete(String jobId) async {
    state = const AsyncLoading();
    final result = await ref
        .read(workerRepositoryProvider)
        .completeWorkerJob(jobId);
    result.fold((failure) => state = AsyncError(failure, StackTrace.current), (
      _,
    ) {
      state = const AsyncData(null);
      // Refresh list and detail so UI reflects COMPLETED immediately.
      ref.invalidate(workerJobsProvider);
      ref.invalidate(workerJobDetailProvider(jobId));
      // Worker profile stats (completedJobs count) may have changed.
      ref.invalidate(workerProfileProvider);
    });
  }
}

final completeJobProvider = AsyncNotifierProvider<CompleteJobNotifier, void>(
  CompleteJobNotifier.new,
);

// ── "Kam paisa mila" — report the cash actually received ─────────────────────

/// Sends ONE fact (the received whole-rupee total) and holds the server's own
/// settlement breakdown. Every number in [WorkerPaymentReportEntity] is
/// `settleBooking`'s — the shortfall, the 18% labour commission and the munafa
/// are never derived on the device.
class ReportReceivedPaymentNotifier
    extends AsyncNotifier<WorkerPaymentReportEntity?> {
  @override
  Future<WorkerPaymentReportEntity?> build() async => null;

  /// Returns `null` on success, or the [Failure] to show. Deliberately hands
  /// the failure back rather than parking it in provider state for the caller
  /// to fish out: the sheet needs THIS attempt's error, and re-reading a
  /// provider nothing is listening to is not a reliable way to get it.
  Future<Failure?> report(String jobId, int receivedCashTotal) async {
    if (state.isLoading) {
      return const ValidationFailure('');
    }
    state = const AsyncLoading();
    final result = await ref
        .read(workerRepositoryProvider)
        .reportReceivedPayment(jobId, receivedCashTotal);
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return failure;
      },
      (report) {
        state = AsyncData(report);
        // The job's own payment fields now come back populated from the
        // server, so re-read them rather than patching anything locally.
        ref.invalidate(workerJobDetailProvider(jobId));
        ref.invalidate(workerJobsProvider);
        return null;
      },
    );
  }
}

final reportReceivedPaymentProvider =
    AsyncNotifierProvider<
      ReportReceivedPaymentNotifier,
      WorkerPaymentReportEntity?
    >(ReportReceivedPaymentNotifier.new);

// ── New jobs feed ─────────────────────────────────────────────────────────────

enum NewJobFilter { all, myBids, notBidYet }

// Visible wording: newJobFilterLabel() in presentation/utils/worker_labels.dart.

/// True while [newJobsProvider] is showing the last cached list because the
/// live fetch failed.
final newJobsIsOfflineProvider = StateProvider<bool>((ref) => false);

/// Fetches PENDING bookings matching the worker's skills via GET /workers/jobs/new.
/// Auto-refreshes every 30 s while the provider is alive.
class NewJobsNotifier extends AsyncNotifier<List<NewJobEntity>> {
  NewJobFilter _filter = NewJobFilter.all;

  NewJobFilter get currentFilter => _filter;

  @override
  Future<List<NewJobEntity>> build() {
    final timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!state.isLoading) ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);
    return _fetch();
  }

  Future<List<NewJobEntity>> _fetch() async {
    final result = await ref.read(workerRepositoryProvider).getNewJobs();
    return result.fold((f) => throw f, (cached) {
      ref.read(newJobsIsOfflineProvider.notifier).state = cached.isStale;
      return _applyFilter(cached.data);
    });
  }

  List<NewJobEntity> _applyFilter(List<NewJobEntity> jobs) {
    return switch (_filter) {
      NewJobFilter.myBids => jobs.where((j) => j.hasMyBid).toList(),
      // Strictly Bidding-lane only — a reopened ("Find Other Ustaad")
      // Inspection job is bid-actionable (see isDirectAssignLane) but must
      // still never surface under this Standard/Inspection-excluding filter.
      NewJobFilter.notBidYet =>
        jobs
            .where((j) => j.lane == BookingLane.bidding && !j.hasMyBid)
            .toList(),
      NewJobFilter.all => jobs,
    };
  }

  void setFilter(NewJobFilter f) {
    _filter = f;
    // ref.invalidateSelf() re-runs build() (reading the new _filter) via
    // Riverpod's safe isRefreshing/copyWithPrevious path, so the list stays
    // visible instead of flashing to a skeleton while refetching.
    ref.invalidateSelf();
  }

  /// Background/pull-to-refresh reload — see BookingsNotifier.refresh() for
  /// why invalidateSelf() is used instead of a manual AsyncLoading reset.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // Swallowed — a background failure keeps the previous list visible.
    }
  }
}

final newJobsProvider =
    AsyncNotifierProvider<NewJobsNotifier, List<NewJobEntity>>(
      NewJobsNotifier.new,
    );
