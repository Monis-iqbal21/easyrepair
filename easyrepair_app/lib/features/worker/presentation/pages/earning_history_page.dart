import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/network/offline_banner.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../domain/entities/earning_history_entity.dart';
import '../providers/earning_history_providers.dart';
import '../../../../core/l10n/l10n_extensions.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
//
// There isn't one. Every colour comes from `context.semanticColors`.
//
// What used to live here, and what each became:
//
//   _kOrange      #DB6234 -> c.primary          EasyRepair's orange, not in the
//                                               Ustaad prototype at all.
//   _kDark        #1A1A1A -> c.textPrimary
//   _kGray        #6B7280 -> c.textSecondary
//   _kLight       #94A3B8 -> c.textSecondary    two greys in the palette, not three.
//   _kBorder      #E2E8F0 -> c.border
//   _kBg          #F9FAFB -> c.background
//   _kGreen       #22C55E -> c.success
//   _kPendingBg   #FFF7ED -> c.warningSurface
//   _kPendingText #B45309 -> c.warning
//   _kPaidBg      #F0FDF4 -> c.successSoft

const double _rCard = 16;   // prototype `.crd`
const double _rPill = 999;  // prototype `.tg`

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

/// Background and text for the lane chip, as a pair.
///
/// It used to return one colour and the chip painted its own background with
/// `color.withValues(alpha: 0.1)`. Deriving a colour is not allowed — it comes
/// from the palette or it does not exist — so each lane now names both halves.
(Color bg, Color fg) _laneColors(AppSemanticColors c, EarningHistoryJobEntity job) {
  if (job.isInspectionOnly) return (c.warningSurface, c.warning);
  return switch (job.lane) {
    'STANDARD' => (c.softTeal, c.primary),
    'INSPECTION' => (c.warningSurface, c.warning),
    'BIDDING' => (c.successSoft, c.success),
    _ => (c.surfaceSubtle, c.textSecondary),
  };
}

class EarningHistoryPage extends ConsumerWidget {
  const EarningHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(workerEarningsHistoryProvider);
    final isShowingCachedData =
        ref.watch(workerEarningsHistoryIsOfflineProvider) &&
        historyAsync.hasValue;
    final c = context.semanticColors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        surfaceTintColor: c.surface,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: c.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.l10n.earningHistoryTitle,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.border),
        ),
      ),
      body: Column(
        children: [
          if (isShowingCachedData) const OfflineDataBanner(),
          Expanded(
            child: historyAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: c.primary),
              ),
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
    final c = context.semanticColors;
    var gross = 0.0;
    var commission = 0.0;
    var ustaad = 0.0;
    for (final day in days) {
      for (final job in day.jobs) {
        gross += job.grossEarning;
        if (job.commissionAmount != null) commission += job.commissionAmount!;
        if (job.ustaadEarning != null) ustaad += job.ustaadEarning!;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MoneyRow(
            label: context.l10n.earningGrossEarnings,
            amount: gross,
            color: c.textPrimary,
          ),
          const SizedBox(height: 10),
          _MoneyRow(
            label: context.l10n.earningCommissionLabel,
            amount: commission,
            color: c.textSecondary,
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: c.border),
          const SizedBox(height: 10),
          _MoneyRow(
            label: context.l10n.earningUstaadEarnings,
            amount: ustaad,
            color: c.success,
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

/// One label on the left, one amount on the right.
///
/// This is also what a job's own breakdown uses now. It used to be three
/// side-by-side columns, which gave each label a third of the screen — not
/// enough for "HandyGo Commission (18%)", which truncated on a real phone.
/// Stacked rows fit the words, and the amounts line up in one column where
/// they can actually be compared.
class _MoneyRow extends StatelessWidget {
  final String label;
  final double? amount;
  final Color color;
  final bool emphasize;
  const _MoneyRow({
    required this.label,
    required this.amount,
    required this.color,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: emphasize ? c.textPrimary : c.textSecondary,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          amount == null ? '—' : formatPkr(amount!),
          style: TextStyle(
            fontSize: emphasize ? 16 : 13.5,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
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
    final c = context.semanticColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: c.border),
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.l10n.earningJobsCompleted(day.jobsCount),
                        style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatPkr(day.grossTotal),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.success,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: c.border),
          for (final job in day.jobs) _JobCard(job: job),
        ],
      ),
    );
  }
}

/// One completed job's full breakdown: lane + category + status on top, then
/// Gross / HandyGo Commission (18%) / Ustaad Earning — the job's own commission
/// status chip is independent of every other job's status.
class _JobCard extends StatelessWidget {
  final EarningHistoryJobEntity job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final (laneBg, laneFg) = _laneColors(c, job);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border, width: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: laneBg,
                  borderRadius: BorderRadius.circular(_rPill),
                ),
                child: Text(
                  _laneLabel(context, job),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: laneFg,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  job.serviceCategory,
                  style: TextStyle(fontSize: 12.5, color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _CommissionStatusChip(status: job.commissionStatus),
            ],
          ),
          const SizedBox(height: 10),
          _MoneyRow(
            label: context.l10n.earningGrossEarnings,
            amount: job.grossEarning,
            color: c.textPrimary,
          ),
          const SizedBox(height: 6),
          _MoneyRow(
            label: context.l10n.earningCommissionLabel,
            amount: job.commissionAmount,
            color: c.textSecondary,
          ),
          const SizedBox(height: 6),
          _MoneyRow(
            label: context.l10n.earningUstaadEarnings,
            amount: job.ustaadEarning,
            color: c.success,
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _CommissionStatusChip extends StatelessWidget {
  final CommissionStatus status;
  const _CommissionStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final isPaid = status == CommissionStatus.paid;
    final bg = isPaid ? c.successSoft : c.warningSurface;
    final text = isPaid ? c.success : c.warning;
    final label =
        // Reuses bidStatusPending — the app-wide "Pending" copy already used
        // for bid status; ARB parity guards against a second key carrying
        // identical English text (see test/core/l10n/arb_parity_test.dart).
        isPaid ? context.l10n.earningStatusPaid : context.l10n.bidStatusPending;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: text, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
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
    final c = context.semanticColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.softTeal,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.savings_outlined, size: 36, color: c.primary),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.earningNoneYet,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.earningNoneHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5),
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
    final c = context.semanticColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: c.textSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            // No colours: AppTheme's OutlinedButton theme resolves them from
            // the same palette.
            OutlinedButton(
              onPressed: onRetry,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
