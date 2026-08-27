import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/l10n/l10n_extensions.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../domain/entities/booking_entity.dart';
import '../../providers/review_prompt_controller.dart';
import 'booking_detail_primitives.dart';

/// "This job is done" — shown the moment the backend says COMPLETED.
///
/// Deliberately independent of whether a review exists, whether a complaint
/// exists, whether cash was confirmed, and whether the client has been away
/// and come back. Completion is a booking lifecycle fact; review, report and
/// payment are separate things that happen after it.
class BookingClosedBanner extends StatelessWidget {
  const BookingClosedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BookingStateBanner(
      key: const Key('job-closed-banner'),
      icon: Icons.verified_rounded,
      title: context.l10n.bookingJobClosedTitle,
      body: context.l10n.bookingJobClosedBody,
      tone: BookingBannerTone.positive,
    );
  }
}

/// "Review Ustaad" CTA.
///
/// Visible exactly when `BookingsService.submitReview` would accept it —
/// COMPLETED, no review yet, an Ustaad to review — and never gated on a cash
/// confirmation held in this page's session. A client who confirmed cash
/// yesterday and reopened the app can still leave their review.
class BookingReviewAction extends ConsumerWidget {
  final BookingEntity booking;

  const BookingReviewAction({super.key, required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!booking.canClientReview) return const SizedBox.shrink();
    return BookingSecondaryButton(
      key: const Key('review-worker-button'),
      label: context.l10n.bookingReviewWorker,
      icon: Icons.star_outline_rounded,
      onPressed: () => ref
          .read(reviewPromptControllerProvider)
          .enqueueFront(context, booking.id),
    );
  }
}

/// The review once it exists — stars, the client's own words, and when.
class BookingSubmittedReviewCard extends StatelessWidget {
  final BookingReviewEntity review;

  const BookingSubmittedReviewCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final comment = review.comment?.trim();

    return BookingDetailCard(
      key: const Key('submitted-review-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingSectionHeading(
            label: context.l10n.bookingYourReview,
            icon: Icons.star_rounded,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Icon(
                  i < review.rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 22,
                  color: i < review.rating ? colors.warning : colors.border,
                ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              comment,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            DateFormat('d MMM yyyy').format(review.createdAt),
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
