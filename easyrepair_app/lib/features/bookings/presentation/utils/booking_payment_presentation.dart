import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../domain/entities/booking_entity.dart';

/// How a payment line should read — the semantic weight of the message, not a
/// colour. Each surface maps a tone onto its own palette token so the wording
/// and the emphasis stay in lockstep without this file importing a theme.
enum BookingPaymentTone { positive, attention, neutral }

/// One payment line, ready to render.
class BookingPaymentPresentation {
  final IconData icon;
  final String label;
  final BookingPaymentTone tone;

  const BookingPaymentPresentation({
    required this.icon,
    required this.label,
    required this.tone,
  });

  /// [BookingPaymentTone] resolved against the app palette. Kept here so the
  /// Bookings card and Booking Detail cannot drift on colour either.
  Color color(AppSemanticColors colors) => switch (tone) {
    BookingPaymentTone.positive => colors.success,
    BookingPaymentTone.attention => colors.warning,
    BookingPaymentTone.neutral => colors.textSecondary,
  };
}

/// Whether a payment line is worth showing at all.
///
/// A booking that ended without any work (cancelled/rejected/expired) has no
/// payment story to tell — unless the server actually recorded a settlement
/// for it, in which case the client must still see what happened to the money.
bool shouldShowBookingPayment(BookingEntity booking) {
  final isPaymentFreeTerminal =
      booking.status == BookingStatus.cancelled ||
      booking.status == BookingStatus.rejected ||
      booking.status == BookingStatus.expired;
  return !isPaymentFreeTerminal ||
      booking.receivedAmount != null ||
      booking.expectedAmount != null;
}

/// THE payment presentation rule for every client surface.
///
/// Reads only the server-derived settlement fields
/// ([BookingEntity.paymentDisplayStatus], [BookingEntity.receivedAmount],
/// [BookingEntity.remainingAmount]) — never commission, never
/// [BookingEntity.canonicalPrice], never a cash confirmation held in this
/// session's memory. The Bookings tab card and Booking Detail both render
/// this, so a booking can never describe its money two different ways.
BookingPaymentPresentation bookingPaymentPresentation(
  AppLocalizations l10n,
  BookingEntity booking,
) {
  switch (booking.paymentDisplayStatus) {
    case PaymentDisplayStatus.paid:
      return BookingPaymentPresentation(
        icon: Icons.check_circle_rounded,
        label: '✓ ${l10n.earningStatusPaid}',
        tone: BookingPaymentTone.positive,
      );
    case PaymentDisplayStatus.partial:
      final received = booking.receivedAmount;
      final remaining = booking.remainingAmount;
      return BookingPaymentPresentation(
        icon: Icons.payments_outlined,
        label: received != null && remaining != null
            ? l10n.bookingCardPartialPayment(
                formatPkr(received),
                formatPkr(remaining),
              )
            : l10n.bookingCardPaymentPending,
        tone: BookingPaymentTone.attention,
      );
    case PaymentDisplayStatus.unpaid:
      final isCancelled =
          booking.status == BookingStatus.cancelled ||
          booking.status == BookingStatus.rejected ||
          booking.status == BookingStatus.expired;
      if (isCancelled && booking.receivedAmount == 0) {
        return BookingPaymentPresentation(
          icon: Icons.money_off_rounded,
          label: l10n.bookingCardNoPaymentTaken,
          tone: BookingPaymentTone.neutral,
        );
      }
      if (booking.status != BookingStatus.completed) {
        return BookingPaymentPresentation(
          icon: Icons.payments_outlined,
          label: l10n.bookingCardPaymentAfterWork,
          tone: BookingPaymentTone.neutral,
        );
      }
      return BookingPaymentPresentation(
        icon: Icons.schedule_rounded,
        label: booking.receivedAmount == 0
            ? l10n.bookingCardNothingPaid
            : l10n.bookingCardPaymentPending,
        tone: BookingPaymentTone.attention,
      );
  }
}

/// Short status word for the payment chip — "Paid" / "Partial" / "Unpaid".
/// Used where the booking's own lifecycle status is shown right next to the
/// money, so the two can be read as the separate things they are.
String bookingPaymentStatusLabel(
  AppLocalizations l10n,
  PaymentDisplayStatus status,
) => switch (status) {
  PaymentDisplayStatus.paid => l10n.earningStatusPaid,
  PaymentDisplayStatus.partial => l10n.bookingPaymentPartial,
  PaymentDisplayStatus.unpaid => l10n.bookingPaymentUnpaid,
};
