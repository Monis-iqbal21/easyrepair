import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/worker_review_entity.dart';
import '../../data/repositories/worker_repository_impl.dart';

/// 2 most recent reviews — used by the home page dashboard section.
final workerRecentReviewsProvider =
    FutureProvider<List<WorkerReviewEntity>>((ref) async {
  final result =
      await ref.read(workerRepositoryProvider).getWorkerReviews(limit: 2);
  return result.fold((f) => throw f, (r) => r);
});

/// All reviews — used by the full reviews page.
final workerAllReviewsProvider =
    FutureProvider<List<WorkerReviewEntity>>((ref) async {
  final result = await ref.read(workerRepositoryProvider).getWorkerReviews();
  return result.fold((f) => throw f, (r) => r);
});

/// Aggregate summary — used by the full reviews page header.
final workerReviewSummaryProvider =
    FutureProvider<WorkerReviewSummaryEntity>((ref) async {
  final result =
      await ref.read(workerRepositoryProvider).getWorkerReviewSummary();
  return result.fold((f) => throw f, (r) => r);
});
