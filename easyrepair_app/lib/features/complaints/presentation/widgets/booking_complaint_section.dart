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

/// Whether the "Report a problem" CREATE action may be offered.
///
/// Mirrors `ComplaintsService.createForBooking`, which accepts COMPLETED
/// bookings only — so the button never appears for a status the API would
/// reject. The complaint lookup must have resolved, and resolved to nothing:
/// while it is still in flight the state is unknown and the button must not
/// flash for a booking that already has a report.
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

/// Compact "Report · Pending / Under review / Resolved" strip for the TOP of
/// Booking Detail.
///
/// Reads the same [bookingComplaintProvider] as [BookingComplaintSection], so
/// there is one source of complaint truth on the page: this states it, the
/// section below details it, and neither can contradict the other. Renders
/// nothing until a complaint actually exists.
class BookingComplaintStatusBanner extends ConsumerWidget {
  const BookingComplaintStatusBanner({
    super.key,
    required this.bookingId,
    required this.isClient,
    required this.ownsBooking,
  });

  final String bookingId;
  final bool isClient;
  final bool ownsBooking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isClient || !ownsBooking) return const SizedBox.shrink();

    final complaint = ref
        .watch(bookingComplaintProvider(bookingId))
        .valueOrNull;
    if (complaint == null) return const SizedBox.shrink();

    final colors = context.semanticColors;
    final (foreground, background, icon) = _tone(context, complaint.status);

    return Container(
      key: const Key('report-status-banner'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${context.l10n.bookingReportLabel} · '
              '${complaintStatusLabel(context.l10n, complaint.status)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: foreground,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, IconData) _tone(BuildContext context, ComplaintStatus status) {
    final colors = context.semanticColors;
    return switch (status) {
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
  }
}

/// The single full complaint surface: either the create CTA, or the submitted
/// report with its issues, free text, timestamp, reference and support
/// request. Never both, and never a second create button once a report
/// exists — duplicate protection stays enforced by the backend too.
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
    if (!widget.isClient || !widget.ownsBooking) {
      return const SizedBox.shrink();
    }

    final complaintState = ref.watch(
      bookingComplaintProvider(widget.bookingId),
    );

    // An existing report stays visible for the whole completed family — a
    // booking that moved on to AWAITING_CONFIRMATION/SETTLED must not lose
    // the report the client already filed.
    final complaint = complaintState.valueOrNull;
    if (complaint != null) {
      return _ExistingComplaintCard(
        complaint: complaint,
        requestingHuman: _requestingHuman,
        onRequestHuman: complaint.humanRequested ? null : _requestHuman,
      );
    }

    // No report yet: only a COMPLETED booking can create one.
    if (widget.bookingStatus != BookingStatus.completed) {
      return const SizedBox.shrink();
    }
    if (complaintState.isLoading && !complaintState.hasValue) {
      return const _LookupPlaceholder();
    }
    if (complaintState.hasError && !complaintState.hasValue) {
      return _LookupError(
        onRetry: () =>
            ref.invalidate(bookingComplaintProvider(widget.bookingId)),
      );
    }
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
      height: 52,
      child: OutlinedButton.icon(
        key: const Key('report-problem-button'),
        onPressed: () =>
            context.push('/client/booking/${widget.bookingId}/report'),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.semanticColors.primary,
          side: BorderSide(color: context.semanticColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        icon: const Icon(Icons.flag_outlined, size: 18),
        label: Text(context.l10n.reportProblemAction),
      ),
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
                  style: TextStyle(
                    fontSize: 16,
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: colors.textPrimary,
                      ),
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
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '${context.l10n.reportSubmittedAtLabel}: '
            '${DateFormat('d MMM yyyy, h:mm a').format(complaint.createdAt.toLocal())}',
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
          ),
          Text(
            '${context.l10n.reportReferenceLabel}: ${complaint.id}',
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
          ),
          const SizedBox(height: 6),
          if (complaint.humanRequested)
            Text(
              context.l10n.reportHumanRequestedConfirmation,
              style: TextStyle(fontSize: 13.5, color: colors.success),
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
            style: TextStyle(
              fontSize: 12.5,
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
