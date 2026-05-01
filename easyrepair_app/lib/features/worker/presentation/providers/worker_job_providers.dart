import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bookings/domain/entities/booking_entity.dart';
import '../../data/repositories/worker_repository_impl.dart';
import '../../domain/entities/new_job_entity.dart';
import 'worker_providers.dart'; // for workerProfileProvider

// ── Filter ────────────────────────────────────────────────────────────────────

enum WorkerJobFilter { all, active, completed, cancelled }

extension WorkerJobFilterX on WorkerJobFilter {
  String get label => switch (this) {
        WorkerJobFilter.all => 'All',
        WorkerJobFilter.active => 'Active',
        WorkerJobFilter.completed => 'Completed',
        WorkerJobFilter.cancelled => 'Cancelled',
      };

  String? get apiValue => switch (this) {
        WorkerJobFilter.all => null,
        WorkerJobFilter.active => 'active',
        WorkerJobFilter.completed => 'completed',
        WorkerJobFilter.cancelled => 'cancelled',
      };
}

// ── Jobs list notifier ────────────────────────────────────────────────────────

class WorkerJobsNotifier extends AsyncNotifier<List<BookingEntity>> {
  WorkerJobFilter _filter = WorkerJobFilter.all;

  WorkerJobFilter get currentFilter => _filter;

  @override
  Future<List<BookingEntity>> build() {
    final timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state is! AsyncLoading) _reload();
    });
    ref.onDispose(timer.cancel);
    return _fetch();
  }

  Future<List<BookingEntity>> _fetch() async {
    final result = await ref
        .read(workerRepositoryProvider)
        .getWorkerJobs(_filter.apiValue);
    return result.fold((f) => throw f, (jobs) => jobs);
  }

  void setFilter(WorkerJobFilter newFilter) {
    if (_filter == newFilter) return;
    _filter = newFilter;
    state = const AsyncLoading();
    _reload();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> _reload() async {
    state = await AsyncValue.guard(_fetch);
  }
}

final workerJobsProvider =
    AsyncNotifierProvider<WorkerJobsNotifier, List<BookingEntity>>(
  WorkerJobsNotifier.new,
);

// ── Single job detail ─────────────────────────────────────────────────────────

final workerJobDetailProvider =
    FutureProvider.family<BookingEntity, String>((ref, jobId) async {
  debugPrint('[workerJobDetailProvider] fetching job detail for jobId=$jobId');
  final result =
      await ref.read(workerRepositoryProvider).getWorkerJobById(jobId);
  return result.fold(
    (f) {
      debugPrint('[workerJobDetailProvider] failed for jobId=$jobId error=${f.message}');
      throw f;
    },
    (job) {
      debugPrint('[workerJobDetailProvider] success jobId=$jobId status=${job.status}');
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
    final result =
        await ref.read(workerRepositoryProvider).completeWorkerJob(jobId);
    result.fold(
      (failure) => state = AsyncError(failure, StackTrace.current),
      (_) {
        state = const AsyncData(null);
        // Refresh list and detail so UI reflects COMPLETED immediately.
        ref.invalidate(workerJobsProvider);
        ref.invalidate(workerJobDetailProvider(jobId));
        // Worker profile stats (completedJobs count) may have changed.
        ref.invalidate(workerProfileProvider);
      },
    );
  }
}

final completeJobProvider =
    AsyncNotifierProvider<CompleteJobNotifier, void>(CompleteJobNotifier.new);

// ── New jobs feed ─────────────────────────────────────────────────────────────

enum NewJobFilter { all, myBids, notBidYet }

extension NewJobFilterX on NewJobFilter {
  String get label => switch (this) {
        NewJobFilter.all => 'All Jobs',
        NewJobFilter.myBids => 'My Bid Offers',
        NewJobFilter.notBidYet => 'Not Bid Yet',
      };
}

/// Fetches PENDING bookings matching the worker's skills via GET /workers/jobs/new.
/// Auto-refreshes every 30 s while the provider is alive.
class NewJobsNotifier extends AsyncNotifier<List<NewJobEntity>> {
  NewJobFilter _filter = NewJobFilter.all;

  NewJobFilter get currentFilter => _filter;

  @override
  Future<List<NewJobEntity>> build() {
    final timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state is! AsyncLoading) _reload();
    });
    ref.onDispose(timer.cancel);
    return _fetch();
  }

  Future<List<NewJobEntity>> _fetch() async {
    final result = await ref.read(workerRepositoryProvider).getNewJobs();
    return result.fold((f) => throw f, (jobs) => _applyFilter(jobs));
  }

  List<NewJobEntity> _applyFilter(List<NewJobEntity> jobs) {
    return switch (_filter) {
      NewJobFilter.myBids => jobs.where((j) => j.hasMyBid).toList(),
      NewJobFilter.notBidYet => jobs.where((j) => !j.hasMyBid).toList(),
      NewJobFilter.all => jobs,
    };
  }

  void setFilter(NewJobFilter f) {
    _filter = f;
    // Re-apply filter to current data without re-fetching.
    final current = state.valueOrNull;
    if (current != null) {
      // Re-fetch so we have the full unfiltered list to filter from.
      state = const AsyncLoading();
      _reload();
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> _reload() async {
    state = await AsyncValue.guard(_fetch);
  }
}

final newJobsProvider =
    AsyncNotifierProvider<NewJobsNotifier, List<NewJobEntity>>(
  NewJobsNotifier.new,
);
