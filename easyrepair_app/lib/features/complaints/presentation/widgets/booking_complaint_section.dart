import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../domain/entities/complaint_entity.dart';
import '../providers/complaint_providers.dart';
import '../utils/complaint_labels.dart';

bool shouldShowReportCreateAction({
  required BookingStatus bookingStatus,
  required bool isClient,
  required bool ownsBooking,
  required AsyncValue<ComplaintEntity?> complaintState,
}) {
  return bookingStatus == BookingStatus.completed &&
      isClient &&
      ownsBooking &&
      complaintState.hasValue &&
      complaintState.valueOrNull == null;
}

class BookingComplaintSection extends ConsumerStatefulWidget {
  const BookingComplaintSection({
    super.key,
    required this.bookingId,
    required this.bookingStatus,
    required this.isClient,
    required this.ownsBooking,
  });

  final String bookingId;
  final BookingStatus bookingStatus;
  final bool isClient;
  final bool ownsBooking;

  @override
  ConsumerState<BookingComplaintSection> createState() =>
      _BookingComplaintSectionState();
}

class _BookingComplaintSectionState
    extends ConsumerState<BookingComplaintSection> {
  bool _requestingHuman = false;

  @override
  Widget build(BuildContext context) {
    if (widget.bookingStatus != BookingStatus.completed ||
        !widget.isClient ||
        !widget.ownsBooking) {
      return const SizedBox.shrink();
    }

    final complaintState = ref.watch(
      bookingComplaintProvider(widget.bookingId),
    );
    if (complaintState.isLoading && !complaintState.hasValue) {
      return const _LookupPlaceholder();
    }
    if (complaintState.hasError && !complaintState.hasValue) {
      return _LookupError(
        onRetry: () => ref.invalidate(
          bookingComplaintProvider(widget.bookingId),
        ),
      );
    }

    final complaint = complaintState.valueOrNull;
    if (complaint == null) {
      if (!shouldShowReportCreateAction(
        bookingStatus: widget.bookingStatus,
        isClient: widget.isClient,
        ownsBooking: widget.ownsBooking,
        complaintState: complaintState,
      )) {
        return const SizedBox.shrink();
      }
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const Key('report-problem-button'),
          onPressed: () => context.push(
            '/client/booking/${widget.bookingId}/report',
          ),
          icon: const Icon(Icons.flag_outlined),
          label: Text(context.l10n.reportProblemAction),
        ),
      );
    }

    return _ExistingComplaintCard(
      complaint: complaint,
      requestingHuman: _requestingHuman,
      onRequestHuman: complaint.humanRequested ? null : _requestHuman,
    );
  }

  Future<void> _requestHuman() async {
    if (_requestingHuman) return;
    setState(() => _requestingHuman = true);
    try {
      await ref
          .read(bookingComplaintProvider(widget.bookingId).notifier)
          .requestHuman();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.reportHumanRequestedConfirmation)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.reportActionFailed)),
      );
    } finally {
      if (mounted) setState(() => _requestingHuman = false);
    }
  }
}

class _LookupPlaceholder extends StatelessWidget {
  const _LookupPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Container(
      key: const Key('report-lookup-loading'),
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.primary,
        ),
      ),
    );
  }
}

class _LookupError extends StatelessWidget {
  const _LookupError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Container(
      key: const Key('report-lookup-error'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.reportLookupFailed,
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
        ],
      ),
    );
  }
}

class _ExistingComplaintCard extends StatelessWidget {
  const _ExistingComplaintCard({
    required this.complaint,
    required this.requestingHuman,
    required this.onRequestHuman,
  });

  final ComplaintEntity complaint;
  final bool requestingHuman;
  final VoidCallback? onRequestHuman;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Container(
      key: const Key('existing-report-section'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  context.l10n.reportYourReportTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              ComplaintStatusChip(status: complaint.status),
            ],
          ),
          const SizedBox(height: 14),
          for (final issue in complaint.issueTypes)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      complaintIssueLabel(context.l10n, issue),
                      style: TextStyle(color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          if (complaint.otherText != null) ...[
            const SizedBox(height: 5),
            Text(
              complaint.otherText!,
              key: const Key('report-other-text'),
              style: TextStyle(color: colors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '${context.l10n.reportSubmittedAtLabel}: '
            '${DateFormat('d MMM yyyy, h:mm a').format(complaint.createdAt.toLocal())}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
          Text(
            '${context.l10n.reportReferenceLabel}: ${complaint.id}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
          const SizedBox(height: 6),
          if (complaint.humanRequested)
            Text(
              context.l10n.reportHumanRequestedConfirmation,
              style: TextStyle(color: colors.success),
            )
          else
            TextButton.icon(
              key: const Key('talk-to-support-button'),
              onPressed: requestingHuman ? null : onRequestHuman,
              icon: requestingHuman
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  : const Icon(Icons.support_agent_rounded),
              label: Text(context.l10n.reportTalkToSupport),
            ),
        ],
      ),
    );
  }
}

class ComplaintStatusChip extends StatelessWidget {
  const ComplaintStatusChip({super.key, required this.status});

  final ComplaintStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final (foreground, background, icon) = switch (status) {
      ComplaintStatus.open => (
          colors.warning,
          colors.warningSurface,
          Icons.schedule_rounded,
        ),
      ComplaintStatus.inProgress || ComplaintStatus.waitingOnCustomer => (
          colors.primary,
          colors.softTeal,
          Icons.manage_search_rounded,
        ),
      ComplaintStatus.resolved || ComplaintStatus.closed => (
          colors.success,
          colors.successSoft,
          Icons.check_circle_rounded,
        ),
    };
    return Container(
      key: Key('complaint-status-${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 5),
          Text(
            complaintStatusLabel(context.l10n, status),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
