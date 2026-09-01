import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/cash_payment_confirmation_entity.dart';
import '../providers/booking_providers.dart';
import '../providers/review_prompt_controller.dart';

Future<CashPaymentConfirmationEntity?> showCashPaymentConfirmationDialog(
  BuildContext context, {
  required String bookingId,
  required num? expectedAmount,
}) {
  // Dismissible on purpose. This prompt opens by itself on every COMPLETED
  // booking that still owes cash, and a customer can easily have several — so
  // a modal that refuses the back button and the barrier does not "remind"
  // them, it locks them out of the app until every last booking is settled.
  // Closing it returns null; the caller treats that as "not now".
  return showDialog<CashPaymentConfirmationEntity>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: CashPaymentConfirmationCard(
        bookingId: bookingId,
        expectedAmount: expectedAmount,
        onConfirmed: (confirmation) =>
            Navigator.of(dialogContext).pop(confirmation),
      ),
    ),
  );
}

/// The single entry point for Client cash-confirmation prompts.
///
/// Every surface delegates here, so provider refreshes and the in-flight
/// dialog guard cannot drift apart. The guard is claimed synchronously before
/// `showDialog` runs, collapsing socket, push, poll and rebuild observations
/// of the same completion into one modal.
class CashPaymentPromptController {
  CashPaymentPromptController(this._ref);

  final Ref _ref;
  String? _activeBookingId;
  Completer<void>? _idleCompleter;
  final Set<String> _automaticallyPrompted = <String>{};

  String? get activeBookingId => _activeBookingId;
  bool get isShowing => _activeBookingId != null;
  Future<void> get whenIdle => _idleCompleter?.future ?? Future<void>.value();

  Future<CashPaymentConfirmationEntity?> showForBooking(
    BuildContext context,
    BookingEntity booking, {
    bool automatic = false,
  }) async {
    if (!booking.canClientConfirmCash) return null;
    if (_activeBookingId != null) return null;
    if (automatic && _automaticallyPrompted.contains(booking.id)) return null;

    _activeBookingId = booking.id;
    _idleCompleter = Completer<void>();
    if (automatic) _automaticallyPrompted.add(booking.id);
    try {
      final confirmation = await showCashPaymentConfirmationDialog(
        context,
        bookingId: booking.id,
        expectedAmount: booking.canonicalPrice,
      );
      if (confirmation != null) {
        // The POST response is server-authored, then every visible booking
        // surface is refetched so settlement fields remain the rendering truth.
        _ref.invalidate(bookingsNotifierProvider);
        _ref.invalidate(bookingDetailProvider(booking.id));
        _ref.invalidate(pendingReviewsProvider);

        // The receipt's CTA explicitly says "Continue to review". Closing
        // the cash dialog is only the first half of that action: enqueue the
        // same canonical review controller used by Booking Detail,
        // notification taps and resume sweeps. Its modal-lane guard waits for
        // this cash prompt's finally block before presenting ReviewModal, so
        // the dialogs never overlap and payment remains complete even if the
        // customer later dismisses the optional review.
        if (context.mounted) {
          _ref
              .read(reviewPromptControllerProvider)
              .enqueueFront(context, booking.id);
        }
      }
      // A null result now means the customer closed the prompt — the back
      // button, the barrier, or "later". The booking stays in
      // [_automaticallyPrompted] so this session does not reopen it on the
      // next rebuild; the manual CTA on My Bookings, Booking Detail and Track
      // Worker is still there whenever they are ready to pay.
      return confirmation;
    } finally {
      _activeBookingId = null;
      _idleCompleter?.complete();
      _idleCompleter = null;
    }
  }
}

final cashPaymentPromptControllerProvider =
    Provider<CashPaymentPromptController>(
      (ref) => CashPaymentPromptController(ref),
    );

