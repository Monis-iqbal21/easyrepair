import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../domain/entities/booking_entity.dart';
import '../widgets/client_cancel_reason_sheet.dart';
import '../widgets/client_chat_action.dart';
import '../widgets/media_attachment_widgets.dart';
import '../providers/booking_providers.dart';
import '../providers/review_prompt_controller.dart';
import '../widgets/inspection_badge.dart';
import '../widgets/inspection_report_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/urgency_badge.dart';
import '../utils/status_labels.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import 'choose_ustaad_page.dart';
import 'full_screen_map_page.dart';
import 'track_worker_page.dart';
import 'worker_discovery_map_page.dart';
import '../utils/booking_labels.dart';
import '../../../../core/errors/failure_messages.dart';

/// Statuses during which the client detail page polls GET /bookings/:id
/// every few seconds to reflect the worker's live progress/location.
const _kPollingStatuses = {
  BookingStatus.accepted,
  BookingStatus.enRoute,
  BookingStatus.arrived,
  BookingStatus.inProgress,
};

// ── Navigation helper ─────────────────────────────────────────────────────────

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/client/jobs');
  }
}

// ── Palette ───────────────────────────────────────────────────────────────────
const _kGreen  = Color(0xFFDB6234);
const _kDark   = Color(0xFF1A1A1A);
const _kGray   = Color(0xFF6B7280);
const _kLight  = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);
const _kBg     = Color(0xFFF9FAFB);

class BookingDetailPage extends ConsumerStatefulWidget {
  final String bookingId;

  const BookingDetailPage({super.key, required this.bookingId});

