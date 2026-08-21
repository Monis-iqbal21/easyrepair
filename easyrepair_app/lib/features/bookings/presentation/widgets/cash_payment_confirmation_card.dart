import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../domain/entities/cash_payment_confirmation_entity.dart';
import '../providers/booking_providers.dart';

Future<CashPaymentConfirmationEntity?> showCashPaymentConfirmationDialog(
  BuildContext context, {
  required String bookingId,
  required num? expectedAmount,
}) {
  return showDialog<CashPaymentConfirmationEntity>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: CashPaymentConfirmationCard(
          bookingId: bookingId,
          expectedAmount: expectedAmount,
          onConfirmed: (confirmation) =>
              Navigator.of(dialogContext).pop(confirmation),
        ),
      ),
    ),
  );
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
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                        if (text.isEmpty) return context.l10n.cashPaymentRequired;
                        if (!RegExp(r'^\d+$').hasMatch(text)) {
                          return context.l10n.cashPaymentWholeRupees;
                        }
                        return null;
                      },
                      onFieldSubmitted: state.isLoading ? null : (_) => _submit(),
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
                      label: Text(context.l10n.cashPaymentConfirmAction),
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
        Text(context.l10n.cashPaymentPaid(formatPkr(confirmation.receivedCashTotal))),
        Text(context.l10n.cashPaymentExpectedReceipt(formatPkr(confirmation.expectedTotal))),
        if (confirmation.shortfall > 0)
          Text(context.l10n.cashPaymentShortfall(formatPkr(confirmation.shortfall))),
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
