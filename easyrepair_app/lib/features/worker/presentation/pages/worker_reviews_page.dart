import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/worker_review_entity.dart';
import '../providers/worker_review_providers.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';

// Every colour on this screen now comes from `context.semanticColors`. The six
// `_k*` constants that used to sit here — including EasyRepair's orange
// `#DB6234`, which is not in the Ustaad prototype at all — are gone, and so are
// the two `BoxShadow`s: a card in this design is `surface` + radius 16 + a 1px
// hairline, nothing else.

// Shared shape values, matching Home and New Jobs.
const double _rCard = 16;
const double _rPill = 999;

class WorkerReviewsPage extends ConsumerWidget {
  const WorkerReviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(workerAllReviewsProvider);
    final summaryAsync = ref.watch(workerReviewSummaryProvider);
    final c = context.semanticColors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        surfaceTintColor: c.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: c.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.l10n.reviewsMyReviews,
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
      body: reviewsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: c.primary),
        ),
        error: (err, _) => _ErrorState(
          message: failureMessage(context.l10n, err),
          onRetry: () => ref.invalidate(workerAllReviewsProvider),
        ),
        data: (reviews) => reviews.isEmpty
            ? const _EmptyState()
            : CustomScrollView(
                slivers: [
                  // ── Summary banner ─────────────────────────────────────
                  SliverToBoxAdapter(
                    child: summaryAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (err, st) => const SizedBox.shrink(),
                      data: (summary) => _SummaryBanner(
                        summary: summary,
                        reviews: reviews,
                      ),
                    ),
                  ),

                  // ── Review list ────────────────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _ReviewCard(review: reviews[i]),
                        childCount: reviews.length,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Summary banner ────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final WorkerReviewSummaryEntity summary;
  final List<WorkerReviewEntity> reviews;
  const _SummaryBanner({required this.summary, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;

    // Replaces the old Avg / Max / Min row. "Max 5, Min 5" said nothing: with
    // two reviews it is noise, and with two hundred it only reports that
    // somebody once gave five and somebody once gave one. A count per star is
    // the shape of the reputation, which is what an Ustaad actually reads.
    //
    // Counted from the list this page already has — exactly the same source the
    // old Max/Min used, so this is no less trustworthy than what it replaces.
    // The request sends no `limit`, but whether the backend applies one of its
    // own is UNKNOWN, so `summary.totalReviews` stays the number of record and
    // the bars are only ever drawn relative to each other.
    final counts = List<int>.filled(5, 0);
    for (final r in reviews) {
      // clamped because a malformed row must never throw a RangeError on a
      // screen whose whole job is to display what the backend sent.
      final i = (r.rating < 1 ? 1 : (r.rating > 5 ? 5 : r.rating)) - 1;
      counts[i] = counts[i] + 1;
    }
    final busiest = counts.reduce((a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Average rating
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.averageRating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StarRow(rating: summary.averageRating.round()),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.reviewsCount(summary.totalReviews),
                    style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_rounded, color: c.primary, size: 28),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.reviewsSubtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: c.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (reviews.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: c.border),
            const SizedBox(height: 12),
            // 5 at the top, 1 at the bottom — the order everyone reads a
            // rating breakdown in.
            for (var star = 5; star >= 1; star--) ...[
              _StarBreakdownRow(
                star: star,
                count: counts[star - 1],
                busiest: busiest,
              ),
              if (star > 1) const SizedBox(height: 6),
            ],
          ],
        ],
      ),
    );
  }
}

/// One row of the breakdown: `5 ★ ▓▓▓▓▓░░░░░ 2`.
///
/// The bar is drawn relative to the busiest star, not to the total, so a
/// perfect record still fills its row instead of showing five stubs.
class _StarBreakdownRow extends StatelessWidget {
  final int star;
  final int count;
  final int busiest;

  const _StarBreakdownRow({
    required this.star,
    required this.count,
    required this.busiest,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final fraction = busiest == 0 ? 0.0 : count / busiest;

    return Row(
      children: [
        SizedBox(
          width: 14,
          child: Text(
            '$star',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.star_rounded, size: 13, color: c.warning),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_rPill),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 7,
              backgroundColor: c.surfaceSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(c.primary),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 22,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: count == 0 ? c.textSecondary : c.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Individual review card ────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final WorkerReviewEntity review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return GestureDetector(
      // Unchanged: the card still opens the booking it belongs to, and still
      // only when there is a booking id to open.
      onTap: review.bookingId != null
          ? () => context.push('/worker/job/${review.bookingId}')
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(_rCard),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top: stars + date ──────────────────────────────────────
            Row(
              children: [
                _StarRow(rating: review.rating),
                const Spacer(),
                Text(
                  DateFormat('MMM d, yyyy').format(review.createdAt),
                  style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                ),
              ],
            ),

            // ── Comment ────────────────────────────────────────────────
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                review.comment!,
                style: TextStyle(
                  fontSize: 14,
                  color: c.textPrimary,
                  height: 1.5,
                ),
              ),
            ],

            const SizedBox(height: 12),
            Container(height: 1, color: c.border),
            const SizedBox(height: 10),

            // ── Footer: client + category ──────────────────────────────
            Row(
              children: [
                if (review.clientName != null &&
                    review.clientName!.isNotEmpty) ...[
                  Icon(Icons.person_outline_rounded,
                      size: 14, color: c.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    review.clientName!,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: c.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: c.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.softTeal,
                      borderRadius: BorderRadius.circular(_rPill),
                    ),
                    child: Text(
                      review.serviceCategory,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: c.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared star row ───────────────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  final int rating;
  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: i < rating ? c.warning : c.border,
        );
      }),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.softTeal,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.star_outline_rounded,
                size: 36,
                color: c.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.workerNoReviewsYet,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.reviewsEmptyHint,
              style: TextStyle(
                fontSize: 14,
                color: c.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: c.textSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: c.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // No colours here: AppTheme's ElevatedButton theme already resolves
            // background and foreground from the same palette.
            ElevatedButton(
              onPressed: onRetry,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