  @override
  ConsumerState<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends ConsumerState<BookingDetailPage> {
  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack(context);
      },
      child: Scaffold(
        backgroundColor: _kBg,
        body: bookingAsync.when(
          skipError: true,
          loading: () => _LoadingSkeleton(bookingId: widget.bookingId),
          error: (err, _) => _ErrorScreen(
            message: failureMessage(context.l10n, err, fallback: context.l10n.bookingLoadFailed),
            onRetry: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
          ),
          data: (booking) => _DetailBody(booking: booking),
        ),
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatefulWidget {
  final String bookingId;
  const _LoadingSkeleton({required this.bookingId});

  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => _goBack(context),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(width: 120, height: 14, shimmer: _shimmer.value),
                  const SizedBox(height: 4),
                  _ShimmerBox(width: 70, height: 10, shimmer: _shimmer.value),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: _kBorder),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  children: [
                    _skeletonCard(
                      _shimmer.value,
                      child: Row(
                        children: [
                          _ShimmerBox(width: 52, height: 52, radius: 14, shimmer: _shimmer.value),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ShimmerBox(width: double.infinity, height: 16, shimmer: _shimmer.value),
                                const SizedBox(height: 8),
                                _ShimmerBox(width: 120, height: 12, shimmer: _shimmer.value),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _skeletonCard(
                      _shimmer.value,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ShimmerBox(width: 100, height: 13, shimmer: _shimmer.value),
                          const SizedBox(height: 16),
                          for (int i = 0; i < 4; i++) ...[
                            Row(children: [
                              _ShimmerBox(width: 16, height: 16, radius: 4, shimmer: _shimmer.value),
                              const SizedBox(width: 10),
                              _ShimmerBox(width: 160, height: 12, shimmer: _shimmer.value),
                            ]),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _skeletonCard(
                      _shimmer.value,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ShimmerBox(width: 80, height: 13, shimmer: _shimmer.value),
                          const SizedBox(height: 16),
                          _ShimmerBox(width: double.infinity, height: 12, shimmer: _shimmer.value),
                          const SizedBox(height: 8),
                          _ShimmerBox(width: 140, height: 12, shimmer: _shimmer.value),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _skeletonCard(double shimmer, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: child,
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final double shimmer;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 6,
    required this.shimmer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(shimmer - 1, 0),
          end: Alignment(shimmer + 1, 0),
          colors: const [
            Color(0xFFE2E8F0),
            Color(0xFFF1F5F9),
            Color(0xFFE2E8F0),
          ],
        ),
      ),
    );
  }
}

// ── Main body ─────────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerStatefulWidget {
  final BookingEntity booking;

  const _DetailBody({required this.booking});

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  final _scrollCtrl = ScrollController();
  Timer? _pollTimer;

  // Guards the auto-popup so it fires at most once per booking per time it
  // becomes eligible (COMPLETED + no review yet, any lane) — reset whenever
  // the booking id changes so navigating between bookings re-arms it, but
  // never re-fires from an unrelated rebuild (polling, provider refresh...)
  // of the *same* booking.
  String? _reviewPromptedForBookingId;

  @override
  void initState() {
    super.initState();
    _syncPolling();
    _maybePromptReview();
  }

  @override
  void didUpdateWidget(covariant _DetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPolling();
    _maybePromptReview();
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
    _pollTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Asks the shared [ReviewPromptController] to prompt for this booking when
  /// it's COMPLETED and unreviewed — all lanes alike.
  ///
  /// Deliberately delegates rather than opening the modal itself: the
  /// foreground completion event, the notification tap and this page all
  /// funnel through one controller, so an app-level prompt and this
  /// page-level prompt can never both open for the same booking.
  void _maybePromptReview() {
    final eligible =
        booking.status == BookingStatus.completed && booking.review == null;
    if (!eligible) return;
    if (_reviewPromptedForBookingId == booking.id) return;
    _reviewPromptedForBookingId = booking.id;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openReviewModal();
    });
  }

  void _openReviewModal() {
    ref.read(reviewPromptControllerProvider).enqueueFront(context, booking.id);
  }

  BookingEntity get booking => widget.booking;

  @override
  Widget build(BuildContext context) {
    final isLive = booking.status.tab == BookingTab.live;
    final isCompleted = booking.status == BookingStatus.completed;
    final isCancelled = booking.status.tab == BookingTab.cancelled;
    final isExpired = booking.status == BookingStatus.expired;
    final isStandard = booking.lane == BookingLane.standard;
    final canEdit = booking.status == BookingStatus.pending &&
        booking.assignedWorker == null;

    return CustomScrollView(
      controller: _scrollCtrl,
      slivers: [
        _AppBar(booking: booking),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status card
                _StatusCard(booking: booking),
                const SizedBox(height: 16),

                // INSPECTION lane: lane-aware state strip (no bidding wording)
                InspectionStatusStrip(booking: booking),

                // Status timeline (when there's history to show)
                if (booking.statusHistory.isNotEmpty) ...[
                  _StatusTimelineCard(booking: booking),
                  const SizedBox(height: 16),
                ],

                // "View Inspection Report" opens the dedicated report page
                // (not shown inline here).
                //
                // The report belongs to the BOOKING, not to whoever is
                // currently hired, so this deliberately does not require an
                // assigned worker: after "Find Other Ustaad" the booking sits
                // unassigned while the client picks a replacement, and it used
                // to lose its report for that whole window. A linked repair
                // booking is BIDDING-lane with a sourceInspectionBookingId and
                // carries no report row of its own — the backend resolves it
                // back to the source inspection booking, so passing either id
                // works.
                //
                // Safe to offer unconditionally for these shapes: the button
                // renders nothing until a report actually exists.
                if (booking.hasInspectionReportToShow)
                  ViewInspectionReportButton(
                    bookingId: booking.id,
                    route: '/client/booking/${booking.id}/inspection-report',
                  ),

                // EXPIRED — "Make Live Again"
                if (isExpired) ...[
                  _MakeLiveAgainCard(bookingId: booking.id),
                  const SizedBox(height: 16),
                ],

                // Worker cancelled — reason strip (booking back in choose-worker state)
                if (!isExpired &&
                    booking.assignedWorker == null &&
                    booking.status == BookingStatus.pending &&
                    booking.lastWorkerCancellationReason != null &&
                    booking.lastWorkerCancellationReason!.isNotEmpty) ...[
                  _WorkerCancelledStrip(
                    reason: booking.lastWorkerCancellationReason!,
                    workerName: booking.lastWorkerCancellationWorkerName,
                  ),
                  const SizedBox(height: 16),
                ],

                // Worker cancelled this booking outright (terminal CANCELLED,
                // not the relist-to-PENDING case above) — show the reason and
                // let the client find another Ustaad for the same booking.
                if (booking.status == BookingStatus.cancelled &&
                    booking.cancelledByRole == CancelledByRole.worker) ...[
                  _WorkerCancelledBookingCard(booking: booking),
                  const SizedBox(height: 16),
                ],

                // STANDARD lane: selected services + total
                if (isStandard && booking.standardServiceItems.isNotEmpty) ...[
                  _StandardServicesCard(booking: booking),
                  const SizedBox(height: 16),
                ],

                // Service info
                _InfoCard(
                  title: context.l10n.bookingServiceDetails,
                  children: [
                    _InfoRow(
                      icon: Icons.build_circle_outlined,
                      label: context.l10n.postJobService,
                      value: '${booking.serviceEmoji}  ${booking.primaryServiceLabel}',
                    ),
                    if (booking.displayIssueTitle != null)
                      _InfoRow(
                        icon: Icons.title_rounded,
                        label: context.l10n.bookingIssue,
                        value: booking.displayIssueTitle!,
                      ),
                    if (booking.cleanDescription != null &&
                        booking.cleanDescription!.isNotEmpty)
                      _InfoRow(
                        icon: Icons.description_outlined,
                        label: context.l10n.postJobDescription,
                        value: booking.cleanDescription!,
                        multiline: true,
                      ),
                    _InfoRow(
                      icon: Icons.bolt_rounded,
                      label: context.l10n.bookingUrgency,
                      value: booking.urgency == BookingUrgency.urgent
                          ? context.l10n.postJobUrgent
                          : context.l10n.postJobNormal,
                    ),
                    _InfoRow(
                      icon: Icons.schedule_rounded,
                      label: context.l10n.bookingTiming,
                      value: booking.urgency == BookingUrgency.urgent
                          ? (urgentWindowLabel(context.l10n, booking.urgentWindow!) as String? ??
                              context.l10n.postJobUrgent)
                          : booking.scheduledDate != null
                              ? DateFormat('EEE, d MMM yyyy')
                                      .format(booking.scheduledDate!) +
                                  (booking.timeSlot != null
                                      ? ' \u2022 ${timeSlotLabel(context.l10n, booking.timeSlot!)}'
                                      : '')
                              : context.l10n.bookingNotScheduledYet,
                    ),
                    if (booking.timeSlot != null)
                      _InfoRow(
                        icon: Icons.access_time_rounded,
                        label: context.l10n.bookingTimeWindow,
                        value: timeSlotLabel(context.l10n, booking.timeSlot!),
                      ),
                    if (booking.scheduledDate != null)
                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: context.l10n.bookingScheduledDate,
                        value: DateFormat('EEE, d MMM yyyy')
                            .format(booking.scheduledDate!),
                      ),
                    _InfoRow(
                      icon: Icons.access_time_filled_rounded,
                      label: context.l10n.bookingCreated,
                      value: DateFormat('d MMM yyyy, h:mm a')
                          .format(booking.createdAt),
                    ),
                    if (isCompleted && booking.completedAt != null)
                      _InfoRow(
                        icon: Icons.check_circle_outline_rounded,
                        label: context.l10n.bookingStatusCompleted,
                        value: DateFormat('d MMM yyyy, h:mm a')
                            .format(booking.completedAt!),
                      ),
                    if (isCancelled &&
                        booking.cancellationReason != null &&
                        booking.cancellationReason!.isNotEmpty)
                      _InfoRow(
                        icon: Icons.cancel_outlined,
                        label: context.l10n.bookingCancellationReason,
                        value: booking.cancellationReason!,
                        multiline: true,
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Attachments (only if present)
                if (booking.attachments.isNotEmpty) ...[
                  _AttachmentsCard(attachments: booking.attachments),
                  const SizedBox(height: 16),
                ],

                // Location
                _LocationCard(booking: booking),
                const SizedBox(height: 16),

                // Inspection-fee status — driven solely by the ORIGINAL
                // inspection work unit reaching COMPLETED (see
                // inspectionFeeStatusLabel). Rendered independently of the
                // pricing card, which is hidden before an Ustaad is hired,
                // so the status is visible across the whole lifecycle. Shows
                // on the inspection booking AND on its linked repair booking.
                if (inspectionFeeStatusLabel(
                        context.l10n, booking.inspectionFeePaid) !=
                    null) ...[
                  _InspectionFeeStatusChip(
                    label: inspectionFeeStatusLabel(
                        context.l10n, booking.inspectionFeePaid)!,
                    paid: booking.inspectionFeePaid == true,
                  ),
                  const SizedBox(height: 16),
                ],

                // Pricing — hidden entirely for an open BIDDING job nobody
                // has been hired for yet (canonicalPrice is null there);
                // never shows Rs 0 or an "estimate".
                if (booking.canonicalPrice != null)
                  _PricingCard(booking: booking),

                // Worker section
                if (booking.assignedWorker != null) ...[
                  if (booking.canonicalPrice != null)
                    const SizedBox(height: 16),
                  // INSPECTION lane, "Find Other Ustaad" outcome where a
                  // DIFFERENT worker ended up hired than who inspected — show
                  // both, clearly labeled. Same worker still renders as one
                  // clean card below (no confusing duplicate).
                  if (booking.inspectingWorker != null &&
                      booking.inspectingWorker!.id != booking.assignedWorker!.id) ...[
                    _WorkerCard(
                      worker: booking.inspectingWorker!,
                      label: context.l10n.bookingInspectionCompletedBy,
                    ),
                    const SizedBox(height: 12),
                    _WorkerCard(
                      worker: booking.assignedWorker!,
                      label: context.l10n.bookingWorkBeingCompletedBy,
                    ),
                  ] else
                    _WorkerCard(
                      worker: booking.assignedWorker!,
                      label: booking.inspectingWorker != null
                          ? context.l10n.bookingInspectionAndRepairBy
                          : context.l10n.bookingAssignedWorker,
                    ),
                  const SizedBox(height: 16),
                  _WorkerMapSection(
                    worker: booking.assignedWorker!,
                    jobLat: booking.latitude,
                    jobLng: booking.longitude,
                    hasJobLocation: booking.hasLocation,
                  ),
                  if (!isCompleted && !isCancelled) ...[
                    const SizedBox(height: 16),
                    _TrackWorkerButton(bookingId: booking.id),
                  ],
                  if (isCompleted && booking.review == null) ...[
                    const SizedBox(height: 16),
                    _ReviewWorkerButton(onTap: _openReviewModal),
                  ],
                ] else if (booking.status == BookingStatus.pending &&
                    (booking.lane == BookingLane.bidding ||
                        booking.isOpenForFindOtherUstaadBidding)) ...[
                  const SizedBox(height: 16),
                  // Still no repair worker hired yet — the original
                  // inspector's card is shown pinned above the bids/offers
                  // entry point (see also worker_discovery_map_page.dart,
                  // which pins the same worker at the top of the list).
                  if (booking.isOpenForFindOtherUstaadBidding &&
                      booking.inspectingWorker != null) ...[
                    _WorkerCard(
                      worker: booking.inspectingWorker!,
                      label: context.l10n.bookingInspectionCompletedBy,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _ViewBidsButton(booking: booking),
                ] else if (booking.status == BookingStatus.pending &&
                    booking.lane != BookingLane.bidding &&
                    !booking.isOpenForFindOtherUstaadBidding &&
                    !isExpired) ...[
                  const SizedBox(height: 16),
                  _ChooseUstaadButton(booking: booking),
                ],
                const SizedBox(height: 16),

                // Submitted review (completed bookings only — the review
                // itself is collected via the auto-popup/manual ReviewModal,
                // not inline; this just displays it once submitted).
                if (isCompleted && booking.review != null) ...[
                  _SubmittedReviewCard(review: booking.review!),
                  const SizedBox(height: 16),
                ],

                // Action buttons
                _ActionButtons(
                  booking: booking,
                  canEdit: canEdit,
                  isLive: isLive,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  final BookingEntity booking;

  const _AppBar({required this.booking});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => _goBack(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.bookingDetailsTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _kDark,
            ),
          ),
          Text(
            booking.referenceId,
            style: const TextStyle(
              fontSize: 11,
              color: _kLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _kBorder),
      ),
    );
  }
}

// ── Status card ───────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final BookingEntity booking;

  const _StatusCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Center(
              child: Text(booking.serviceEmoji,
                  style: const TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.serviceCategory,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(status: booking.status),
                    UrgencyBadge(urgency: booking.urgency, small: true),
                    if (booking.inspection) const InspectionBadge(small: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Location card ─────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final BookingEntity booking;

  const _LocationCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final address = booking.address;
    final hasAddress = address != null && address.isNotEmpty;
    final hasCity = booking.city.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.postJobServiceAddress,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 12),
          // Address block with pin icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: _kGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasAddress ? address : context.l10n.bookingNoAddressProvided,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: hasAddress ? _kDark : _kGray,
                        height: 1.4,
                      ),
                    ),
                    if (hasCity) ...[
                      const SizedBox(height: 3),
                      Text(
                        booking.city,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kGray,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 12),
          ...children.map((child) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: child,
              )),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool multiline;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: _kLight),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: _kLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kDark,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Attachments card ──────────────────────────────────────────────────────────

class _AttachmentsCard extends StatelessWidget {
  final List<BookingAttachmentEntity> attachments;

  const _AttachmentsCard({required this.attachments});

  @override
  Widget build(BuildContext context) {
    final images = attachments.where((a) => a.type == AttachmentType.image).toList();
    final videos = attachments.where((a) => a.type == AttachmentType.video).toList();
    final audios = attachments.where((a) => a.type == AttachmentType.audio).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.bookingAttachments,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 14),

          // ── Images ──────────────────────────────────────────────────────
          if (images.isNotEmpty) ...[
            _attachmentSectionLabel(
              icon: Icons.image_outlined,
              label: context.l10n.bookingPhotosCount(images.length),
            ),
            const SizedBox(height: 10),
            BookingImageGrid(images: images),
          ],

          // ── Videos ──────────────────────────────────────────────────────
          if (videos.isNotEmpty) ...[
            if (images.isNotEmpty) const SizedBox(height: 14),
            _attachmentSectionLabel(
              icon: Icons.videocam_outlined,
              label: context.l10n.bookingVideosCount(videos.length),
            ),
            const SizedBox(height: 8),
            ...videos.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BookingVideoTile(attachment: v),
                )),
          ],

          // ── Audio ────────────────────────────────────────────────────────
          if (audios.isNotEmpty) ...[
            if (images.isNotEmpty || videos.isNotEmpty)
              const SizedBox(height: 14),
            _attachmentSectionLabel(
              icon: Icons.mic_none_rounded,
              label: context.l10n.bookingVoiceNote,
            ),
            const SizedBox(height: 8),
            ...audios.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BookingAudioPlayerCard(attachment: a),
                )),
          ],
        ],
      ),
    );
  }

  Widget _attachmentSectionLabel({
    required IconData icon,
    required String label,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _kLight),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _kGray,
          ),
        ),
      ],
    );
  }
}


