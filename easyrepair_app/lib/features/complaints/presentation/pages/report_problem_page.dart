import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../client/presentation/widgets/client_state_view.dart';
import '../../domain/entities/complaint_entity.dart';
import '../providers/complaint_providers.dart';
import '../utils/complaint_labels.dart';

class ReportProblemPage extends ConsumerStatefulWidget {
  const ReportProblemPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends ConsumerState<ReportProblemPage> {
  final _selected = <ComplaintIssueType>{};
  final _otherController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  bool get _otherSelected => _selected.contains(ComplaintIssueType.other);
  bool get _canSubmit =>
      _selected.isNotEmpty &&
      (!_otherSelected || _otherController.text.trim().isNotEmpty) &&
      !_submitting;

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final complaintState = ref.watch(
      bookingComplaintProvider(widget.bookingId),
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: colors.surface,
        title: Text(context.l10n.reportProblemTitle),
      ),
      body: SafeArea(
        child: _submitted
            ? const _ReportSuccessView()
            : complaintState.isLoading &&
                  !complaintState.hasValue &&
                  !_submitting
            ? Center(
                child: ClientStateView.loading(
                  message: context.l10n.reportCheckingExisting,
                ),
              )
            : complaintState.hasError && !complaintState.hasValue
            ? ClientStateView.error(
                title: context.l10n.clientStateErrorTitle,
                message: context.l10n.reportLookupFailed,
                actionLabel: context.l10n.commonRetry,
                onAction: () =>
                    ref.invalidate(bookingComplaintProvider(widget.bookingId)),
              )
            : complaintState.valueOrNull != null && !_submitting
            ? _AlreadySubmittedView(bookingId: widget.bookingId)
            : _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final colors = context.semanticColors;
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const Key('report-form'),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              Text(
                context.l10n.reportProblemHelper,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 18),
              for (final issue in ComplaintIssueType.values) ...[
                _IssueOption(
                  issue: issue,
                  selected: _selected.contains(issue),
                  onChanged: () => _toggle(issue),
                ),
                if (issue == ComplaintIssueType.other && _otherSelected) ...[
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('report-other-field'),
                    controller: _otherController,
                    onChanged: (_) => setState(() {}),
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: context.l10n.reportOtherLabel,
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: colors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: FilledButton(
            key: const Key('submit-report-button'),
            onPressed: _canSubmit ? _submit : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              disabledBackgroundColor: colors.disabled,
            ),
            child: _submitting
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onPrimary,
                    ),
                  )
                : Text(context.l10n.reportSubmit),
          ),
        ),
      ],
    );
  }

  /// Returns to Booking Detail whether or not this page was pushed onto an
  /// existing stack. A complaint notification (or any deep link) can make the
  /// report route the only entry, and popping that throws in GoRouter.
  void _returnToBooking() {
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/client/booking/${widget.bookingId}');
    }
  }

  void _toggle(ComplaintIssueType issue) {
    if (_submitting) return;
    setState(() {
      if (!_selected.add(issue)) {
        _selected.remove(issue);
        if (issue == ComplaintIssueType.other) _otherController.clear();
      }
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(bookingComplaintProvider(widget.bookingId).notifier)
          .submit(
            issueTypes: Set.unmodifiable(_selected),
            otherText: _otherSelected ? _otherController.text.trim() : null,
          );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _returnToBooking();
        }),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.reportActionFailed)));
    }
  }
}

class _IssueOption extends StatelessWidget {
  const _IssueOption({
    required this.issue,
    required this.selected,
    required this.onChanged,
  });

  final ComplaintIssueType issue;
  final bool selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Semantics(
      checked: selected,
      button: true,
      child: Material(
        color: selected ? colors.softTeal : colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: Key('report-issue-${issue.apiValue}'),
          onTap: onChanged,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? colors.primary : colors.controlBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: (_) => onChanged(),
                  activeColor: colors.primary,
                  checkColor: colors.onPrimary,
                  side: BorderSide(color: colors.controlBorder),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    complaintIssueLabel(context.l10n, issue),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportSuccessView extends StatelessWidget {
  const _ReportSuccessView();

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Center(
      key: const Key('report-success'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 68, color: colors.success),
            const SizedBox(height: 18),
            Text(
              context.l10n.reportSubmittedTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.reportSubmittedBody,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlreadySubmittedView extends StatelessWidget {
  const _AlreadySubmittedView({required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Center(
      key: const Key('report-already-submitted'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_turned_in_rounded,
              size: 56,
              color: colors.success,
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.reportAlreadyExists,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textPrimary),
            ),
            const SizedBox(height: 14),
            FilledButton(
              // Same deep-link hazard as the success view: this page can be
              // the only route in the stack.
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/client/booking/$bookingId'),
              child: Text(context.l10n.reportBackToBooking),
            ),
          ],
        ),
      ),
    );
  }
}
