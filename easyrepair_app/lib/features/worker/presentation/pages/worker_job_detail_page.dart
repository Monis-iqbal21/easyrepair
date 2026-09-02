import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/offline_banner.dart';
import '../../../../core/presentation/widgets/resource_unavailable_view.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../../bookings/presentation/providers/booking_providers.dart';
import '../../../bookings/presentation/widgets/inspection_badge.dart';
import '../../../bookings/presentation/widgets/inspection_report_card.dart';
import '../../../bookings/presentation/widgets/media_attachment_widgets.dart';
import '../../../../core/network/reconnect_refresh.dart';
import '../providers/worker_job_providers.dart';
import '../providers/worker_providers.dart';
import '../widgets/onboarding_gate.dart';
import '../widgets/worker_payment_section.dart';
import '../widgets/worker_chat_action.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../bookings/presentation/utils/status_labels.dart';
import '../utils/worker_status_labels.dart';
import '../../../bookings/presentation/utils/booking_labels.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/theme/app_semantic_colors.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
//
// There isn't one. Every colour on this screen comes from
// `context.semanticColors` — see `core/theme/app_semantic_colors.dart`.
//
// What used to live here, and what each became:
//
//   c.primary  #DB6234 -> c.primary        EasyRepair's orange. It was named
//                                        "green", and is absent from the
//                                        Ustaad prototype entirely.
//   c.textPrimary   #1A1A1A -> c.textPrimary
//   c.textSecondary   #6B7280 -> c.textSecondary
//   c.textSecondary  #94A3B8 -> c.textSecondary  the palette has two greys, not three.
//   c.border #E2E8F0 -> c.border
//   c.background     #F9FAFB -> c.background
//   c.error    #EF4444 -> c.error
//
// This pass changes COLOUR ONLY. Nothing was reordered, no widget moved, and
// no provider, API call, navigation target or condition was touched.

/// Shape values shared with Home, New Jobs and My Reviews.
const double _rCard = 16; // prototype `.crd`
const double _rButton = 14; // prototype `.btnp`
const double _rPill = 999; // prototype `.tg` / `.av`
const double _hButton = 52; // prototype `.btnp` min-height

/// First letters of a client's name, for the live-job card's avatar.
String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final letters = parts.take(2).map((w) => w[0]).join().toUpperCase();
  return letters.isEmpty ? '—' : letters;
}

// ── Navigation helper ─────────────────────────────────────────────────────────

void _goBackOrHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/worker/home');
  }
}

class WorkerJobDetailPage extends ConsumerWidget {
  final String jobId;

  /// When true, opens the in-app full-screen job map as soon as the booking
  /// loads — used by the worker home page's active-job-card "Map" button.
  final bool openMapOnLoad;