// ── Pricing card ──────────────────────────────────────────────────────────────

class _PricingCard extends StatelessWidget {
  final BookingEntity booking;

  const _PricingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    // BookingEntity.displayPrice is the single source of truth for this
    // card and for Track Worker's hired-price pill — one label, one amount,
    // never a fee+work breakdown that double-counts a number already folded
    // into finalPrice. See its doc comment for the full precedence rule.
    final (label, amount) = booking.displayPrice;

    final labelText = switch (label) {
      DisplayPriceLabel.agreed => context.l10n.bookingAgreedPrice,
      DisplayPriceLabel.finalPrice => context.l10n.bookingFinalPrice,
      DisplayPriceLabel.inspectionFee => context.l10n.postJobInspectionFeeTitle,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.bookingPricing,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 12),
          if (amount != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  labelText,
                  style: TextStyle(fontSize: 13, color: _kGray),
                ),
                Text(
                  formatPkr(amount),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Small paid/not-paid chip shown wherever the inspection fee is relevant.
class _InspectionFeeStatusChip extends StatelessWidget {
  final String label;
  final bool paid;

  const _InspectionFeeStatusChip({required this.label, required this.paid});

  @override
  Widget build(BuildContext context) {
    final color = paid ? const Color(0xFF22C55E) : const Color(0xFFB45309);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(
            paid
                ? Icons.check_circle_outline_rounded
                : Icons.schedule_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Worker card ───────────────────────────────────────────────────────────────

class _WorkerCard extends StatelessWidget {
  final AssignedWorkerEntity worker;

  /// Null means "use the default heading", which is localized in [build].
  final String? label;

  const _WorkerCard({required this.worker, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label ?? context.l10n.bookingAssignedWorker,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: _kGreen,
                  shape: BoxShape.circle,
                ),
                child: worker.avatarUrl != null
                    ? ClipOval(
                        child: Image.network(
                          worker.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _InitialsText(worker.initials),
                        ),
                      )
                    : _InitialsText(worker.initials),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.fullName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kDark,
                      ),
                    ),
                    if (worker.rating != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 3),
                          Text(
                            worker.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _kGray,
                            ),
                          ),
                          const Text(
                            ' / 5.0',
                            style:
                                TextStyle(fontSize: 11, color: _kLight),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InitialsText extends StatelessWidget {
  final String initials;
  const _InitialsText(this.initials);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Worker map section ────────────────────────────────────────────────────────

class _WorkerMapSection extends StatefulWidget {
  final AssignedWorkerEntity worker;
  final double jobLat;
  final double jobLng;

  /// Whether the booking genuinely has coordinates — computed from the raw
  /// API payload, never from a `lat != 0` sentinel (see
  /// BookingEntity.hasLocation).
  final bool hasJobLocation;

  const _WorkerMapSection({
    required this.worker,
    required this.jobLat,
    required this.jobLng,
    required this.hasJobLocation,
  });

  @override
  State<_WorkerMapSection> createState() => _WorkerMapSectionState();
}

class _WorkerMapSectionState extends State<_WorkerMapSection> {
  /// Live marker set, shared with the full-screen page so the Ustaad's
  /// position keeps updating while it is open.
  final _markers = ValueNotifier<Set<Marker>>(<Marker>{});

  @override
  void initState() {
    super.initState();
    _rebuildMarkers();
  }

  @override
  void didUpdateWidget(covariant _WorkerMapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rebuildMarkers();
  }

  @override
  void dispose() {
    _markers.dispose();
    super.dispose();
  }

  void _rebuildMarkers() {
    final next = <Marker>{};
    if (widget.hasJobLocation) {
      next.add(
        Marker(
          markerId: const MarkerId('job'),
          position: LatLng(widget.jobLat, widget.jobLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: context.l10n.bookingJobLocation),
        ),
      );
    }
    final w = widget.worker;
    if (w.currentLat != null && w.currentLng != null) {
      next.add(
        Marker(
          markerId: const MarkerId('worker'),
          position: LatLng(w.currentLat!, w.currentLng!),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: w.fullName),
        ),
      );
    }
    _markers.value = next;
  }

  LatLng get _cameraTarget => widget.hasJobLocation
      ? LatLng(widget.jobLat, widget.jobLng)
      : LatLng(widget.worker.currentLat!, widget.worker.currentLng!);

  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullScreenMapPage(
          title: context.l10n.bookingLiveLocation,
          markersListenable: _markers,
          initialTarget: _cameraTarget,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final worker = widget.worker;
    final jobLat = widget.jobLat;
    final jobLng = widget.jobLng;
    final hasLocation = worker.currentLat != null && worker.currentLng != null;

    // The map is showable whenever we have SOMETHING real to point at. It no
    // longer depends on a --dart-define key: the GoogleMap SDK is keyed from
    // AndroidManifest (via Gradle), the same path every other map in the app
    // already uses successfully. The previous Static Maps image needed a
    // separately-enabled API plus its own dart-define, and its errorBuilder
    // collapsed every failure into "Map preview unavailable".
    final canShowMap = hasLocation || widget.hasJobLocation;

    final distanceM = hasLocation && widget.hasJobLocation
        ? haversineDistanceMeters(
            worker.currentLat!, worker.currentLng!, jobLat, jobLng)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 16, 14),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.bookingLiveLocation,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasLocation
                          ? context.l10n.bookingTrackingWorker(
                              worker.fullName.split(' ').first,
                            )
                          : context.l10n.bookingWaitingForWorkerLocation,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _kLight,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (hasLocation) _LiveBadge(),
              ],
            ),
          ),

          // ── Map or Fallback ────────────────────────────────────────────────
          if (canShowMap)
            SizedBox(
              height: 190,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ValueListenableBuilder<Set<Marker>>(
                      valueListenable: _markers,
                      builder: (context, markers, _) => GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _cameraTarget,
                          zoom: 14,
                        ),
                        markers: markers,
                        // Inline preview: tap-to-expand rather than a
                        // gesture-capturing mini map inside a scroll view.
                        zoomControlsEnabled: false,
                        zoomGesturesEnabled: false,
                        scrollGesturesEnabled: false,
                        rotateGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                        myLocationButtonEnabled: false,
                        mapToolbarEnabled: false,
                        liteModeEnabled: true,
                      ),
                    ),
                  ),
                  // Bottom-RIGHT so it never covers Google's mandatory
                  // attribution (bottom-left).
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: MapExpandButton(onTap: _openFullScreen),
                  ),
                ],
              ),
            )
          else
            // Only reachable when neither the booking nor the worker has any
            // real coordinates — a genuine absence, not a config problem.
            _MapFallback(hasLocation: hasLocation),

          // ── Distance bar ──────────────────────────────────────────────────
          if (hasLocation && distanceM != null)
            _DistanceBar(distanceM: distanceM)
          else if (!hasLocation)
            Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Text(
                context.l10n.bookingLiveLocationNotAvailable,
                style: TextStyle(
                  fontSize: 12,
                  color: _kLight,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Live badge ────────────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD0B5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: _kGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            context.l10n.bookingStatusLive,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kGreen,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Static map ────────────────────────────────────────────────────────────────

class _MapFallback extends StatelessWidget {
  final bool hasLocation;

  const _MapFallback({required this.hasLocation});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      width: double.infinity,
      color: const Color(0xFFF9FAFB),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasLocation
                  ? Icons.map_outlined
                  : Icons.location_searching_rounded,
              size: 22,
              color: const Color(0xFF93C5FD),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasLocation ? context.l10n.bookingMapPreviewUnavailable : context.l10n.bookingLocationPending,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kGray,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            hasLocation
                ? context.l10n.bookingMapImageLoadFailed
                : context.l10n.bookingAppearsWhenEnRoute,
            style: const TextStyle(fontSize: 11.5, color: _kLight),
          ),
        ],
      ),
    );
  }
}

