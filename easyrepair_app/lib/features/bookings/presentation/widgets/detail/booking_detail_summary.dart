import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n_extensions.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../../../core/utils/currency_utils.dart';
import '../../../domain/entities/booking_entity.dart';
import '../../utils/booking_labels.dart';
import '../status_badge.dart';
import '../urgency_badge.dart';
import 'booking_detail_primitives.dart';

/// Placeholder shown wherever a booking legitimately has no price yet — an
/// open BIDDING job nobody has been hired for. Never "Rs 0", never an
/// estimate: HandyGo has no estimated-price concept.
const kBookingNoPriceYet = '—';

/// The single top-of-page summary: what was booked, where it stands, when it
/// is happening and what it costs.
///
/// Every value here is read from an authoritative shared source, so this card
/// and the Bookings tab card can never tell different stories:
///   * status wording   → [StatusBadge] with the card's own configuration
///   * lane wording     → [bookingLaneLabel]
///   * schedule         → [bookingScheduleLabel]
///   * price            → [BookingEntity.displayPrice] / `canonicalPrice`
class BookingDetailSummary extends StatelessWidget {
  final BookingEntity booking;

  const BookingDetailSummary({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final l10n = context.l10n;

    // Identical to the Bookings card's rule, so an inspection awaiting the
    // client's decision reads "Waiting for quote" on both surfaces.
    final waitingForQuote =
        booking.lane == BookingLane.inspection &&
        booking.inspectionReportSubmitted &&
        booking.inspectionDecisionStatus ==
            InspectionDecisionStatus.pendingClientDecision;

    final schedule = bookingScheduleLabel(l10n, booking);
    final (priceLabel, priceAmount) = booking.displayPrice;

    return BookingDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.referenceId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                bookingLaneLabel(l10n, booking.lane),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            booking.serviceCategory,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                status: booking.status,
                detailedClientWording: true,
                waitingForQuote: waitingForQuote,
              ),
              UrgencyBadge(urgency: booking.urgency),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: colors.divider),
          const SizedBox(height: 14),
          // ONE schedule block — never Timing + Time Window + Scheduled Date
          // as three rows saying the same thing.
          BookingDetailRow(
            icon: Icons.event_rounded,
            label: l10n.bookingSchedule,
            value: schedule ?? l10n.bookingNotScheduledYet,
          ),
          const SizedBox(height: 12),
          // ONE price — the canonical amount with the canonical wording. A
          // BIDDING job with no accepted bid shows a dash, never Rs 0.
          BookingDetailRow(
            icon: Icons.payments_rounded,
            label: priceAmount == null
                ? l10n.bookingPrice
                : _priceLabelText(context, priceLabel),
            value: priceAmount == null
                ? kBookingNoPriceYet
                : formatPkr(priceAmount),
          ),
        ],
      ),
    );
  }

  String _priceLabelText(BuildContext context, DisplayPriceLabel label) =>
      switch (label) {
        DisplayPriceLabel.agreed => context.l10n.bookingAgreedPrice,
        DisplayPriceLabel.finalPrice => context.l10n.bookingFinalPrice,
        DisplayPriceLabel.inspectionFee =>
          context.l10n.postJobInspectionFeeTitle,
      };
}
