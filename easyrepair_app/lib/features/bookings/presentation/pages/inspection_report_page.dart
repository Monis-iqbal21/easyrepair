import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency_utils.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/inspection_report_entity.dart';
import '../providers/booking_providers.dart';
import '../utils/status_labels.dart';
import '../providers/review_prompt_controller.dart';
import '../widgets/cash_payment_confirmation_card.dart';
import '../widgets/media_attachment_widgets.dart';
import 'worker_discovery_map_page.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/theme/app_semantic_colors.dart';

/// Full inspection report view — issue found, recommended repair, parts,
/// labour, repair quote total, photos, notes. Reused for both the client
/// (with Accept/Close decision buttons while pending) and the assigned
/// worker (read-only, [showDecisionButtons] false) via role-aware routing.
///
/// Repair quote total = labour + parts only — the inspection fee is
/// deliberately never shown here: it's either waived (quote accepted) or
/// charged alone (closed after inspection), never combined with the repair
/// quote, so showing it inside the report would be misleading.
class InspectionReportPage extends ConsumerWidget {
  final String bookingId;
  final bool showDecisionButtons;

  const InspectionReportPage({
    super.key,
    required this.bookingId,
    required this.showDecisionButtons,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    final reportAsync = ref.watch(inspectionReportProvider(bookingId));

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        foregroundColor: c.textPrimary,
        title: Text(
          context.l10n.inspectionReportTitle,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: reportAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: c.primary, strokeWidth: 2),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 40,
                    color: c.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    failureMessage(
                      context.l10n,
                      err,
                      fallback: context.l10n.inspectionReportNotAvailable,
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textSecondary, fontSize: 13.5),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () =>
                        ref.invalidate(inspectionReportProvider(bookingId)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.primary,
                      side: BorderSide(color: c.primary),
                    ),
                    child: Text(context.l10n.commonRetry),
                  ),
                ],
              ),
            ),
          ),
          data: (report) => _ReportBody(
            bookingId: bookingId,
            report: report,
            showDecisionButtons: showDecisionButtons,
          ),
        ),
      ),
    );
  }
}

class _ReportBody extends ConsumerWidget {
  final String bookingId;
  final InspectionReportEntity report;
  final bool showDecisionButtons;