// ── Distance bar ──────────────────────────────────────────────────────────────

class _DistanceBar extends StatelessWidget {
  final double distanceM;

  const _DistanceBar({required this.distanceM});

  @override
  Widget build(BuildContext context) {
    final label = formatDistanceLabel(context.l10n, distanceM);
    final isClose = distanceM < 300;

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Row(
        children: [
          // Icon circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isClose
                  ? Icons.directions_walk_rounded
                  : Icons.directions_car_rounded,
              size: 18,
              color: _kGreen,
            ),
          ),
          const SizedBox(width: 12),
          // Distance text
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kDark,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                isClose ? context.l10n.bookingWorkerNearlyThere : context.l10n.bookingWorkerOnTheWay,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: _kLight,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Updated hint
          Text(
            context.l10n.bookingLiveUpdatedNow,
            style: TextStyle(
              fontSize: 10.5,
              color: _kLight,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status timeline card ──────────────────────────────────────────────────────

class _StatusTimelineCard extends StatelessWidget {
  final BookingEntity booking;
  const _StatusTimelineCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final history = booking.statusHistory;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.bookingStatusTimeline,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kDark),
          ),
          const SizedBox(height: 14),
          ...history.asMap().entries.map((e) {
            final isLast = e.key == history.length - 1;
            final entry = e.value;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(
                        color: isLast ? _kGreen : _kLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast) Container(width: 1, height: 28, color: _kBorder),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bookingStatusLabel(context.l10n, entry.status),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isLast ? _kGreen : _kDark,
                          ),
                        ),
                        if (entry.note != null && entry.note!.isNotEmpty)
                          Text(
                            entry.note!,
                            style: const TextStyle(fontSize: 11.5, color: _kGray),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          DateFormat('d MMM, h:mm a').format(entry.createdAt),
                          style: const TextStyle(fontSize: 11, color: _kLight),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Make Live Again card (EXPIRED bookings) ───────────────────────────────────

class _MakeLiveAgainCard extends ConsumerWidget {
  final String bookingId;
  const _MakeLiveAgainCard({required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(relistBookingNotifierProvider).isLoading;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_bottom_rounded, size: 18, color: Color(0xFFEA580C)),
              SizedBox(width: 8),
              Text(
                context.l10n.bookingJobExpired,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFEA580C)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.bookingExpiredExplanation,
            style: TextStyle(fontSize: 12.5, color: _kGray, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      try {
                        await ref
                            .read(relistBookingNotifierProvider.notifier)
                            .relist(bookingId);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                failureMessage(context.l10n, e, fallback: context.l10n.bookingMakeLiveFailed),
                              ),
                              backgroundColor: const Color(0xFFDC2626),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      context.l10n.bookingMakeLiveAgain,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Worker cancelled strip ────────────────────────────────────────────────────

class _WorkerCancelledStrip extends StatelessWidget {
  final String reason;
  final String? workerName;
  const _WorkerCancelledStrip({required this.reason, this.workerName});

  @override
  Widget build(BuildContext context) {
    final title = workerName != null && workerName!.isNotEmpty
        ? context.l10n.bookingPreviousUstaadCancelledNamed(workerName!)
        : context.l10n.bookingPreviousUstaadCancelled;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFBE123C)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFBE123C),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  reason,
                  style: const TextStyle(fontSize: 12.5, color: _kGray, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Worker cancelled this booking outright (terminal CANCELLED) ─────────────

class _WorkerCancelledBookingCard extends ConsumerWidget {
  final BookingEntity booking;
  const _WorkerCancelledBookingCard({required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading =
        ref.watch(reopenAfterWorkerCancellationNotifierProvider).isLoading;
    final reason = booking.cancellationReason;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFBE123C)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.bookingUstaadCancelledJob,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFBE123C),
                  ),
                ),
              ),
            ],
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              context.l10n.bookingReasonPrefix(reason),
              style: const TextStyle(fontSize: 12.5, color: _kGray, height: 1.4),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      try {
                        final updated = await ref
                            .read(
                              reopenAfterWorkerCancellationNotifierProvider
                                  .notifier,
                            )
                            .reopen(booking.id);
                        if (context.mounted) {
                          // Same lane/report-state routing rule used
                          // elsewhere on this page (_ViewBidsButton vs.
                          // _ChooseUstaadButton): BIDDING, or a reopened
                          // INSPECTION with an existing report, goes to the
                          // bids/find-workers flow; STANDARD (and
                          // INSPECTION with no report yet) goes to the
                          // normal nearby-worker hire flow.
                          final useBiddingFlow = updated.lane ==
                                  BookingLane.bidding ||
                              updated.isOpenForFindOtherUstaadBidding;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => useBiddingFlow
                                  ? WorkerDiscoveryMapPage(booking: updated)
                                  : ChooseUstaadPage(booking: updated),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                failureMessage(context.l10n, e, fallback: context.l10n.bookingFindAnotherUstaadFailed),
                              ),
                              backgroundColor: const Color(0xFFDC2626),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBE123C),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      context.l10n.bookingFindAnotherUstaad,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Standard services card ────────────────────────────────────────────────────

class _StandardServicesCard extends StatelessWidget {
  final BookingEntity booking;
  const _StandardServicesCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.bookingSelectedServices,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kDark),
          ),
          const SizedBox(height: 12),
          ...booking.standardServiceItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.quantity > 1
                          ? context.l10n.bookingServiceQuantity(item.nameSnapshot, item.quantity)
                          : item.nameSnapshot,
                      style: const TextStyle(fontSize: 13.5, color: _kDark),
                    ),
                  ),
                  Text(
                    formatPkr(item.lineTotal),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _kDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 20, color: _kBorder),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.postJobTotal,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kDark),
                ),
              ),
              Text(
                formatPkr(booking.finalPrice ?? booking.standardServicesTotal ?? 0),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _kGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Choose Ustaad button (STANDARD/INSPECTION, no worker yet) ────────────────

class _ChooseUstaadButton extends StatelessWidget {
  final BookingEntity booking;
  const _ChooseUstaadButton({required this.booking});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChooseUstaadPage(booking: booking),
        ),
      ),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: _kGreen,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 16, color: Colors.white),
            SizedBox(width: 8),
            Text(
              context.l10n.bookingChooseUstaad,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── View bids button ──────────────────────────────────────────────────────────

class _ViewBidsButton extends StatelessWidget {
  final BookingEntity booking;
  const _ViewBidsButton({required this.booking});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkerDiscoveryMapPage(booking: booking),
        ),
      ),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: _kGreen,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gavel_rounded, size: 16, color: Colors.white),
            SizedBox(width: 8),
            Text(
              context.l10n.bookingSeeWorkerBids,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Track worker button ───────────────────────────────────────────────────────

class _TrackWorkerButton extends StatelessWidget {
  final String bookingId;
  const _TrackWorkerButton({required this.bookingId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TrackWorkerPage(bookingId: bookingId),
        ),
      ),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: _kGreen,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on_rounded, size: 16, color: Colors.white),
            SizedBox(width: 8),
            Text(
              context.l10n.bookingTrackWorker,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Review worker button ──────────────────────────────────────────────────────

class _ReviewWorkerButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ReviewWorkerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: _kGreen,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_outline_rounded, size: 16, color: Colors.white),
            SizedBox(width: 8),
            Text(
              context.l10n.bookingReviewWorker,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Submitted review display (read-only, once a review exists) ───────────────

class _SubmittedReviewCard extends StatelessWidget {
  final BookingReviewEntity review;

  const _SubmittedReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Text(
                context.l10n.bookingYourReview,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                Icons.star_rounded,
                size: 22,
                color: i < review.rating
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: const TextStyle(
                fontSize: 13,
                color: _kGray,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            DateFormat('d MMM yyyy').format(review.createdAt),
            style: const TextStyle(fontSize: 11, color: _kLight),
          ),
        ],
      ),
    );
  }
}

