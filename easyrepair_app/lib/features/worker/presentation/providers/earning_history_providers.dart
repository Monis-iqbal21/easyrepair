import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/earning_history_entity.dart';
import '../../data/repositories/worker_repository_impl.dart';

/// True while [workerEarningsHistoryProvider] is showing the last cached
/// history because the live fetch failed.
final workerEarningsHistoryIsOfflineProvider = StateProvider<bool>((ref) => false);

/// All-time completed-job earnings grouped by date — used by the Earning
/// History page. Gross (pre-commission) amounts, same source as the worker
/// home dashboard's "Today's Earnings" tile.
final workerEarningsHistoryProvider =
    FutureProvider<List<EarningHistoryDayEntity>>((ref) async {
  final result = await ref.read(workerRepositoryProvider).getEarningsHistory();
  return result.fold((f) => throw f, (cached) {
    ref.read(workerEarningsHistoryIsOfflineProvider.notifier).state =
        cached.isStale;
    return cached.data;
  });
});