/// Schedules automatic presentation after the current build/layout pass.
/// Repeated calls are intentional and safe: [CashPaymentPromptController]
/// deduplicates them synchronously by booking id and active-dialog state.
void scheduleAutomaticCashPaymentPrompt(
  BuildContext context,
  WidgetRef ref,
  BookingEntity booking,
) {
  if (!booking.canClientConfirmCash) {
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) {
      return;
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    unawaited(
      ref
          .read(cashPaymentPromptControllerProvider)
          .showForBooking(context, booking, automatic: true),
    );
  });
}

class CashPaymentConfirmationCard extends ConsumerStatefulWidget {
  const CashPaymentConfirmationCard({
    super.key,
    required this.bookingId,
    required this.expectedAmount,
    required this.onConfirmed,
  });

  final String bookingId;
  final num? expectedAmount;
  final ValueChanged<CashPaymentConfirmationEntity> onConfirmed;

  @override
  ConsumerState<CashPaymentConfirmationCard> createState() =>
      _CashPaymentConfirmationCardState();
}

class _CashPaymentConfirmationCardState
    extends ConsumerState<CashPaymentConfirmationCard> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notifier = ref.read(
      cashPaymentConfirmationProvider(widget.bookingId).notifier,
    );
    final current = ref.read(cashPaymentConfirmationProvider(widget.bookingId));
    if (current.isLoading || !_formKey.currentState!.validate()) return;

    try {
      await notifier.confirm(int.parse(_amountController.text));
    } catch (_) {
      // Provider state owns the controlled, localized error shown below.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final state = ref.watch(cashPaymentConfirmationProvider(widget.bookingId));
    final confirmation = state.valueOrNull;

    return Card(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: confirmation == null
            ? Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.payments_outlined, color: colors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.l10n.cashPaymentTitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.cashPaymentQuestion,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.expectedAmount != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.cashPaymentExpected(
                          formatPkr(widget.expectedAmount!),
                        ),
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _amountController,
                      enabled: !state.isLoading,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: context.l10n.cashPaymentInputLabel,
                        hintText: context.l10n.cashPaymentInputHint,
                        prefixText: 'PKR ',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return context.l10n.cashPaymentRequired;
                        }
                        if (!RegExp(r'^\d+$').hasMatch(text)) {
                          return context.l10n.cashPaymentWholeRupees;
                        }
                        return null;
                      },
                      onFieldSubmitted: state.isLoading
                          ? null
                          : (_) => _submit(),
                    ),
                    if (state.hasError) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage(context, state.error),
                        style: TextStyle(color: colors.error),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      key: const Key('cash-payment-submit-button'),
                      onPressed: state.isLoading ? null : _submit,
                      icon: state.isLoading
                          ? SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.onPrimary,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(context.l10n.cashPaymentTitle),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      key: const Key('cash-payment-later-button'),
                      onPressed: state.isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(context.l10n.cashPaymentLater),
                    ),
                  ],
                ),
              )
            : _ConfirmationReceipt(
                confirmation: confirmation,
                onContinue: () => widget.onConfirmed(confirmation),
              ),
      ),
    );
  }

  String _errorMessage(BuildContext context, Object? error) {
    if (error is Failure && error.code == FailureCode.conflict) {
      return context.l10n.cashPaymentConflict;
    }
    return failureMessage(
      context.l10n,
      error,
      fallback: context.l10n.cashPaymentFailed,
    );
  }
}

class _ConfirmationReceipt extends StatelessWidget {
  const _ConfirmationReceipt({
    required this.confirmation,
    required this.onContinue,
  });

  final CashPaymentConfirmationEntity confirmation;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.verified_rounded, color: colors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.cashPaymentConfirmedTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.cashPaymentPaid(
            formatPkr(confirmation.receivedCashTotal),
          ),
        ),
        Text(
          context.l10n.cashPaymentExpectedReceipt(
            formatPkr(confirmation.expectedTotal),
          ),
        ),
        if (confirmation.shortfall > 0)
          Text(
            context.l10n.cashPaymentShortfall(
              formatPkr(confirmation.shortfall),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          context.l10n.cashPaymentReference(confirmation.settlementId),
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onContinue,
          icon: const Icon(Icons.star_outline_rounded),
          label: Text(context.l10n.cashPaymentContinueReview),
        ),
      ],
    );
  }
}
