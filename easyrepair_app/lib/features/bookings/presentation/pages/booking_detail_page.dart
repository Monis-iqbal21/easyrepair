import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/network/offline_banner.dart';
import '../../../../core/network/reconnect_refresh.dart';
import '../../../../core/presentation/widgets/resource_unavailable_view.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../complaints/presentation/providers/complaint_providers.dart';
import '../../../complaints/presentation/widgets/booking_complaint_section.dart';
import '../../domain/entities/booking_entity.dart';
import '../providers/booking_providers.dart';
import '../utils/booking_payment_presentation.dart';
import '../widgets/detail/booking_action_section.dart';
import '../widgets/detail/booking_attachments_section.dart';
import '../widgets/detail/booking_completion_section.dart';
import '../widgets/detail/booking_detail_primitives.dart';
import '../widgets/detail/booking_detail_summary.dart';
import '../widgets/detail/booking_lane_sections.dart';
import '../widgets/detail/booking_location_section.dart';
import '../widgets/detail/booking_payment_section.dart';
import '../widgets/detail/booking_status_history_section.dart';
import '../widgets/detail/booking_worker_card.dart';
import '../widgets/cash_payment_confirmation_card.dart';
import '../widgets/inspection_report_card.dart';

/// Statuses during which the client detail page polls GET /bookings/:id every
/// few seconds to reflect the worker's live progress.
const _kPollingStatuses = {
  BookingStatus.accepted,
  BookingStatus.enRoute,
  BookingStatus.arrived,
  BookingStatus.inProgress,
};

/// Vertical rhythm between top-level sections.
const _kSectionGap = 14.0;

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/client/jobs');
  }
}

/// The ONE Client Booking Detail page, shared by STANDARD, INSPECTION and
/// BIDDING.
///
/// The shell — app bar, report banner, summary, worker, actions, attachments,
/// location, completion/payment — is identical for all three lanes. Only
/// [BookingLaneSection] and a small number of INSPECTION-specific strips
/// differ, because only those describe something the lanes genuinely do
/// differently.
///
/// There is deliberately no map here: live tracking lives on the Track Ustaad
/// page, reachable from the action section.
class BookingDetailPage extends ConsumerWidget {
  final String bookingId;

