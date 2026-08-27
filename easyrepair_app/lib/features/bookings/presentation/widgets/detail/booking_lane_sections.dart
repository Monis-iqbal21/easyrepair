import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n_extensions.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../../../core/utils/currency_utils.dart';
import '../../../domain/entities/booking_entity.dart';
import '../../utils/booking_labels.dart';
import 'booking_detail_primitives.dart';
import 'booking_detail_summary.dart';

/// Lane-specific "what was booked" section, sitting under the shared summary.
///
/// Each lane answers the same question differently — STANDARD lists catalog
/// items, INSPECTION and BIDDING describe a problem in the client's own
/// words — so this is the one place the three genuinely diverge. Everything
/// they share (reference, status, schedule, price) already lives in
/// [BookingDetailSummary] and is deliberately not repeated here.
class BookingLaneSection extends StatelessWidget {
  final BookingEntity booking;

  const BookingLaneSection({super.key, required this.booking});

  /// Whether this section has anything to say — so the page can leave it out
  /// entirely rather than reserving space for an empty card. An INSPECTION
  /// booking whose title is just the category and which carries no typed
  /// description has nothing here the summary has not already shown.
  static bool hasContentFor(BookingEntity booking) {
    if (booking.lane == BookingLane.standard) return true;
    final issue = booking.displayIssueTitle?.trim();
    final description = booking.cleanDescription?.trim();
    return (issue != null && issue.isNotEmpty) ||
        (description != null && description.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return switch (booking.lane) {
      BookingLane.standard => _StandardSection(booking: booking),
      BookingLane.inspection => _ProblemSection(booking: booking),
      BookingLane.bidding => _ProblemSection(booking: booking),
    };
  }
}

/// Selected catalog services with their per-line prices and ONE total.
///
/// The total reads [BookingEntity.canonicalPrice] — the same getter the
/// summary and the Bookings card read — so the page can never show two
/// different Standard totals under two different precedence rules.
class _StandardSection extends StatelessWidget {
  final BookingEntity booking;

  const _StandardSection({required this.booking});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final l10n = context.l10n;
    final items = booking.standardServiceItems;
    final total = booking.canonicalPrice;
    final description = booking.cleanDescription;

    // No item snapshots (legacy row): fall back to the plain service label
    // rather than rendering an empty card.
    if (items.isEmpty) {
      return BookingDetailCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookingSectionHeading(label: l10n.bookingSelectedServices),
            const SizedBox(height: 12),
            Text(
              booking.primaryServiceLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return BookingDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingSectionHeading(label: l10n.bookingSelectedServices),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: BookingAmountRow(
                label: item.quantity > 1
                    ? l10n.bookingServiceQuantity(
                        item.nameSnapshot,
                        item.quantity,
                      )
                    : item.nameSnapshot,
                amount: formatPkr(item.lineTotal),
              ),
            ),
          if (total != null) ...[
            const SizedBox(height: 2),
            Divider(height: 1, color: colors.divider),
            const SizedBox(height: 12),
            BookingAmountRow(
              label: l10n.postJobTotal,
              amount: formatPkr(total),
              emphasised: true,
            ),
          ],
          if (description != null && description.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: colors.divider),
            const SizedBox(height: 14),
            BookingDetailRow(
              icon: Icons.notes_rounded,
              label: l10n.postJobDescription,
              value: description,
            ),
          ],
        ],
      ),
    );
  }
}

/// INSPECTION and BIDDING both describe a problem the client wrote in their
/// own words, so they share one section. The lane itself is already named in
/// the summary; nothing here restates it.
class _ProblemSection extends StatelessWidget {
  final BookingEntity booking;

  const _ProblemSection({required this.booking});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final l10n = context.l10n;
    final issue = booking.displayIssueTitle;
    final description = booking.cleanDescription;

    // Everything worth showing is empty (an INSPECTION booking whose title is
    // just the category, with no typed description) — the summary already
    // named the category, so render nothing rather than an empty card.
    if ((issue == null || issue.trim().isEmpty) &&
        (description == null || description.trim().isEmpty)) {
      return const SizedBox.shrink();
    }

    return BookingDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingSectionHeading(label: l10n.bookingIssue),
          const SizedBox(height: 12),
          if (issue != null && issue.trim().isNotEmpty)
            Text(
              issue,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: colors.textPrimary,
              ),
            ),
          if (issue != null &&
              issue.trim().isNotEmpty &&
              description != null &&
              description.trim().isNotEmpty)
            const SizedBox(height: 8),
          if (description != null && description.trim().isNotEmpty)
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: colors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// INSPECTION-only fee state ("Inspection fee paid" / "not paid").
///
/// Driven solely by [BookingEntity.inspectionFeePaid], which the backend
/// derives from the ORIGINAL inspection work unit reaching COMPLETED — so it
/// stays correct on the inspection booking AND on its linked repair booking,
/// including the window where nobody is assigned.
class BookingInspectionFeeChip extends StatelessWidget {
  final BookingEntity booking;

  const BookingInspectionFeeChip({super.key, required this.booking});

  /// Null `inspectionFeePaid` means no inspection is involved at all.
  static bool hasContentFor(BookingEntity booking) =>
      booking.inspectionFeePaid != null;

  @override
  Widget build(BuildContext context) {
    final label = inspectionFeeStatusLabel(
      context.l10n,
      booking.inspectionFeePaid,
    );
    if (label == null) return const SizedBox.shrink();

    final paid = booking.inspectionFeePaid == true;
    return BookingStateBanner(
      icon: paid ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
      title: label,
      tone: paid ? BookingBannerTone.positive : BookingBannerTone.attention,
    );
  }
}