  const WorkerJobDetailPage({
    super.key,
    required this.jobId,
    this.openMapOnLoad = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    debugPrint('[WorkerJobDetailPage] build — jobId received=$jobId');
    // Reconnecting on this nested page refreshes the job in place — only
    // this job's data provider is invalidated, so the Ustaad stays on
    // /worker/job/<id> instead of being bounced anywhere.
    refreshOnReconnect(
      ref,
      () => ref.invalidate(workerJobDetailProvider(jobId)),
    );
    final jobAsync = ref.watch(workerJobDetailProvider(jobId));
    final isShowingCachedData =
        ref.watch(workerJobDetailIsOfflineProvider(jobId)) && jobAsync.hasValue;

    return Scaffold(
      backgroundColor: c.background,
      appBar: _AppBar(),
      body: jobAsync.when(
        skipError: true,
        loading: () =>
            Center(child: CircularProgressIndicator(color: c.primary)),
        error: (err, _) => isResourceUnavailableFailure(err)
            ? ResourceUnavailableView(
                message: context.l10n.resourceJobUnavailable,
                actionLabel: context.l10n.goToMyJobsAction,
                onAction: () => context.go('/worker/jobs'),
              )
            : _ErrorScreen(
                message: failureMessage(
                  context.l10n,
                  err,
                  fallback: context.l10n.workerJobLoadFailed,
                ),
                onRetry: () => ref.invalidate(workerJobDetailProvider(jobId)),
              ),
        data: (job) => Column(
          children: [
            if (isShowingCachedData) const OfflineDataBanner(),
            Expanded(
              child: _JobBody(job: job, openMapOnLoad: openMapOnLoad),
            ),
          ],
        ),
      ),
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return AppBar(
      backgroundColor: c.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: GestureDetector(
        onTap: () => _goBackOrHome(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border),
          ),
          child: Icon(Icons.arrow_back_rounded, color: c.textPrimary, size: 20),
        ),
      ),
      title: Text(
        context.l10n.workerJobDetailsTitle,
        style: TextStyle(
          color: c.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _JobBody extends ConsumerWidget {
  final BookingEntity job;
  final bool openMapOnLoad;
  const _JobBody({required this.job, this.openMapOnLoad = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    final isPending = job.status == BookingStatus.pending;
    final isStandard = job.lane == BookingLane.standard;
    final isInspection = job.lane == BookingLane.inspection;
    final isBidding = job.lane == BookingLane.bidding;
    final isHired =
        job.assignedWorker != null || job.status != BookingStatus.pending;
    final canComplete =
        job.status.isWorkerActive && !isStandard && !isInspection && !isBidding;
    final cancelledByClient =
        job.status == BookingStatus.cancelled &&
        job.cancelledByRole == CancelledByRole.client;
    // Same getter Booking Details' Qeemat card and Track Worker read, so
    // this Ustaad's own job detail can never show a different number.
    final (priceLabel, priceAmount) = job.displayPrice;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusCard(job: job),
                const SizedBox(height: 12),

                // ── Client cancelled this (previously assigned) job ──────
                if (cancelledByClient) ...[
                  _ClientCancelledBanner(reason: job.cancellationReason),
                  const SizedBox(height: 16),
                ],

                // ── STANDARD lane: selected services + prices ────────────
                if (isStandard && job.standardServiceItems.isNotEmpty) ...[
                  _StandardServicesSection(job: job),
                  const SizedBox(height: 16),
                ],

                // ── STANDARD lane, still Live/listed: no bid — informational ──
                if (isStandard && isPending) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.softTeal,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: c.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.l10n.workerStandardDirectHireNote,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: c.primary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Bid Now button — normal BIDDING lane, or an INSPECTION
                // job the customer reopened via "Find Other Ustaad". Ordinary
                // Standard/Inspection jobs stay direct-assign-only. ─────────
                if (isPending &&
                    (isBidding || job.isOpenForFindOtherUstaadBidding)) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (!ensureApprovedOrWarn(context, ref)) return;
                        final title = job.title?.isNotEmpty == true
                            ? job.title!
                            : job.serviceCategory;
                        context.push(
                          '/worker/job/${job.id}/bid?title=${Uri.encodeComponent(title)}',
                        );
                      },
                      icon: const Icon(Icons.gavel_rounded, size: 16),
                      label: Text(context.l10n.workerSendOffer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.onPrimary,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(_hButton),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_rButton),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Call + Chat (available once hired) ───────────────────
                Row(
                  children: [
                    if (isHired && job.clientPhone != null) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _callClient(job.clientPhone!),
                          icon: const Icon(Icons.call_rounded, size: 16),
                          label: Text(context.l10n.trackCall),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.primary,
                            side: BorderSide(color: c.primary),
                            minimumSize: const Size.fromHeight(_hButton),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(_rButton),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            openWorkerChatForBooking(context, ref, job.id),
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 16,
                        ),
                        label: Text(context.l10n.bidChatWithClient),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.primary,
                          side: BorderSide(color: c.primary),
                          minimumSize: const Size.fromHeight(_hButton),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_rButton),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── STANDARD/BIDDING lane lifecycle (On My Way / Arrived /
                // Start / Cancel) — same section, same shared endpoints;
                // BookingEntity resolves the right getter per lane. ────────
                if ((isStandard || isBidding) && job.status.isWorkerActive) ...[
                  _StandardLifecycleSection(job: job),
                  const SizedBox(height: 16),
                ],

                // ── INSPECTION lane lifecycle (On My Way / Arrived / Start
                // Inspection / Fill Report / Waiting for Decision / Complete) ──
                if (isInspection && job.status.isWorkerActive) ...[
                  _InspectionLifecycleSection(job: job),
                  const SizedBox(height: 16),
                ],

                // ── INSPECTION lane: view the submitted report (read-only —
                // no accept/close buttons on the worker side) ──────────────
                if (isInspection && job.inspectionReportSubmitted)
                  ViewInspectionReportButton(
                    bookingId: job.id,
                    route: '/worker/job/${job.id}/inspection-report/view',
                  )
                // ── The report lives on another booking — either a linked
                // post-inspection repair job (Find Other Ustaad) or a
                // historical inspection the client manually attached to this
                // ordinary bidding job. Both resolve through this same
                // booking id server-side, so the worker sees one identical
                // read-only entry point either way.
                //
                // Purely OPTIONAL extra context for bidders — never required
                // before bidding, and always price-sanitized by the backend
                // (the button self-hides if this worker isn't an eligible
                // viewer, since the provider errors out). ──────────────────
                else if (job.hasLinkedInspectionReport)
                  ViewInspectionReportButton(
                    bookingId: job.id,
                    route: '/worker/job/${job.id}/inspection-report/view',
                    label: context.l10n.discoveryViewInspectionReport,
                  ),

                // ── Location ─────────────────────────────────────────────
                // Moved above Service details: the prototype's live-job screen
                // puts the address directly under Call/Chat, because "where am
                // I going" is what an Ustaad opens this screen for.
                //
                // Privacy is unchanged: exact address/map/directions are only
                // shown once this Ustaad is actually hired — before that the
                // backend never sends exact coordinates/address (see
                // WorkersService._toJobDto), so only an approximate area +
                // distance card is shown.
                if (isHired)
                  _LocationSection(job: job, openMapOnLoad: openMapOnLoad)
                else
                  _ApproximateLocationCard(job: job),
                const SizedBox(height: 16),

                // ── Status history ────────────────────────────────────────
                // Also moved up. This dotted list with times is the prototype's
                // timeline (Kaam confirm hua / Raaste mein / Pohanch gaya …);
                // it used to sit below Attachments, near the bottom.
                if (job.statusHistory.isNotEmpty) ...[
                  _StatusHistorySection(
                    key: const Key('worker-status-history-section'),
                    history: job.statusHistory,
                    review: job.review,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Service details ──────────────────────────────────────
                _Section(
                  title: context.l10n.bookingServiceDetails,
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.category_outlined,
                        label: context.l10n.workerCategoryLabel,
                        value: job.primaryServiceLabel,
                      ),
                      if (job.displayIssueTitle != null)
                        _InfoRow(
                          icon: Icons.title_rounded,
                          label: context.l10n.workerTitleLabel,
                          value: job.displayIssueTitle!,
                        ),
                      if (job.cleanDescription != null &&
                          job.cleanDescription!.isNotEmpty)
                        _InfoRow(
                          icon: Icons.description_outlined,
                          label: context.l10n.postJobDescription,
                          value: job.cleanDescription!,
                          multiline: true,
                        ),
                      _InfoRow(
                        icon: Icons.bolt_rounded,
                        label: context.l10n.bookingUrgency,
                        value: job.urgency == BookingUrgency.urgent
                            ? context.l10n.postJobUrgent
                            : context.l10n.postJobNormal,
                      ),
                      _InfoRow(
                        icon: Icons.schedule_rounded,
                        label: context.l10n.bookingTiming,
                        value: job.urgency == BookingUrgency.urgent
                            ? (job.urgentWindow != null
                                  ? urgentWindowLabel(
                                      context.l10n,
                                      job.urgentWindow!,
                                    )
                                  : context.l10n.postJobUrgent)
                            : job.scheduledDate != null
                            ? DateFormat(
                                    'EEE, d MMM yyyy',
                                  ).format(job.scheduledDate!) +
                                  (job.timeSlot != null
                                      ? ' • ${timeSlotLabel(context.l10n, job.timeSlot!)}'
                                      : '')
                            : context.l10n.bookingNotScheduledYet,
                      ),
                      if (job.timeSlot != null)
                        _InfoRow(
                          icon: Icons.schedule_rounded,
                          label: context.l10n.workerTimeSlotLabel,
                          value: timeSlotLabel(context.l10n, job.timeSlot!),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Pricing ───────────────────────────────────────────────
                // Never an "estimate" row: HandyGo has no estimated-price
                // concept.
                if (priceAmount != null) ...[
                  _Section(
                    title: context.l10n.bookingPricing,
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.payments_outlined,
                          label: switch (priceLabel) {
                            DisplayPriceLabel.agreed =>
                              context.l10n.bookingAgreedPrice,
                            DisplayPriceLabel.finalPrice =>
                              context.l10n.bookingFinalPrice,
                            DisplayPriceLabel.inspectionFee =>
                              context.l10n.postJobInspectionFeeTitle,
                          },
                          value: formatPkr(priceAmount),
                        ),
                        // Paid/not-paid follows the ORIGINAL inspection work
                        // unit, so the inspecting Ustaad is never told the fee
                        // is earned before that booking is COMPLETED.
                        if (workerInspectionFeeLabel(
                              context.l10n,
                              job.inspectionFeePaid,
                            ) !=
                            null)
                          _InfoRow(
                            icon: job.inspectionFeePaid == true
                                ? Icons.check_circle_outline_rounded
                                : Icons.schedule_rounded,
                            label: context.l10n.workerFeeStatusLabel,
                            value: workerInspectionFeeLabel(
                              context.l10n,
                              job.inspectionFeePaid,
                            )!,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Payment truth ─────────────────────────────────────────
                // What the client ACTUALLY paid, from the server settlement —
                // never the quote above dressed up as money received. Only
                // once the job is done: before that there is nothing to
                // settle and nothing honest to show.
                if (job.status == BookingStatus.completed) ...[
                  WorkerPaymentSection(job: job),
                  const SizedBox(height: 16),
                ],

                // ── Attachments ───────────────────────────────────────────
                if (job.attachments.isNotEmpty) ...[
                  BookingAttachmentsSection(attachments: job.attachments),
                  const SizedBox(height: 16),
                ],

                // ── Review ────────────────────────────────────────────────
                if (job.review != null) ...[
                  _ReviewSection(
                    review: job.review!,
                    clientName: job.clientName,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),

        // ── Complete button (sticky bottom) ──────────────────────────────
        if (canComplete) _CompleteJobBar(jobId: job.id),
      ],
    );
  }

  Future<void> _callClient(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

// ── Standard-lane selected services ───────────────────────────────────────────

class _StandardServicesSection extends StatelessWidget {
  final BookingEntity job;
  const _StandardServicesSection({required this.job});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return _Section(
      title: context.l10n.bookingSelectedServices,
      child: Column(
        children: [
          ...job.standardServiceItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.quantity > 1
                          ? context.l10n.bookingServiceQuantity(
                              item.nameSnapshot,
                              item.quantity,
                            )
                          : item.nameSnapshot,
                      style: TextStyle(fontSize: 13.5, color: c.textPrimary),
                    ),
                  ),
                  Text(
                    formatPkr(item.lineTotal),
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
          Divider(height: 20, color: c.border),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.postJobTotal,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
              ),
              Text(
                formatPkr(job.finalPrice ?? job.standardServicesTotal ?? 0),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: c.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Standard-lane lifecycle actions ───────────────────────────────────────────

class _StandardLifecycleSection extends ConsumerWidget {
  final BookingEntity job;
  const _StandardLifecycleSection({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    final isLoading = ref.watch(workerLifecycleNotifierProvider).isLoading;
    final canCancel = job.canWorkerCancel;

    Future<void> runAction(
      Future<void> Function() action, {
      String? successMessage,
    }) async {
      // Re-entry guard: a second tap that raced past the disabled button
      // (isLoading only updates on the next rebuild) must never fire a
      // duplicate lifecycle transition.
      if (ref.read(workerLifecycleNotifierProvider).isLoading) return;
      try {
        await action();
        if (successMessage != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: c.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }

    Widget primaryButton({
      required String label,
      required IconData icon,
      required VoidCallback onPressed,
    }) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : onPressed,
          icon: isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.onPrimary,
                  ),
                )
              : Icon(icon, size: 16),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary,
            foregroundColor: c.onPrimary,
            elevation: 0,
            minimumSize: const Size.fromHeight(_hButton),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_rButton),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // Same BookingEntity.standardWorkerNextAction/biddingWorkerNextAction
    // mapping and WorkerLifecycleActionDispatchX.invoke dispatch as
    // worker_jobs_page.dart's _StandardActionBtn — the two surfaces can never
    // show a different button for the same booking. Exactly one of the two
    // getters is non-null for any given booking (mutually exclusive by lane).
    final nextAction =
        job.standardWorkerNextAction ?? job.biddingWorkerNextAction;
    IconData iconFor(WorkerLifecycleAction a) => switch (a) {
      WorkerLifecycleAction.onMyWay => Icons.directions_car_filled_rounded,
      WorkerLifecycleAction.arrived => Icons.location_on_rounded,
      WorkerLifecycleAction.start => Icons.play_circle_outline_rounded,
      WorkerLifecycleAction.complete => Icons.check_circle_outline_rounded,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (nextAction != null)
          primaryButton(
            label: lifecycleActionLabel(context.l10n, nextAction),
            icon: iconFor(nextAction),
            onPressed: () => runAction(
              () => nextAction.invoke(ref, job.id),
              successMessage: lifecycleActionSuccess(context.l10n, nextAction),
            ),
          )
        else
          const SizedBox.shrink(),
        if (canCancel) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            // Cancel keeps its width and its 52px target but loses the
            // outline: it is not a peer of the action above it.
            child: TextButton.icon(
              onPressed: isLoading
                  ? null
                  : () => _showWorkerCancelReasonDialog(
                      context,
                      ref,
                      job.id,
                      runAction,
                    ),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: Text(context.l10n.workerCancelJob),
              style: TextButton.styleFrom(
                foregroundColor: c.error,
                minimumSize: const Size.fromHeight(_hButton),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_rButton),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Inspection-lane lifecycle actions ─────────────────────────────────────────

class _InspectionLifecycleSection extends ConsumerWidget {
  final BookingEntity job;
  const _InspectionLifecycleSection({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    final isLoading = ref.watch(workerLifecycleNotifierProvider).isLoading;
    final canCancel = job.canWorkerCancel;

    Future<void> runAction(
      Future<void> Function() action, {
      String? successMessage,
    }) async {
      // Re-entry guard: a second tap that raced past the disabled button
      // (isLoading only updates on the next rebuild) must never fire a
      // duplicate lifecycle transition.
      if (ref.read(workerLifecycleNotifierProvider).isLoading) return;
      try {
        await action();
        if (successMessage != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: c.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }

    Widget primaryButton({
      required String label,
      required IconData icon,
      required VoidCallback onPressed,
    }) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : onPressed,
          icon: isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.onPrimary,
                  ),
                )
              : Icon(icon, size: 16),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary,
            foregroundColor: c.onPrimary,
            elevation: 0,
            minimumSize: const Size.fromHeight(_hButton),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_rButton),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // Same BookingEntity.inspectionWorkerNextAction mapping and
    // InspectionWorkerActionDispatchX.invoke dispatch as worker_jobs_page.dart's
    // _InspectionActionBtn — the two surfaces can never show a different
    // button for the same booking.
    final nextAction = job.inspectionWorkerNextAction;
    IconData iconFor(InspectionWorkerAction a) => switch (a) {
      InspectionWorkerAction.onMyWay => Icons.directions_car_filled_rounded,
      InspectionWorkerAction.arrived => Icons.location_on_rounded,
      InspectionWorkerAction.startInspection => Icons.search_rounded,
      InspectionWorkerAction.startWork => Icons.build_rounded,
      InspectionWorkerAction.fillReport => Icons.assignment_outlined,
      InspectionWorkerAction.waitingForDecision => Icons.hourglass_top_rounded,
      InspectionWorkerAction.complete => Icons.check_circle_outline_rounded,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (nextAction == InspectionWorkerAction.waitingForDecision)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.warningSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.warning),
            ),
            child: Row(
              children: [
                Icon(Icons.hourglass_top_rounded, size: 18, color: c.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.workerReportSubmittedWaiting,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: c.warning,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (nextAction == InspectionWorkerAction.fillReport)
          primaryButton(
            label: inspectionActionLabel(context.l10n, nextAction!),
            icon: iconFor(nextAction),
            onPressed: () async {
              await context.push('/worker/job/${job.id}/inspection-report');
              if (context.mounted) {
                ref.invalidate(workerJobDetailProvider(job.id));
              }
            },
          )
        else if (nextAction != null)
          primaryButton(
            label: inspectionActionLabel(context.l10n, nextAction),
            icon: iconFor(nextAction),
            onPressed: () => runAction(
              () => nextAction.invoke(ref, job.id),
              successMessage: inspectionActionSuccess(context.l10n, nextAction),
            ),
          )
        else
          const SizedBox.shrink(),
        if (canCancel) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            // Cancel keeps its width and its 52px target but loses the
            // outline: it is not a peer of the action above it.
            child: TextButton.icon(
              onPressed: isLoading
                  ? null
                  : () => _showWorkerCancelReasonDialog(
                      context,
                      ref,
                      job.id,
                      runAction,
                    ),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: Text(context.l10n.workerCancelJob),
              style: TextButton.styleFrom(
                foregroundColor: c.error,
                minimumSize: const Size.fromHeight(_hButton),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_rButton),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Shared worker-cancel reason dialog (Standard/Bidding + Inspection) ────────
//
// One consistent cancellation flow for every lane: a required dropdown of
// preset reasons, with a required free-text field when "Other" is picked.

/// The preset reasons an Ustaad can pick from, in the language they chose.
///
/// The picked label is what gets submitted as the booking's free-text
/// cancellation reason — exactly as before, only now it reads in the Ustaad's
/// own language instead of always Roman Urdu.
List<String> workerCancelReasons(AppLocalizations l10n) => [
  l10n.workerCancelReasonEmergency,
  l10n.workerCancelReasonTooFar,
  l10n.workerCancelReasonNoTools,
  l10n.workerCancelReasonSchedule,
  l10n.workerCancelReasonCustomer,
  l10n.workerCancelReasonOther,
];

Future<void> _showWorkerCancelReasonDialog(
  BuildContext context,
  WidgetRef ref,
  String jobId,
  Future<void> Function(Future<void> Function()) runAction,
) async {
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => const _CancelReasonDialog(),
  );
  if (reason == null || reason.trim().isEmpty) return;

  await runAction(
    () => ref
        .read(workerLifecycleNotifierProvider.notifier)
        .cancel(jobId, reason.trim()),
  );
  if (context.mounted) _goBackOrHome(context);
}

class _CancelReasonDialog extends StatefulWidget {
  const _CancelReasonDialog();

  @override
  State<_CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<_CancelReasonDialog> {
  String? _selectedReason;
  final _customCtrl = TextEditingController();

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  /// "Other" is the only reason that needs a free-text follow-up, and the
  /// dropdown's value is the localized label — so the comparison has to be
  /// against the same localized string the list was built from.
  bool _isOtherFor(AppLocalizations l10n) =>
      _selectedReason == l10n.workerCancelReasonOther;

  bool _canConfirmFor(AppLocalizations l10n) =>
      _selectedReason != null &&
      (!_isOtherFor(l10n) || _customCtrl.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final l10n = context.l10n;
    final isOther = _isOtherFor(l10n);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        l10n.workerCancelJobTitle,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.workerCancelJobBody,
            style: TextStyle(color: c.textSecondary, fontSize: 13.5),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedReason,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: l10n.cancelReasonSelect,
              filled: true,
              fillColor: c.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: workerCancelReasons(l10n)
                .map(
                  (r) => DropdownMenuItem(
                    value: r,
                    child: Text(r, style: const TextStyle(fontSize: 13.5)),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedReason = v),
          ),
          if (isOther) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customCtrl,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.workerCancelOwnReasonHint,
                filled: true,
                fillColor: c.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.border),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(
            l10n.workerKeepJob,
            style: TextStyle(color: c.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _canConfirmFor(l10n)
              ? () => Navigator.pop(
                  context,
                  isOther ? _customCtrl.text.trim() : _selectedReason,
                )
              : null,
          child: Text(
            l10n.workerYesCancel,
            style: TextStyle(color: c.error, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ── Status card ───────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final BookingEntity job;
  const _StatusCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final (bg, fg) = _chipColors(c, job.status);
    // Only ever true once this Ustaad is hired — the backend does not send a
    // client name before that, which is exactly when the card should still
    // lead with the service instead.
    final hasClient = job.clientName != null && job.clientName!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.softTeal,
              // A circle once it carries initials, the prototype's `.av`;
              // the emoji tile keeps its rounded square.
              borderRadius: BorderRadius.circular(hasClient ? _rPill : 14),
            ),
            child: hasClient
                ? Text(
                    _initialsOf(job.clientName!),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.primary,
                    ),
                  )
                : Text(job.serviceEmoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            // The prototype's live-job card leads with the person, not the
            // service: an avatar, their name, then the job underneath. Same
            // two facts the card already showed plus `job.clientName`, which
            // this screen was already displaying — just lower down, in a
            // "Client" section of its own. That section is gone; the name is
            // shown once, here, where the prototype puts it.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasClient ? job.clientName! : job.serviceCategory,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  hasClient
                      ? '${job.serviceCategory} · ${job.referenceId}'
                      : job.referenceId,
                  style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(_rPill),
                ),
                child: Text(
                  workerJobStatusLabel(context.l10n, job.status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
              if (job.inspection) ...[
                const SizedBox(height: 6),
                const InspectionBadge(small: true),
              ],
            ],
          ),
        ],
      ),
    );
  }

  (Color, Color) _chipColors(AppSemanticColors c, BookingStatus s) {
    if (s.isWorkerActive) {
      return (c.successSoft, c.success);
    }
    return switch (s) {
      BookingStatus.completed => (c.successSoft, c.success),
      BookingStatus.cancelled ||
      BookingStatus.rejected => (c.surfaceSubtle, c.error),
      _ => (c.surfaceSubtle, c.textSecondary),
    };
  }
}

// ── Reusable section container ────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
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
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

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
    final c = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: c.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: c.textPrimary,
                    height: 1.4,
                  ),
                  maxLines: multiline ? null : 2,
                  overflow: multiline ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status history ────────────────────────────────────────────────────────────

class _StatusHistorySection extends StatelessWidget {
  final List<BookingStatusHistoryEntry> history;
  final BookingReviewEntity? review;
  const _StatusHistorySection({super.key, required this.history, this.review});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final hasReview = review != null;
    return _Section(
      title: context.l10n.workerStatusHistory,
      child: Column(
        children: [
          ...history.asMap().entries.map((e) {
            final isLast = !hasReview && e.key == history.length - 1;
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
                        color: isLast ? c.primary : c.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Container(width: 1, height: 28, color: c.border),
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
                          workerJobStatusLabel(context.l10n, entry.status),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isLast ? c.primary : c.textPrimary,
                          ),
                        ),
                        if (entry.note != null && entry.note!.isNotEmpty)
                          Text(
                            entry.note!,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: c.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          DateFormat('d MMM, h:mm a').format(entry.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
          if (hasReview)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: c.warning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              context.l10n.trackStepReviewed,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.warning,
                              ),
                            ),
                            const SizedBox(width: 6),
                            ...List.generate(5, (i) {
                              final r = review!.rating;
                              return Icon(
                                i < r
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 12,
                                color: i < r ? c.warning : c.border,
                              );
                            }),
                          ],
                        ),
                        Text(
                          DateFormat('d MMM, h:mm a').format(review!.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Complete job sticky bar ───────────────────────────────────────────────────

class _CompleteJobBar extends ConsumerWidget {
  final String jobId;
  const _CompleteJobBar({required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    final isLoading = ref.watch(completeJobProvider).isLoading;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: _hButton,
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : () => _confirm(context, ref),
          icon: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.onPrimary,
                  ),
                )
              : const Icon(Icons.check_circle_outline_rounded, size: 18),
          label: Text(
            isLoading
                ? context.l10n.workerCompleting
                : context.l10n.workerMarkAsCompleted,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary,
            foregroundColor: c.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_rButton),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final c = context.semanticColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          context.l10n.workerMarkCompletedTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          context.l10n.workerMarkCompletedBody,
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
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(context.l10n.workerComplete),
          ),
        ],
      ),
    );

    // Re-entry guard: the confirm dialog's async gap means a second tap
    // that raced the disabled button could reach here before this call's
    // own AsyncLoading state has rendered — never fire a duplicate complete.
    if (confirmed == true &&
        context.mounted &&
        !ref.read(completeJobProvider).isLoading) {
      await ref.read(completeJobProvider.notifier).complete(jobId);
      if (context.mounted) {
        final err = ref.read(completeJobProvider).error;
        if (err != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failureMessage(context.l10n, err)),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          _goBackOrHome(context);
        }
      }
    }
  }
}

// ── Review section ────────────────────────────────────────────────────────────

class _ReviewSection extends StatelessWidget {
  final BookingReviewEntity review;
  final String? clientName;
  const _ReviewSection({required this.review, this.clientName});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return _Section(
      title: context.l10n.workerClientReview,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < review.rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 18,
                  color: i < review.rating ? c.warning : c.border,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.workerReviewRatingOutOfFive(review.rating),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('d MMM yyyy').format(review.createdAt),
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: TextStyle(fontSize: 14, color: c.textPrimary, height: 1.5),
            ),
          ],
          if (clientName != null && clientName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 13,
                  color: c.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  clientName!,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Google Directions API helpers ─────────────────────────────────────────────

Future<List<LatLng>?> _fetchRoadRoute(LatLng origin, LatLng dest) async {
  final key = AppConfig.googleMapsApiKey;
  if (key.isEmpty) return null;
  try {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    final response = await dio.get<Map<String, dynamic>>(
      'https://maps.googleapis.com/maps/api/directions/json',
      queryParameters: {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${dest.latitude},${dest.longitude}',
        'mode': 'driving',
        'key': key,
      },
    );
    final data = response.data;
    if (data == null) return null;
    final routes = data['routes'] as List<dynamic>?;
    if (data['status'] == 'OK' && routes != null && routes.isNotEmpty) {
      final encoded = routes[0]['overview_polyline']['points'] as String;
      return _decodePolyline(encoded);
    }
    debugPrint('[Directions] API status: ${data['status']}');
    return null;
  } catch (e) {
    debugPrint('[Directions] API request failed: $e');
    return null;
  }
}

List<LatLng> _decodePolyline(String encoded) {
  final result = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;
  while (index < encoded.length) {
    var b = 0;
    var shift = 0;
    var chunk = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      chunk |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (chunk & 1) != 0 ? ~(chunk >> 1) : (chunk >> 1);
    shift = 0;
    chunk = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      chunk |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (chunk & 1) != 0 ? ~(chunk >> 1) : (chunk >> 1);
    result.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return result;
}

// ── State returned from fullscreen map so preview can sync directions ─────────

class _DirectionsResult {
  final bool directionsActive;
  final LatLng? workerPos;
  final List<LatLng> routePoints;
  const _DirectionsResult(
    this.directionsActive,
    this.workerPos, [
    this.routePoints = const [],
  ]);
}

// ── Location section with map preview + directions ────────────────────────────

// ── Client cancelled banner (shown to the previously-assigned Ustaad) ────────

class _ClientCancelledBanner extends StatelessWidget {
  final String? reason;
  const _ClientCancelledBanner({required this.reason});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: c.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.workerClientCancelledBooking,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.error,
                  ),
                ),
                if (reason != null && reason!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    reason!,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Approximate location (shown before hire — no exact address/map) ──────────

class _ApproximateLocationCard extends StatelessWidget {
  final BookingEntity job;
  const _ApproximateLocationCard({required this.job});

  String? _distanceLabel(AppLocalizations l10n) {
    final km = job.distanceKm;
    if (km == null) return null;
    return km < 1
        ? l10n.distanceMetersAway((km * 1000).round())
        : l10n.distanceKmAway(km.toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final distanceLabel = _distanceLabel(context.l10n);
    return _Section(
      title: context.l10n.chatAttachLocation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: c.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    job.city.isNotEmpty
                        ? context.l10n.workerApproximateArea(job.city)
                        : context.l10n.workerApproximateAreaUnavailable,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (distanceLabel != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.near_me_outlined,
                    size: 16,
                    color: c.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.workerDistanceLabel(distanceLabel),
                    style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              context.l10n.workerExactAddressAfterHire,
              style: TextStyle(
                fontSize: 11.5,
                color: c.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationSection extends ConsumerStatefulWidget {
  final BookingEntity job;

  /// When true, opens the full-screen map automatically once (used by the
  /// worker home page's active-job-card "Map" button, which deep-links
  /// straight into this section's existing full-screen map instead of an
  /// external maps app).
  final bool openMapOnLoad;

  const _LocationSection({required this.job, this.openMapOnLoad = false});

  @override
  ConsumerState<_LocationSection> createState() => _LocationSectionState();
}

class _LocationSectionState extends ConsumerState<_LocationSection>
    with WidgetsBindingObserver {
  GoogleMapController? _mapCtrl;
  bool _directionsActive = false;
  LatLng? _workerPos;
  Timer? _dirTimer;
  bool _gettingLocation = false;
  List<LatLng> _routePoints = const [];

  static const _kReachedMeters = 50.0;
  static const _kDirCheckSecs = 5;

  bool get _hasJobLoc => widget.job.latitude != 0 || widget.job.longitude != 0;
  LatLng get _jobLatLng => LatLng(widget.job.latitude, widget.job.longitude);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.openMapOnLoad && _hasJobLoc) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openFullScreenMap());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dirTimer?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  /// Opens the existing full-screen job map — shared by the expand button
  /// and the worker home page's active-job-card "Map" button.
  Future<void> _openFullScreenMap() async {
    _dirTimer?.cancel();
    _dirTimer = null;
    final result = await Navigator.push<_DirectionsResult>(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenMapPage(
          job: widget.job,
          initialDirectionsActive: _directionsActive,
          initialWorkerPos: _workerPos,
          initialRoutePoints: _routePoints,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _directionsActive = result.directionsActive;
        _workerPos = result.workerPos;
        _routePoints = result.routePoints;
      });
    }
    if (_directionsActive) {
      final pts = _routePoints.isNotEmpty
          ? _routePoints
          : (_workerPos != null ? [_workerPos!, _jobLatLng] : <LatLng>[]);
      _fitBoundsForPoints(pts);
      _startDirTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _dirTimer?.cancel();
      _dirTimer = null;
      debugPrint('[DirectionsMode] App paused — timer suspended.');
    } else if (state == AppLifecycleState.resumed) {
      if (_directionsActive) {
        debugPrint('[DirectionsMode] App resumed — restarting timer.');
        _startDirTimer();
      }
      ref.invalidate(workerJobDetailProvider(widget.job.id));
    }
  }

  // ── Directions ──────────────────────────────────────────────────────────────

  Future<void> _startDirections() async {
    if (_gettingLocation) return;

    // Resolved up front: every message below is reached after an await, and
    // reading `context.l10n` there would cross an async gap.
    final l10n = context.l10n;

    if (AppConfig.googleMapsApiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.workerRoadRouteNotConfigured),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _openExternalMaps();
      }
      return;
    }

    setState(() => _gettingLocation = true);

    LatLng? workerPos;
    String? errorMessage;
    try {
      final tracker = ref.read(locationTrackerProvider);
      if (tracker.lastSyncedLat != null && tracker.lastSyncedLng != null) {
        workerPos = LatLng(tracker.lastSyncedLat!, tracker.lastSyncedLng!);
      } else {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          errorMessage = l10n.workerLocationPermissionDenied;
        } else {
          try {
            final p = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 8),
              ),
            );
            workerPos = LatLng(p.latitude, p.longitude);
          } catch (_) {
            // Timed out or the platform failed to produce a fresh fix —
            // fall back to the last known position. Guarded by its own
            // try/catch so a failure here (e.g. permission revoked mid-
            // flow) can never leave the loader spinning forever.
            try {
              final last = await Geolocator.getLastKnownPosition();
              if (last != null) {
                workerPos = LatLng(last.latitude, last.longitude);
              }
            } catch (_) {
              // workerPos stays null — handled by the check below.
            }
          }
        }
      }
    } finally {
      // Always stop the loader — success, permission denial, timeout, or
      // any other error all land here.
      if (mounted) setState(() => _gettingLocation = false);
    }

    if (!mounted) return;

    if (workerPos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage ?? l10n.workerDirectionsLocationFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _workerPos = workerPos;
      _directionsActive = true;
    });
    _fitBoundsForPoints([workerPos, _jobLatLng]);

    final route = await _fetchRoadRoute(workerPos, _jobLatLng);
    if (!mounted) return;

    if (route != null && route.isNotEmpty) {
      setState(() => _routePoints = route);
      _fitBoundsForPoints(route);
    } else {
      debugPrint(
        '[Directions] Road route unavailable — straight-line emergency fallback active.',
      );
    }

    _startDirTimer();
  }

  void _stopDirections() {
    _dirTimer?.cancel();
    _dirTimer = null;
    setState(() {
      _directionsActive = false;
      _workerPos = null;
      _routePoints = const [];
    });
    _mapCtrl?.animateCamera(CameraUpdate.newLatLng(_jobLatLng));
  }

  void _startDirTimer() {
    _dirTimer?.cancel();
    _dirTimer = Timer.periodic(
      const Duration(seconds: _kDirCheckSecs),
      (_) => _checkDistance(),
    );
  }

  Future<void> _checkDistance() async {
    if (!_directionsActive || !mounted) return;

    LatLng? current;
    final tracker = ref.read(locationTrackerProvider);
    if (tracker.lastSyncedLat != null && tracker.lastSyncedLng != null) {
      current = LatLng(tracker.lastSyncedLat!, tracker.lastSyncedLng!);
    } else {
      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        current = LatLng(p.latitude, p.longitude);
      } catch (_) {}
    }

    if (current == null || !mounted) return;

    final dist = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      _jobLatLng.latitude,
      _jobLatLng.longitude,
    );
    debugPrint('[DirectionsMode] Distance to job: ${dist.toStringAsFixed(1)}m');

    if (dist <= _kReachedMeters) {
      debugPrint('[DirectionsMode] Reached job — stopping directions.');
      _stopDirections();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.workerArrivedAtJobLocation),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (mounted) setState(() => _workerPos = current);
  }

  void _fitBoundsForPoints(List<LatLng> points) {
    if (points.isEmpty) return;
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapCtrl?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  Future<void> _openExternalMaps() async {
    if (_directionsActive) _stopDirections();

    final lat = _jobLatLng.latitude;
    final lng = _jobLatLng.longitude;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Markers + Polyline ──────────────────────────────────────────────────────

  Set<Marker> _buildMarkers() {
    return {
      Marker(
        markerId: const MarkerId('job'),
        position: _jobLatLng,
        infoWindow: InfoWindow(
          title: widget.job.serviceCategory,
          snippet: widget.job.address,
        ),
      ),
      if (_workerPos != null)
        Marker(
          markerId: const MarkerId('worker'),
          position: _workerPos!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: context.l10n.workerYourLocation),
        ),
    };
  }

  Set<Polyline> _buildPolylines() {
    final c = context.semanticColors;
    if (!_directionsActive) return {};
    if (_routePoints.isNotEmpty) {
      return {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: c.primary,
          width: 5,
        ),
      };
    }
    // Emergency straight-line fallback when Directions API returns no route.
    if (_workerPos == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [_workerPos!, _jobLatLng],
        color: c.primary,
        width: 3,
        patterns: [PatternItem.dash(16), PatternItem.gap(8)],
      ),
    };
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    if (!_hasJobLoc) {
      return _Section(
        title: context.l10n.chatAttachLocation,
        child: Column(
          children: [
            if (widget.job.address != null && widget.job.address!.isNotEmpty)
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: context.l10n.postJobStepAddress,
                value: widget.job.address!,
                multiline: true,
              ),
            if (widget.job.city.isNotEmpty)
              _InfoRow(
                icon: Icons.location_city_rounded,
                label: context.l10n.workerCityLabel,
                value: widget.job.city,
              ),
          ],
        ),
      );
    }

    return _Section(
      title: context.l10n.chatAttachLocation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Map preview ──────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                SizedBox(
                  height: 180,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _jobLatLng,
                      zoom: 15,
                    ),
                    markers: _buildMarkers(),
                    polylines: _buildPolylines(),
                    onMapCreated: (c) => _mapCtrl = c,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    myLocationEnabled: false,
                    mapToolbarEnabled: false,
                    // This inline preview sits inside the page's
                    // SingleChildScrollView — its pan/zoom gestures were
                    // competing with the page scroll's own gesture detector.
                    // Claim gestures within the map's bounds immediately
                    // (same fix as the client location picker) so drag/pinch
                    // moves the map smoothly instead of losing the arena.
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                  ),
                ),
                // Expand / fullscreen button
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _openFullScreenMap,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.border),
                      ),
                      child: Icon(
                        Icons.fullscreen_rounded,
                        size: 18,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Address / location info card ─────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                if (widget.job.address != null &&
                    widget.job.address!.isNotEmpty) ...[
                  _InfoRow(
                    icon: Icons.home_work_outlined,
                    label: context.l10n.workerClientAddress,
                    value: widget.job.address!,
                    multiline: true,
                  ),
                  Divider(height: 1, thickness: 0.5, color: c.border),
                  const SizedBox(height: 8),
                ],
                _InfoRow(
                  icon: Icons.location_on_rounded,
                  label: context.l10n.workerPinnedJobLocation,
                  value: context.l10n.workerPinnedOnMap,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Directions controls ──────────────────────────────────────────
          if (!_directionsActive) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _gettingLocation ? null : _startDirections,
                    icon: _gettingLocation
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.primary,
                            ),
                          )
                        : Icon(
                            Icons.directions_rounded,
                            size: 16,
                            color: c.primary,
                          ),
                    label: Text(
                      _gettingLocation
                          ? context.l10n.workerGettingLocation
                          : context.l10n.workerDirections,
                      style: TextStyle(color: c.primary, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openExternalMaps,
                    icon: Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: c.textSecondary,
                    ),
                    label: Text(
                      context.l10n.workerOpenInMaps,
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: c.softTeal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.navigation_rounded,
                          size: 16,
                          color: c.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.workerDirectionsActive,
                          style: TextStyle(
                            color: c.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _stopDirections,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: c.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 9,
                      horizontal: 16,
                    ),
                  ),
                  child: Text(
                    context.l10n.inspFormStop,
                    style: TextStyle(color: c.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
          // ── City ─────────────────────────────────────────────────────────
          if (widget.job.city.isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.location_city_rounded,
              label: context.l10n.workerCityLabel,
              value: widget.job.city,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Fullscreen map page ───────────────────────────────────────────────────────

class _FullScreenMapPage extends ConsumerStatefulWidget {
  final BookingEntity job;
  final bool initialDirectionsActive;
  final LatLng? initialWorkerPos;
  final List<LatLng> initialRoutePoints;

  const _FullScreenMapPage({
    required this.job,
    this.initialDirectionsActive = false,
    this.initialWorkerPos,
    this.initialRoutePoints = const [],
  });

  @override
  ConsumerState<_FullScreenMapPage> createState() => _FullScreenMapPageState();
}

class _FullScreenMapPageState extends ConsumerState<_FullScreenMapPage>
    with WidgetsBindingObserver {
  GoogleMapController? _ctrl;
  bool _directionsActive = false;
  LatLng? _workerPos;
  List<LatLng> _routePoints = const [];
  Timer? _dirTimer;
  bool _gettingLocation = false;

  static const _kReachedMeters = 50.0;
  static const _kDirCheckSecs = 5;

  LatLng get _jobLatLng => LatLng(widget.job.latitude, widget.job.longitude);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _directionsActive = widget.initialDirectionsActive;
    _workerPos = widget.initialWorkerPos;
    _routePoints = widget.initialRoutePoints;
    if (_directionsActive) _startDirTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dirTimer?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  void _popWithResult() {
    Navigator.pop(
      context,
      _DirectionsResult(_directionsActive, _workerPos, _routePoints),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _dirTimer?.cancel();
      _dirTimer = null;
      debugPrint('[DirectionsMode/FS] App paused — timer suspended.');
    } else if (state == AppLifecycleState.resumed) {
      if (_directionsActive) {
        debugPrint('[DirectionsMode/FS] App resumed — restarting timer.');
        _startDirTimer();
      }
    }
  }

  // ── Directions ──────────────────────────────────────────────────────────────

  Future<void> _startDirections() async {
    if (_gettingLocation) return;

    // Resolved up front: every message below is reached after an await, and
    // reading `context.l10n` there would cross an async gap.
    final l10n = context.l10n;

    if (AppConfig.googleMapsApiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.workerRoadRouteNotConfigured),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _openExternalMaps();
      }
      return;
    }

    setState(() => _gettingLocation = true);

    LatLng? workerPos;
    String? errorMessage;
    try {
      final tracker = ref.read(locationTrackerProvider);
      if (tracker.lastSyncedLat != null && tracker.lastSyncedLng != null) {
        workerPos = LatLng(tracker.lastSyncedLat!, tracker.lastSyncedLng!);
      } else {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          errorMessage = l10n.workerLocationPermissionDenied;
        } else {
          try {
            final p = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 8),
              ),
            );
            workerPos = LatLng(p.latitude, p.longitude);
          } catch (_) {
            try {
              final last = await Geolocator.getLastKnownPosition();
              if (last != null) {
                workerPos = LatLng(last.latitude, last.longitude);
              }
            } catch (_) {
              // workerPos stays null — handled by the check below.
            }
          }
        }
      }
    } finally {
      // Always stop the loader — success, permission denial, timeout, or
      // any other error all land here.
      if (mounted) setState(() => _gettingLocation = false);
    }

    if (!mounted) return;

    if (workerPos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage ?? l10n.workerDirectionsLocationFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _workerPos = workerPos;
      _directionsActive = true;
    });
    _fitBoundsForPoints([workerPos, _jobLatLng]);

    final route = await _fetchRoadRoute(workerPos, _jobLatLng);
    if (!mounted) return;

    if (route != null && route.isNotEmpty) {
      setState(() => _routePoints = route);
      _fitBoundsForPoints(route);
    } else {
      debugPrint(
        '[Directions/FS] Road route unavailable — straight-line emergency fallback active.',
      );
    }

    _startDirTimer();
  }

  void _stopDirections() {
    _dirTimer?.cancel();
    _dirTimer = null;
    setState(() {
      _directionsActive = false;
      _workerPos = null;
      _routePoints = const [];
    });
    _ctrl?.animateCamera(CameraUpdate.newLatLng(_jobLatLng));
  }

  void _startDirTimer() {
    _dirTimer?.cancel();
    _dirTimer = Timer.periodic(
      const Duration(seconds: _kDirCheckSecs),
      (_) => _checkDistance(),
    );
  }

  Future<void> _checkDistance() async {
    if (!_directionsActive || !mounted) return;

    LatLng? current;
    final tracker = ref.read(locationTrackerProvider);
    if (tracker.lastSyncedLat != null && tracker.lastSyncedLng != null) {
      current = LatLng(tracker.lastSyncedLat!, tracker.lastSyncedLng!);
    } else {
      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        current = LatLng(p.latitude, p.longitude);
      } catch (_) {}
    }

    if (current == null || !mounted) return;

    final dist = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      _jobLatLng.latitude,
      _jobLatLng.longitude,
    );
    debugPrint(
      '[DirectionsMode/FS] Distance to job: ${dist.toStringAsFixed(1)}m',
    );

    if (dist <= _kReachedMeters) {
      debugPrint('[DirectionsMode/FS] Reached job — stopping directions.');
      _stopDirections();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.workerArrivedAtJobLocation),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (mounted) setState(() => _workerPos = current);
  }

  void _fitBoundsForPoints(List<LatLng> points) {
    if (points.isEmpty) return;
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _ctrl?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  Future<void> _openExternalMaps() async {
    if (_directionsActive) _stopDirections();
    final lat = _jobLatLng.latitude;
    final lng = _jobLatLng.longitude;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Set<Marker> _buildMarkers() {
    return {
      Marker(
        markerId: const MarkerId('job'),
        position: _jobLatLng,
        infoWindow: InfoWindow(
          title: widget.job.serviceCategory,
          snippet: widget.job.address,
        ),
      ),
      if (_workerPos != null)
        Marker(
          markerId: const MarkerId('worker'),
          position: _workerPos!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: context.l10n.workerYourLocation),
        ),
    };
  }

  Set<Polyline> _buildPolylines() {
    final c = context.semanticColors;
    if (!_directionsActive) return {};
    if (_routePoints.isNotEmpty) {
      return {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: c.primary,
          width: 5,
        ),
      };
    }
    // Emergency straight-line fallback when Directions API returns no route.
    if (_workerPos == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [_workerPos!, _jobLatLng],
        color: c.primary,
        width: 3,
        patterns: [PatternItem.dash(16), PatternItem.gap(8)],
      ),
    };
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _popWithResult();
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: c.textPrimary,
          leading: BackButton(onPressed: _popWithResult),
          title: Text(
            widget.job.serviceCategory,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _jobLatLng,
                zoom: 15,
              ),
              markers: _buildMarkers(),
              polylines: _buildPolylines(),
              onMapCreated: (c) {
                _ctrl = c;
                if (_directionsActive) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final pts = _routePoints.isNotEmpty
                        ? _routePoints
                        : (_workerPos != null
                              ? [_workerPos!, _jobLatLng]
                              : <LatLng>[]);
                    _fitBoundsForPoints(pts);
                  });
                }
              },
              zoomControlsEnabled: true,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              mapToolbarEnabled: false,
            ),

            // ── Bottom controls ──────────────────────────────────────────────
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + bottomPad,
              child: _directionsActive
                  ? Row(
                      children: [
                        Expanded(
                          child: _MapButton(
                            label: context.l10n.workerDirectionsActive,
                            icon: Icons.navigation_rounded,
                            color: c.primary,
                            onPressed: null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _MapButton(
                          label: context.l10n.inspFormStop,
                          icon: Icons.stop_rounded,
                          color: c.error,
                          onPressed: _stopDirections,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _MapButton(
                            label: _gettingLocation
                                ? context.l10n.workerGettingLocation
                                : context.l10n.workerDirections,
                            icon: Icons.directions_rounded,
                            color: c.primary,
                            onPressed: _gettingLocation
                                ? null
                                : _startDirections,
                            loading: _gettingLocation,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MapButton(
                            label: context.l10n.workerOpenInMaps,
                            icon: Icons.open_in_new_rounded,
                            color: c.textSecondary,
                            onPressed: _openExternalMaps,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable map control button (fullscreen bottom bar only) ──────────────────

class _MapButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool loading;

  const _MapButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    // Disabled is dimmed with Opacity, never by deriving a fainter colour: a
    // colour comes from the palette or it does not exist. The elevation and
    // its black shadow are gone for the same reason the cards lost theirs; a
    // solid fill reads perfectly well against the map without one.
    return Opacity(
      opacity: onPressed == null && !loading ? 0.6 : 1,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(_rButton),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(_rButton),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.onPrimary,
                    ),
                  )
                else
                  Icon(icon, size: 15, color: c.onPrimary),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: c.onPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

// ── Error + loading screens ───────────────────────────────────────────────────

class _ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorScreen({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: c.textSecondary),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: c.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