  const _ReportBody({
    required this.bookingId,
    required this.report,
    required this.showDecisionButtons,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    final isPending =
        report.decisionStatus == InspectionDecisionStatus.pendingClientDecision;
    final isDeciding = ref.watch(inspectionDecisionNotifierProvider).isLoading;
    // The inspection decision says what the client chose; it does not say
    // whether the job is still running. Once the booking itself has finished,
    // "Quote accepted — repair in progress" is simply untrue, so the badge
    // defers to the booking's own status — the same source of truth the
    // Bookings list and the detail timeline read. Null while that detail is
    // still loading, in which case the decision wording stands.
    final bookingStatus = ref
        .watch(bookingDetailProvider(bookingId))
        .valueOrNull
        ?.status;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DecisionBadge(
            decisionStatus: report.decisionStatus,
            bookingStatus: bookingStatus,
          ),
          const SizedBox(height: 14),
          if ((report.issueFound != null && report.issueFound!.isNotEmpty) ||
              (report.recommendedRepair != null &&
                  report.recommendedRepair!.isNotEmpty) ||
              (report.notes != null && report.notes!.isNotEmpty))
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (report.issueFound != null &&
                      report.issueFound!.isNotEmpty)
                    _row(
                      c,
                      context.l10n.inspectionRowIssueFound,
                      report.issueFound!,
                    ),
                  if (report.recommendedRepair != null &&
                      report.recommendedRepair!.isNotEmpty)
                    _row(
                      c,
                      context.l10n.inspFormRecommendedRepair,
                      report.recommendedRepair!,
                    ),
                  if (report.notes != null && report.notes!.isNotEmpty)
                    _row(
                      c,
                      context.l10n.inspectionRowNotes,
                      report.notes!,
                      isLast: true,
                    ),
                ],
              ),
            ),
          if (report.voiceNoteUrl != null) ...[
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.inspectionUstaadVoiceNote,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  WhatsAppVoiceNotePlayer(
                    url: report.voiceNoteUrl,
                    durationSeconds: report.voiceNoteDurationSeconds,
                  ),
                ],
              ),
            ),
          ],
          if (report.photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.inspectionPhotos,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: report.photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      // Tap opens the shared full-screen viewer (zoom/pan,
                      // ✕ / Android-back close) — same one Job Details uses.
                      itemBuilder: (ctx, i) => GestureDetector(
                        onTap: () =>
                            showFullScreenImage(ctx, report.photos[i].url),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            report.photos[i].url,
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 88,
                              height: 88,
                              color: c.surfaceSubtle,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: c.textSecondary,
                              ),
                            ),
                            loadingBuilder: (_, child, prog) => prog == null
                                ? child
                                : Container(
                                    width: 88,
                                    height: 88,
                                    color: c.surfaceSubtle,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: c.primary,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (report.partsNeeded && report.parts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.inspectionParts,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...report.parts.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.warranty != null && p.warranty!.isNotEmpty
                                  ? context.l10n.inspectionPartWithWarranty(
                                      p.name,
                                      p.quantity,
                                      p.warranty!,
                                    )
                                  : context.l10n.bookingServiceQuantity(
                                      p.name,
                                      p.quantity,
                                    ),
                              style: TextStyle(
                                fontSize: 13.5,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                          // Price hidden in the sanitized bidder/hired-different-worker view.
                          if (p.lineTotal != null)
                            Text(
                              formatPkr(p.lineTotal!),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Repair quote total = labour + parts only. The inspection fee is
          // never shown here — see file-level doc comment for why. Hidden
          // entirely in the sanitized bidder/hired-different-worker view.
          if (!report.isSanitized) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surfaceSubtle,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _summaryLine(
                    c,
                    context.l10n.inspFormPartsTotal,
                    report.partsTotal!,
                  ),
                  _summaryLine(
                    c,
                    context.l10n.inspFormLabour,
                    report.labourCost!,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.inspectionRepairQuoteTotal,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        formatPkr(report.repairQuoteTotal!),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: c.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (showDecisionButtons && isPending) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isDeciding
                    ? null
                    : () => _decide(context, ref, accept: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: c.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isDeciding
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.onPrimary,
                        ),
                      )
                    : Text(
                        context.l10n.inspectionAcceptQuoteContinue,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: isDeciding
                    ? null
                    : () => _findOtherUstaad(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.warning,
                  side: BorderSide(color: c.warning),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  context.l10n.inspectionFindOtherUstaad,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: isDeciding
                    ? null
                    : () => _decide(context, ref, accept: false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.primary,
                  side: BorderSide(color: c.primary),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  context.l10n.inspectionCloseAfterInspection,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    AppSemanticColors c,
    String label,
    String value, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontSize: 14, color: c.textPrimary, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(AppSemanticColors c, String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
          Text(
            formatPkr(value),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref, {
    required bool accept,
  }) async {
    final c = context.semanticColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          accept
              ? context.l10n.inspectionAcceptQuoteConfirmTitle
              : context.l10n.inspectionCloseConfirmTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          accept
              ? context.l10n.inspectionAcceptQuoteConfirmBody
              : context.l10n.inspectionCloseConfirmBody,
          style: TextStyle(color: c.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.l10n.commonCancel,
              style: TextStyle(color: c.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: c.onPrimary,
            ),
            child: Text(context.l10n.inspectionConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // Re-entry guard: the confirm dialog's async gap means a second tap
    // that raced the disabled button could reach here before this call's
    // own AsyncLoading state has rendered — never fire a duplicate decision.
    if (ref.read(inspectionDecisionNotifierProvider).isLoading) return;

    try {
      final notifier = ref.read(inspectionDecisionNotifierProvider.notifier);
      if (accept) {
        await notifier.acceptQuote(bookingId);
      } else {
        await notifier.closeAfterInspection(bookingId);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? context.l10n.inspectionQuoteAcceptedRepairInProgress
                  : context.l10n.inspectionClosedAfterInspection,
            ),
            backgroundColor: c.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failureMessage(
                context.l10n,
                e,
                fallback: context.l10n.inspectionActionFailed,
              ),
            ),
            backgroundColor: c.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _findOtherUstaad(BuildContext context, WidgetRef ref) async {
    final c = context.semanticColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          context.l10n.inspectionFindAnotherConfirmTitle,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        // Deliberately future tense: at this point the inspection booking is
        // still IN_PROGRESS, so the fee is NOT yet paid — confirming here is
        // what completes the inspection and makes it payable. Claiming
        // "already paid" here was factually wrong.
        content: Text(
          context.l10n.inspectionFindAnotherConfirmBody,
          style: TextStyle(color: c.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.l10n.commonCancel,
              style: TextStyle(color: c.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.warning,
              foregroundColor: c.onPrimary,
            ),
            child: Text(context.l10n.inspectionFindOtherUstaad),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // Re-entry guard: a second tap that raced past the disabled button (or a
    // second confirm dialog) must never fire a duplicate request. The
    // backend is idempotent regardless, but there's no reason to send it.
    if (ref.read(inspectionDecisionNotifierProvider).isLoading) return;

    final reviewController = ref.read(reviewPromptControllerProvider);

    // RESERVE BEFORE THE REQUEST. The backend's `booking.completed` push can
    // arrive before this call's HTTP response, so reserving afterwards would
    // still let the ordinary foreground review modal open first. Claiming the
    // guard up front means any such event finds this booking already active
    // and enqueues nothing.
    reviewController.reserveMandatory(bookingId);

    try {
      await ref
          .read(inspectionDecisionNotifierProvider.notifier)
          .findOtherUstaad(bookingId);
    } catch (e) {
      // The request that the reservation was guarding failed — release it so
      // the booking is not left permanently blocked.
      reviewController.releaseReservation(bookingId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failureMessage(
                context.l10n,
                e,
                fallback: context.l10n.inspectionActionFailed,
              ),
            ),
            backgroundColor: c.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    // findOtherUstaad's _run already pushed the (now completed) inspection
    // booking into bookingDetailProvider. The open repair is the LINKED child
    // booking — old-style records without a link fall back to the same
    // booking, which is itself still the open job there.
    final inspectionBooking = await ref.read(
      bookingDetailProvider(bookingId).future,
    );
    final repairBookingId = inspectionBooking.linkedRepairBookingId;
    if (!context.mounted) return;

    // This action completes the inspection work unit. Confirm the actual cash
    // paid before collecting its review; the backend is the sole authority
    // for settlement allocation and accepts full, partial, or zero cash.
    final cashConfirmation = await showCashPaymentConfirmationDialog(
      context,
      bookingId: inspectionBooking.id,
      expectedAmount: inspectionBooking.cashConfirmationPrice,
    );
    if (cashConfirmation == null || !context.mounted) return;

    // The review ALWAYS belongs to the original completed inspection booking,
    // never to the child repair booking.
    if (inspectionBooking.review == null) {
      if (!context.mounted) return;
      final submitted = await reviewController.showMandatory(
        context,
        inspectionBooking,
      );
      // Only a confirmed successful submission may proceed. A failed
      // submission leaves the modal open and never resolves this, so we
      // simply never get here — and definitely never navigate.
      if (!submitted) return;
    } else {
      // Already reviewed — nothing to collect, go straight through.
      reviewController.releaseReservation(bookingId);
    }

    if (!context.mounted) return;
    final biddingBooking = repairBookingId != null
        ? await ref.read(bookingDetailProvider(repairBookingId).future)
        : inspectionBooking;
    if (!context.mounted) return;

    // `pushReplacement` plus the awaited-review gate above means this can
    // only ever run once per successful decision.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WorkerDiscoveryMapPage(booking: biddingBooking),
      ),
    );
  }
}

class _DecisionBadge extends StatelessWidget {
  final InspectionDecisionStatus decisionStatus;

  /// The booking's own lifecycle state, when it is known. A finished booking
  /// outranks the inspection decision: the decision is a historical fact, the
  /// badge describes where the job is *now*.
  final BookingStatus? bookingStatus;

  const _DecisionBadge({required this.decisionStatus, this.bookingStatus});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final status = bookingStatus;
    // `tab` is the existing collapse of COMPLETED / AWAITING_CONFIRMATION /
    // SETTLED into one client-facing idea of "done" — reused rather than
    // re-derived, so this badge can never disagree with the Bookings list.
    if (status != null && status.tab == BookingTab.completed) {
      return _badge(
        bookingStatusLabel(context.l10n, status),
        c.successSoft,
        c.success,
        Icons.check_circle_rounded,
      );
    }
    // Same tint/foreground pairings [StatusBadge] uses, so a state named on
    // two screens is drawn the same way on both.
    final (text, background, foreground) = switch (decisionStatus) {
      InspectionDecisionStatus.pendingClientDecision => (
        context.l10n.inspectionBadgeAwaitingDecision,
        c.softTeal,
        c.primary,
      ),
      InspectionDecisionStatus.acceptedRepair => (
        context.l10n.inspectionBadgeQuoteAccepted,
        c.successSoft,
        c.success,
      ),
      InspectionDecisionStatus.closedAfterInspection => (
        context.l10n.trackStepClosedAfterInspection,
        c.softTeal,
        c.primary,
      ),
      InspectionDecisionStatus.findOtherUstaad => (
        context.l10n.inspectionBadgeFindingAnother,
        c.warningSurface,
        c.warning,
      ),
    };
    return _badge(
      text,
      background,
      foreground,
      Icons.assignment_turned_in_rounded,
    );
  }

  Widget _badge(
    String text,
    Color background,
    Color foreground,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: foreground),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}
