import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/worker_review_entity.dart';
import '../providers/worker_review_providers.dart';

// ── Palette (matches existing worker UI) ─────────────────────────────────────
const _kOrange = Color(0xFFFF5F15);
const _kDark   = Color(0xFF1A1A1A);
const _kGray   = Color(0xFF6B7280);
const _kLight  = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);
const _kBg     = Color(0xFFF9FAFB);

class WorkerReviewsPage extends ConsumerWidget {
  const WorkerReviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(workerAllReviewsProvider);
    final summaryAsync = ref.watch(workerReviewSummaryProvider);

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
          'My Reviews',
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
      body: reviewsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorState(
          message: err.toString(),
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
                      error: (_, __) => const SizedBox.shrink(),
                      data: (summary) => _SummaryBanner(summary: summary),
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
  const _SummaryBanner({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Average rating
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary.averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: _kDark,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              _StarRow(rating: summary.averageRating.round()),
              const SizedBox(height: 4),
              Text(
                '${summary.totalReviews} ${summary.totalReviews == 1 ? 'review' : 'reviews'}',
                style: const TextStyle(fontSize: 12, color: _kGray),
              ),
            ],
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_rounded, color: _kOrange, size: 28),
                SizedBox(height: 6),
                Text(
                  'Reviews from clients for jobs you completed',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kGray,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual review card ────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final WorkerReviewEntity review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                style: const TextStyle(fontSize: 11, color: _kLight),
              ),
            ],
          ),

          // ── Comment ────────────────────────────────────────────────
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF374151),
                height: 1.5,
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // ── Footer: client + category ──────────────────────────────
          Row(
            children: [
              if (review.clientName != null &&
                  review.clientName!.isNotEmpty) ...[
                const Icon(Icons.person_outline_rounded,
                    size: 13, color: _kLight),
                const SizedBox(width: 4),
                Text(
                  review.clientName!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                    color: _kLight,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kOrange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    review.serviceCategory,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _kOrange,
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
    );
  }
}

// ── Shared star row ───────────────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  final int rating;
  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: i < rating ? const Color(0xFFF59E0B) : const Color(0xFFD1D5DB),
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
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.star_outline_rounded,
                size: 36,
                color: Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No reviews yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Once clients review your completed jobs,\ntheir reviews will appear here.',
              style: TextStyle(
                fontSize: 13,
                color: _kGray,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: _kGray, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