// ── Review modal (auto-popup on completion + manual "Review Worker") ─────────

/// Popup shown automatically once a booking (any lane) completes with no
/// review yet, and reachable manually via the "Review Worker" button for
/// any completed booking. Submits through the existing [reviewNotifierProvider]
/// / review API — no new backend surface.
// ── Action buttons ────────────────────────────────────────────────────────────

class _ActionButtons extends ConsumerWidget {
  final BookingEntity booking;
  final bool canEdit;
  final bool isLive;

  const _ActionButtons({
    required this.booking,
    required this.canEdit,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCancel = booking.canClientCancel;
    final showChat = booking.assignedWorker != null;

    final showCall = booking.assignedWorker?.phone != null &&
        booking.assignedWorker!.phone!.isNotEmpty;

    if (!canEdit && !showCancel && !showChat) return const SizedBox.shrink();

    return Column(
      children: [
        if (showCall) ...[
          _FullBtn(
            label: context.l10n.bookingCallWorker,
            icon: Icons.call_rounded,
            color: _kGreen,
            bgColor: const Color(0xFFFFF0EB),
            onTap: () => _callWorker(booking.assignedWorker!.phone!),
          ),
          const SizedBox(height: 10),
        ],
        if (showChat)
          _ChatWithWorkerButton(
            bookingId: booking.id,
            workerProfileId: booking.assignedWorker!.id,
          ),
        if (showChat && (canEdit || showCancel)) const SizedBox(height: 10),
        if (canEdit)
          _FullBtn(
            label: context.l10n.postJobEditBooking,
            icon: Icons.edit_outlined,
            color: const Color(0xFF1A1A1A),
            bgColor: const Color(0xFFF1F5F9),
            onTap: () => context.push(
              '/client/post-job?editId=${booking.id}',
            ),
          ),
        if (canEdit && showCancel) const SizedBox(height: 10),
        if (showCancel)
          _FullBtn(
            label: context.l10n.bookingCancelBooking,
            icon: Icons.close_rounded,
            color: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFFF1F2),
            onTap: () => _confirmCancel(context, ref),
          ),
      ],
    );
  }

