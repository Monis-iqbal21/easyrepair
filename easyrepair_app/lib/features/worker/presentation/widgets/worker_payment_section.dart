import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../providers/worker_job_providers.dart';

const double _rCard = 16;
const double _rButton = 14;

/// What the client ACTUALLY paid, for the Ustaad who did the work.
///
/// Every amount here is read straight off the booking's server-side
/// settlement — `receivedAmount`, `remainingAmount`, `settlementCommission`,
/// `settlementMunafa`. Nothing on this screen multiplies anything by 18%, and
/// the quoted price is never presented as money received. Before a settlement
/// exists the card says so plainly and offers the Ustaad the one thing they
/// can do about it: declare what they were handed.
class WorkerPaymentSection extends ConsumerWidget {
  const WorkerPaymentSection({super.key, required this.job});

  final BookingEntity job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.bookingPaymentTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (job.hasSettlementRecord)
            ..._settledRows(context, c)
          else
            ..._awaitingRows(context, c),
          if (job.canWorkerReportPayment) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('worker-report-payment-button'),
                onPressed: () => showWorkerReportPaymentSheet(context, job),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: c.primary,
                  side: BorderSide(color: c.controlBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_rButton),
                  ),
                ),
                child: Text(l10n.workerReportPaymentAction),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _awaitingRows(BuildContext context, AppSemanticColors c) {
    final l10n = context.l10n;
    return [
      _PaymentRow(
        label: l10n.workerPaymentAwaitingTitle,
        value: l10n.workerPaymentAwaitingBody,
        valueColor: c.textSecondary,
        wrapValue: true,
      ),
    ];
  }

  List<Widget> _settledRows(BuildContext context, AppSemanticColors c) {
    final l10n = context.l10n;
    final short = job.hasPaymentShortfall;
    return [
      _PaymentRow(
        label: l10n.bookingPaymentExpected,
        value: formatPkr(job.expectedAmount),
        valueColor: c.textSecondary,
      ),
      _PaymentRow(
        key: const Key('worker-payment-received'),
        label: l10n.bookingPaymentReceived,
        value: formatPkr(job.receivedAmount),
        // Attention, not error: a short payment is a thing to chase, not a
        // failure of the Ustaad's work.
        valueColor: short ? c.warning : c.success,
        emphasise: true,
      ),
      if (short)
        _PaymentRow(
          key: const Key('worker-payment-shortfall'),
          label: l10n.bookingPaymentRemaining,
          value: formatPkr(job.remainingAmount),
          valueColor: c.urgent,
          emphasise: true,
        ),
      if (job.settlementPartsPaid != null && job.settlementPartsPaid! > 0)
        _PaymentRow(
          label: l10n.workerPaymentPartsLabel,
          value: formatPkr(job.settlementPartsPaid),
          valueColor: c.textSecondary,
        ),
      if (job.settlementLabourPaid != null && job.settlementLabourPaid! > 0)
        _PaymentRow(
          label: l10n.workerPaymentLabourLabel,
          value: formatPkr(job.settlementLabourPaid),
          valueColor: c.textSecondary,
        ),
      if (job.settlementCommission != null)
        _PaymentRow(
          key: const Key('worker-payment-commission'),
          label: l10n.earningCommissionLabel,
          value: '- ${formatPkr(job.settlementCommission)}',
          valueColor: c.textSecondary,
        ),
      if (job.settlementMunafa != null)
        _PaymentRow(
          key: const Key('worker-payment-munafa'),
          label: l10n.earningUstaadEarnings,
          value: formatPkr(job.settlementMunafa),
          valueColor: c.textPrimary,
          emphasise: true,
        ),
    ];
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
    this.emphasise = false,
    this.wrapValue = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool emphasise;
  final bool wrapValue;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final valueStyle = TextStyle(
      fontSize: emphasise ? 15 : 13.5,
      fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500,
      color: valueColor,
      height: 1.4,
    );

    if (wrapValue) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(value, style: valueStyle),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

/// "Kam paisa mila?" — one field, one fact.
///
/// The sheet collects a whole-rupee amount and nothing else. It refuses an
/// empty or negative entry locally so the Ustaad is not sent on a round trip
/// for an obvious mistake, and leaves every other judgement — "more than the
/// payable total", the shortfall, the commission split, whether a settlement
/// case opens — to the server, which is the only place that arithmetic lives.
Future<void> showWorkerReportPaymentSheet(
  BuildContext context,
  BookingEntity job,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.semanticColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_rCard)),
    ),
    builder: (sheetContext) => _ReportPaymentSheet(job: job),
  );
}

class _ReportPaymentSheet extends ConsumerStatefulWidget {
  const _ReportPaymentSheet({required this.job});

  final BookingEntity job;

  @override
  ConsumerState<_ReportPaymentSheet> createState() =>
      _ReportPaymentSheetState();
}

class _ReportPaymentSheetState extends ConsumerState<_ReportPaymentSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;
  bool _touched = false;

  /// Whole rupees, zero or more. `null` when the field cannot be read that
  /// way at all — the server applies the same floor plus the upper bound.
  int? get _amount {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return null;
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final l10n = context.l10n;
    final invalid = _touched && _amount == null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.workerReportPaymentTitle,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.workerReportPaymentHelper,
            style: TextStyle(fontSize: 13.5, color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('worker-report-payment-field'),
            controller: _controller,
            autofocus: true,
            enabled: !_submitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            onSubmitted: _submitting ? null : (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.workerReportPaymentFieldLabel,
              prefixText: 'Rs ',
              errorText: invalid ? l10n.workerReportPaymentInvalidError : null,
              filled: true,
              fillColor: c.surfaceSubtle,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_rButton),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('worker-report-payment-submit'),
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: c.primary,
              foregroundColor: c.onPrimary,
              disabledBackgroundColor: c.disabled,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_rButton),
              ),
            ),
            child: _submitting
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.onPrimary,
                    ),
                  )
                : Text(l10n.workerReportPaymentSubmit),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final amount = _amount;
    if (amount == null) {
      setState(() => _touched = true);
      return;
    }

    setState(() {
      _submitting = true;
      _touched = true;
    });

    final failure = await ref
        .read(reportReceivedPaymentProvider.notifier)
        .report(widget.job.id, amount);

    if (!mounted) return;
    setState(() => _submitting = false);

    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (failure == null) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.workerReportPaymentSuccess)),
      );
      return;
    }

    // The server owns every rejection reason worth showing — "more than the
    // payable total", "already recorded with a different amount", and so on.
    // The sheet stays open so the amount can be corrected in place.
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failureMessage(
            l10n,
            failure,
            fallback: l10n.workerReportPaymentFailed,
          ),
        ),
      ),
    );
  }
}
