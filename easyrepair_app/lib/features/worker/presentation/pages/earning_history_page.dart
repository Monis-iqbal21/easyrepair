import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_utils.dart';
import '../../domain/entities/earning_history_entity.dart';
import '../providers/earning_history_providers.dart';

// ── Palette (matches existing worker UI) ─────────────────────────────────────
const _kOrange = Color(0xFFDB6234);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);
const _kLight = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);
const _kBg = Color(0xFFF9FAFB);
const _kGreen = Color(0xFF22C55E);

String _laneLabel(EarningHistoryJobEntity job) {
  if (job.isInspectionOnly) return 'Inspection Fee';
  switch (job.lane) {
    case 'STANDARD':
      return 'Standard';
    case 'INSPECTION':
      return 'Inspection';
    case 'BIDDING':
      return 'Bidding';
    default:
      return job.lane;
  }
}

Color _laneColor(EarningHistoryJobEntity job) {
  if (job.isInspectionOnly) return const Color(0xFFB45309);
  switch (job.lane) {
    case 'STANDARD':
      return _kOrange;
    case 'INSPECTION':
      return const Color(0xFFB45309);
    case 'BIDDING':
      return _kGreen;
    default:
      return _kGray;
  }
}

class EarningHistoryPage extends ConsumerWidget {
  const EarningHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(workerEarningsHistoryProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: _kDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Earning History',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _kDark,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder),
        ),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _kOrange)),
        error: (err, _) => _ErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(workerEarningsHistoryProvider),
        ),
        data: (days) => days.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                itemCount: days.length,
                itemBuilder: (ctx, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _DayCard(day: days[i]),
                ),
              ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final EarningHistoryDayEntity day;
  const _DayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, d MMMM').format(day.date),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${day.jobsCount} ${day.jobsCount == 1 ? 'job' : 'jobs'} completed',
                        style: const TextStyle(fontSize: 12, color: _kGray),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatPkr(day.grossTotal),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kGreen,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          for (final job in day.jobs) _JobRow(job: job),
        ],
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  final EarningHistoryJobEntity job;
  const _JobRow({required this.job});

  @override
  Widget build(BuildContext context) {
    final color = _laneColor(job);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _laneLabel(job),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              job.serviceCategory,
              style: const TextStyle(fontSize: 12.5, color: _kDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            formatPkr(job.grossEarning),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.savings_outlined, size: 48, color: _kLight),
            const SizedBox(height: 12),
            const Text(
              'No earnings yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Completed jobs will show up here with your daily earnings.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: _kGray),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: _kGray),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kGray, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: _kOrange,
                side: const BorderSide(color: _kOrange),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