  Future<void> _callWorker(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Opens the shared Roman Urdu cancellation-reason modal.
  ///
  /// Cancellation ELIGIBILITY is unchanged and decided by the caller
  /// (`booking.canClientCancel`); this only collects the reason.
  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    await showClientCancelReasonSheet(
      context: context,
      hasAssignedWorker: booking.assignedWorker != null,
      onSubmit: (reason) => ref
          .read(bookingsNotifierProvider.notifier)
          .cancelBooking(booking.id, reason),
    ).then((reason) {
      if (reason == null || !context.mounted) return;
      context.pop();
    }).catchError((Object e) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failureMessage(context.l10n, e, fallback: context.l10n.bookingCancelFailed),
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return null;
    });
  }
}

class _FullBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _FullBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Chat with Worker" action — same visual shape as [_FullBtn] but with its
/// own in-flight guard so a rapid double-tap can't fire a second
/// get-or-create request (mirrors _ChatButton in worker_discovery_map_page).
/// Client-facing endpoint (workerProfileId-based) — has no booking-status
/// restriction, so this still works after the job is COMPLETED, unlike the
/// worker-only "for-booking" endpoint.
class _ChatWithWorkerButton extends ConsumerStatefulWidget {
  final String bookingId;
  final String workerProfileId;

  const _ChatWithWorkerButton({
    required this.bookingId,
    required this.workerProfileId,
  });

  @override
  ConsumerState<_ChatWithWorkerButton> createState() =>
      _ChatWithWorkerButtonState();
}

class _ChatWithWorkerButtonState extends ConsumerState<_ChatWithWorkerButton> {
  bool _loading = false;

  Future<void> _openChat() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await openClientChatWithWorker(
        context,
        ref,
        widget.bookingId,
        widget.workerProfileId,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loading ? null : _openChat,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0EB),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_kGreen),
                ),
              )
            else
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 16,
                color: _kGreen,
              ),
            const SizedBox(width: 8),
            Text(
              context.l10n.bookingChatWithWorker,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error screen ──────────────────────────────────────────────────────────────

class _ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorScreen({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => _goBack(context),
        ),
        title: Text(
          context.l10n.bookingDetailsTitle,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _kDark,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('\u26a0\ufe0f', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 16),
              Text(
                context.l10n.bookingLoadFailedShort,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, color: _kLight, height: 1.4),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: _kDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    context.l10n.commonRetry,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
