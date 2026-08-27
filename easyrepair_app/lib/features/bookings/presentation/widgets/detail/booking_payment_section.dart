import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/l10n/l10n_extensions.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../../../core/utils/currency_utils.dart';
import '../../../domain/entities/booking_entity.dart';
import '../../providers/booking_providers.dart';
import '../../utils/booking_payment_presentation.dart';
import '../../utils/status_labels.dart';
import '../cash_payment_confirmation_card.dart';
import 'booking_detail_primitives.dart';

/// Booking lifecycle and payment, side by side but never conflated.
///
/// The payment half is read ENTIRELY from the server-derived settlement
/// fields on [BookingEntity] — `paymentDisplayStatus`, `receivedAmount`,
/// `expectedAmount`, `remainingAmount` — which `GET /bookings/:id` already
/// returns from the current BookingSettlement. Nothing here is recomputed
/// from commission, from `canonicalPrice`, or from a confirmation held in
/// this page's memory, so closing and reopening the page cannot lose it.
class BookingPaymentSection extends ConsumerWidget {
  final BookingEntity booking;

  const BookingPaymentSection({super.key, required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!shouldShowBookingPayment(booking)) return const SizedBox.shrink();

    final colors = context.semanticColors;
    final l10n = context.l10n;
    final payment = bookingPaymentPresentation(l10n, booking);
    final paymentColor = payment.color(colors);
    final received = booking.receivedAmount;
    final remaining = booking.remainingAmount;
    final expected = booking.expectedAmount;

    return BookingDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingSectionHeading(
            label: l10n.bookingPaymentTitle,
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 14),
          // Booking lifecycle and money are two different facts about the
          // same job. Once the job is finished they are pinned side by side —
          // "Booking: Completed" next to "Payment: Partial" — so a payment
          // state can never read as a lifecycle state. Before completion the
          // booking status is already stated once in the summary above, so
          // only the payment half appears and nothing is said twice.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (booking.isClientTerminal) ...[
                Expanded(
                  child: _Fact(
                    label: l10n.bookingStatusSectionLabel,
                    value: bookingCardStatusLabel(l10n, booking.status),
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: _Fact(
                  label: l10n.bookingPaymentTitle,
                  value: bookingPaymentStatusLabel(
                    l10n,
                    booking.paymentDisplayStatus,
                  ),
                  color: paymentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(payment.icon, size: 16, color: paymentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  payment.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: paymentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          // Amounts appear only once the server actually has a settlement —
          // `receivedAmount` is null exactly when no settlement row exists.
          if (booking.hasSettlementRecord) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: colors.divider),
            const SizedBox(height: 14),
            if (received != null)
              BookingAmountRow(
                label: l10n.bookingPaymentReceived,
                amount: formatPkr(received),
              ),
            if (expected != null) ...[
              const SizedBox(height: 8),
              BookingAmountRow(
                label: l10n.bookingPaymentExpected,
                amount: formatPkr(expected),
              ),
            ],
            if (remaining != null && remaining > 0) ...[
              const SizedBox(height: 8),
              BookingAmountRow(
                label: l10n.bookingPaymentRemaining,
                amount: formatPkr(remaining),
              ),
            ],
          ],
          // Offered only while the backend would accept it: COMPLETED with no
          // settlement recorded yet. Once a settlement exists the client sees
          // its state above instead of an empty input form.
          if (booking.canClientConfirmCash) ...[
            const SizedBox(height: 16),
            BookingPrimaryButton(
              key: const Key('confirm-cash-button'),
              label: l10n.cashPaymentTitle,
              icon: Icons.payments_rounded,
              onPressed: () => _confirmCash(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCash(BuildContext context, WidgetRef ref) async {
    // Reuses the existing idempotent POST /bookings/:id/confirm-cash-payment
    // dialog untouched; on success the booking is refetched so the server's
    // settlement — not this dialog's return value — drives what is rendered.
    final confirmation = await showCashPaymentConfirmationDialog(
      context,
      bookingId: booking.id,
      expectedAmount: booking.canonicalPrice,
    );
    if (confirmation == null) return;
    // Refetch so the SERVER's settlement — not this dialog's return value —
    // decides what the client sees from here on, including after they leave
    // the page and come back.
    ref.invalidate(bookingDetailProvider(booking.id));
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Fact({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: color,
          ),
        ),
      ],
    );
  }
}
