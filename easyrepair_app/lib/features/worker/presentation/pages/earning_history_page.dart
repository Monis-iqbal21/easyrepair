import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/network/offline_banner.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../domain/entities/earning_history_entity.dart';
import '../providers/earning_history_providers.dart';
import '../../../../core/l10n/l10n_extensions.dart';

// ── Palette (matches existing worker UI) ─────────────────────────────────────
const _kOrange = Color(0xFFDB6234);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);
const _kLight = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);
const _kBg = Color(0xFFF9FAFB);
const _kGreen = Color(0xFF22C55E);
const _kPendingBg = Color(0xFFFFF7ED);
const _kPendingText = Color(0xFFB45309);
const _kPaidBg = Color(0xFFF0FDF4);

String _laneLabel(BuildContext context, EarningHistoryJobEntity job) {
  if (job.isInspectionOnly) return context.l10n.postJobInspectionFeeTitle;
  switch (job.lane) {
    case 'STANDARD':
      return context.l10n.workerLevelStandard;
    case 'INSPECTION':
      return context.l10n.inspectionBadge;
    case 'BIDDING':
      return context.l10n.earningBidding;
    default:
      return job.lane;
  }
}

Color _laneColor(EarningHistoryJobEntity job) {
  if (job.isInspectionOnly) return _kPendingText;
  switch (job.lane) {
    case 'STANDARD':
      return _kOrange;
    case 'INSPECTION':
      return _kPendingText;
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
    final isShowingCachedData = ref.watch(workerEarningsHistoryIsOfflineProvider) &&
        historyAsync.hasValue;

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
        title: Text(
          context.l10n.earningHistoryTitle,
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
      body: Column(
        children: [
          if (isShowingCachedData) const OfflineDataBanner(),
          Expanded(
            child: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _kOrange)),
        error: (err, _) => _ErrorState(
          message: failureMessage(context.l10n, err),
          onRetry: () => ref.invalidate(workerEarningsHistoryProvider),
        ),
        data: (days) => days.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                // +1 for the totals header, rendered as the first item so it
                // scrolls with the list rather than needing a separate Column.
                itemCount: days.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _TotalsHeader(days: days),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _DayCard(day: days[i - 1]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Page-wide Gross / HandyGo Commission (18%) / Ustaad Earnings, summed from
/// the backend-computed per-job figures already delivered with each day —
/// never re-derives the 18% rate here, only adds up numbers the backend
/// already calculated (see commission.util.ts, the one shared source).
class _TotalsHeader extends StatelessWidget {
  final List<EarningHistoryDayEntity> days;
  const _TotalsHeader({required this.days});

  @override
  Widget build(BuildContext context) {
    var gross = 0.0;
    var commission = 0.0;
    var ustaad = 0.0;
    for (final day in days) {
      for (final job in day.jobs) {
        gross += job.grossEarning;
        commission += job.commissionAmount;
        ustaad += job.ustaadEarning;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TotalRow(
            label: context.l10n.earningGrossEarnings,
            amount: gross,
            color: _kDark,
            emphasize: true,
          ),
          const SizedBox(height: 10),
          _TotalRow(
            label: context.l10n.earningCommissionLabel,
            amount: commission,
            color: _kGray,
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _kBorder),
          const SizedBox(height: 10),
          _TotalRow(
            label: context.l10n.earningUstaadEarnings,
            amount: ustaad,
            color: _kGreen,
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool emphasize;
  const _TotalRow({
    required this.label,
    required this.amount,
    required this.color,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: emphasize ? _kDark : _kGray,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          formatPkr(amount),
          style: TextStyle(
            fontSize: emphasize ? 16 : 13.5,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
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
                        context.l10n.earningJobsCompleted(day.jobsCount),
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
          for (final job in day.jobs) _JobCard(job: job),
        ],
      ),
    );
  }
}

/// One completed job's full breakdown: lane + category + date on top, then
/// Gross / HandyGo Commission (18%) / Ustaad Earning, and the job's own
/// commission status chip — independent of every other job's status.
class _JobCard extends StatelessWidget {
  final EarningHistoryJobEntity job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final color = _laneColor(job);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorder, width: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _laneLabel(context, job),
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
              _CommissionStatusChip(status: job.commissionStatus),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AmountColumn(
                  label: context.l10n.earningGrossEarnings,
                  amount: job.grossEarning,
                  color: _kDark,
                ),
              ),
              Expanded(
                child: _AmountColumn(
                  label: context.l10n.earningCommissionLabel,
                  amount: job.commissionAmount,
                  color: _kGray,
                ),
              ),
              Expanded(
                child: _AmountColumn(
                  label: context.l10n.earningUstaadEarnings,
                  amount: job.ustaadEarning,
                  color: _kGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountColumn extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _AmountColumn({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: _kLight),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          formatPkr(amount),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CommissionStatusChip extends StatelessWidget {
  final CommissionStatus status;
  const _CommissionStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPaid = status == CommissionStatus.paid;
    final bg = isPaid ? _kPaidBg : _kPendingBg;
    final text = isPaid ? _kGreen : _kPendingText;
    final label =
        // Reuses bidStatusPending — the app-wide "Pending" copy already used
        // for bid status; ARB parity guards against a second key carrying
        // identical English text (see test/core/l10n/arb_parity_test.dart).
        isPaid ? context.l10n.earningStatusPaid : context.l10n.bidStatusPending;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: text, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: text,
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
            Text(
              context.l10n.earningNoneYet,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.earningNoneHint,
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
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
