import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bookings/domain/entities/booking_entity.dart';
import '../../data/repositories/worker_repository_impl.dart';
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
  Future<List<BookingEntity>> build() => _fetch();

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
  final result =
      await ref.read(workerRepositoryProvider).getWorkerJobById(jobId);
  return result.fold((f) => throw f, (job) => job);
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