  const BookingDetailPage({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reconnecting while the user is sitting on this nested page must refresh
    // the booking WITHOUT moving them: only this booking's provider is
    // invalidated, so the route stays /client/booking/<id>.
    refreshOnReconnect(ref, () {
      ref.invalidate(bookingDetailProvider(bookingId));
      // The report's status is changed by Admin, never by this device, so a
      // reconnect must re-read it too — otherwise "Your report" keeps showing
      // whatever it said before the connection dropped.
      ref.invalidate(bookingComplaintProvider(bookingId));
    });

    final bookingAsync = ref.watch(bookingDetailProvider(bookingId));
    final isShowingCachedData =
        ref.watch(bookingDetailIsOfflineProvider(bookingId)) &&
        bookingAsync.hasValue;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack(context);
      },
      child: Scaffold(
        backgroundColor: context.semanticColors.background,
        appBar: _buildAppBar(context, bookingAsync.valueOrNull),
        body: bookingAsync.when(
          skipError: true,
          loading: () => const _LoadingView(),
          error: (err, _) => isResourceUnavailableFailure(err)
              ? ResourceUnavailableView(
                  message: context.l10n.resourceBookingUnavailable,
                  actionLabel: context.l10n.goToMyBookingsAction,
                  onAction: () => _goBack(context),
                )
              : _ErrorView(
                  message: failureMessage(
                    context.l10n,
                    err,
                    fallback: context.l10n.bookingLoadFailed,
                  ),
                  onRetry: () =>
                      ref.invalidate(bookingDetailProvider(bookingId)),
                ),
          data: (booking) {
            final user = ref.read(authStateProvider).valueOrNull;
            if (!isShowingCachedData && user != null && !user.isWorker) {
              scheduleAutomaticCashPaymentPrompt(context, ref, booking);
            }
            return Column(
              children: [
                if (isShowingCachedData) const OfflineDataBanner(),
                Expanded(child: _DetailBody(booking: booking)),
              ],
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    BookingEntity? booking,
  ) {
    final colors = context.semanticColors;
    return AppBar(
      backgroundColor: colors.surface,
      surfaceTintColor: colors.surface,
      foregroundColor: colors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => _goBack(context),
      ),
      title: Text(
        context.l10n.bookingDetailsTitle,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: colors.border),
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  final BookingEntity booking;

  const _DetailBody({required this.booking});

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody>
    with WidgetsBindingObserver {
  Timer? _pollTimer;

  BookingEntity get booking => widget.booking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncPolling();
  }

  /// Resume refresh. The 6s poll below only runs while a job is actively in
  /// progress, so a COMPLETED booking — the only kind that can carry a report
  /// — refetches nothing on its own. Admin can resolve or close that report
  /// while the app is backgrounded and the push can be missed entirely, so
  /// coming back to the foreground re-reads the authoritative state.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed || !mounted) return;
    ref.invalidate(bookingDetailProvider(widget.booking.id));
    ref.invalidate(bookingComplaintProvider(widget.booking.id));
  }

  @override
  void didUpdateWidget(covariant _DetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPolling();
  }

  void _syncPolling() {
    final shouldPoll = _kPollingStatuses.contains(booking.status);
    if (shouldPoll && _pollTimer == null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (mounted) ref.invalidate(bookingDetailProvider(widget.booking.id));
      });
    } else if (!shouldPoll && _pollTimer != null) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final signedInUser = ref.watch(authStateProvider).valueOrNull;
    final isClient = signedInUser != null && !signedInUser.isWorker;

    // The page decides its own layout: every section below is added only when
    // it will actually render something, so a hidden section never leaves a
    // phantom gap. The two genuinely asynchronous sections (report status,
    // inspection report link) are resolved here too, by watching the same
    // providers their widgets do.
    final complaint = isClient
        ? ref.watch(bookingComplaintProvider(booking.id)).valueOrNull
        : null;
    final hasInspectionReport =
        booking.hasInspectionReportToShow &&
        ref.watch(inspectionReportProvider(booking.id)).hasValue;

    final worker = booking.assignedWorker;
    final inspector = booking.inspectingWorker;
    final hasDistinctInspector =
        inspector != null && (worker == null || inspector.id != worker.id);

    final previousCancellationReason = booking.lastWorkerCancellationReason
        ?.trim();

    final sections = <Widget>[
      // 1. Existing report status, right where the client looks first after
      //    raising one. Compact — the full report lives once, at the bottom.
      if (complaint != null)
        BookingComplaintStatusBanner(
          bookingId: booking.id,
          isClient: isClient,
          ownsBooking: true,
        ),

      // 2. Summary — reference, lane, status, urgency, ONE schedule, ONE
      //    authoritative price.
      BookingDetailSummary(booking: booking),

      // 3. Terminal / attention states. COMPLETED is the whole story: the job
      //    is closed the moment the backend says so, regardless of review,
      //    report, payment or whether the client has been away and come back.
      if (booking.status == BookingStatus.completed)
        const BookingClosedBanner(),
      if (booking.status == BookingStatus.expired)
        BookingExpiredSection(bookingId: booking.id),
      if (booking.status == BookingStatus.cancelled &&
          booking.cancelledByRole == CancelledByRole.worker)
        BookingWorkerCancelledSection(booking: booking),
      if (BookingCancelledNotice.hasContentFor(booking))
        BookingCancelledNotice(booking: booking),
      if (booking.status == BookingStatus.pending &&
          worker == null &&
          previousCancellationReason != null &&
          previousCancellationReason.isNotEmpty)
        BookingPreviousUstaadCancelledNotice(
          reason: previousCancellationReason,
          workerName: booking.lastWorkerCancellationWorkerName,
        ),

      // 4. INSPECTION-lane state and fee — the only strips no other lane has.
      if (InspectionStatusStrip.hasContentFor(booking))
        InspectionStatusStrip(booking: booking),
      if (BookingInspectionFeeChip.hasContentFor(booking))
        BookingInspectionFeeChip(booking: booking),

      // 5. Lane-specific job information.
      if (BookingLaneSection.hasContentFor(booking))
        BookingLaneSection(booking: booking),

      // 6. Hired Ustaad — Call and Chat live inside this card, not in a
      //    separate bottom action bar.
      if (worker != null)
        BookingWorkerCard(
          worker: worker,
          bookingId: booking.id,
          heading: hasDistinctInspector
              ? l10n.bookingWorkBeingCompletedBy
              : inspector != null
              ? l10n.bookingInspectionAndRepairBy
              : l10n.bookingAssignedWorker,
        ),
      // The inspector, when someone else is doing the repair (or nobody is
      // hired yet). One compact row — never a second full worker card.
      if (hasDistinctInspector)
        BookingInspectorRow(
          inspector: inspector,
          label: l10n.bookingInspectionCompletedBy,
        ),

      // 7. Backend-recorded status history. This is the client's single
      //    lifecycle history; do not duplicate it with a separate timeline.
      if (booking.statusHistory.isNotEmpty)
        BookingStatusHistorySection(history: booking.statusHistory),

      // 8. Inspection report entry point, then current actions. The report
      //    belongs to the BOOKING, so it survives "Find Other Ustaad" and any
      //    number of re-hires, including the window with nobody assigned.
      if (hasInspectionReport)
        ViewInspectionReportButton(
          bookingId: booking.id,
          route: BookingActionSection.inspectionReportRoute(booking),
        ),
      if (BookingActionSection.hasContentFor(booking))
        BookingActionSection(booking: booking),

      // 9. What the client attached.
      if (booking.attachments.isNotEmpty)
        BookingAttachmentsSection(attachments: booking.attachments),

      // 10. Job location — text only, no map.
      BookingLocationSection(booking: booking),

      // 11. Money, then review, then report.
      if (shouldShowBookingPayment(booking))
        BookingPaymentSection(booking: booking),
      if (booking.review != null)
        BookingSubmittedReviewCard(review: booking.review!)
      else if (booking.canClientReview)
        BookingReviewAction(booking: booking),
      if (isClient &&
          (complaint != null || booking.status == BookingStatus.completed))
        BookingComplaintSection(
          bookingId: booking.id,
          bookingStatus: booking.status,
          isClient: isClient,
          ownsBooking: true,
        ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: sections.length,
      separatorBuilder: (_, _) => const SizedBox(height: _kSectionGap),
      itemBuilder: (_, index) => sections[index],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        for (final height in const [168.0, 120.0, 96.0, 140.0])
          Padding(
            padding: const EdgeInsets.only(bottom: _kSectionGap),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: colors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            BookingSecondaryButton(
              label: context.l10n.commonRetry,
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
