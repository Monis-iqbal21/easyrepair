import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/earning_history_entity.dart';
import '../../data/repositories/worker_repository_impl.dart';

/// All-time completed-job earnings grouped by date — used by the Earning
/// History page. Gross (pre-commission) amounts, same source as the worker
/// home dashboard's "Today's Earnings" tile.
final workerEarningsHistoryProvider =
    FutureProvider<List<EarningHistoryDayEntity>>((ref) async {
  final result = await ref.read(workerRepositoryProvider).getEarningsHistory();
  return result.fold((f) => throw f, (r) => r);
});
