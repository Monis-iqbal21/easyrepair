import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../../bookings/presentation/providers/booking_providers.dart';
import '../../../bookings/presentation/widgets/booking_skeleton.dart';
import '../../../bookings/presentation/widgets/inspection_badge.dart';
import '../../../../core/network/reconnect_refresh.dart';
import '../providers/worker_job_providers.dart';
import '../providers/worker_providers.dart';
import '../widgets/onboarding_gate.dart';
import '../widgets/worker_bottom_nav_bar.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/network/offline_banner.dart';
import '../../../bookings/presentation/utils/status_labels.dart';
import '../utils/worker_status_labels.dart';
import '../../../../core/errors/failure_messages.dart';

class WorkerJobsPage extends ConsumerStatefulWidget {
  const WorkerJobsPage({super.key});

  @override
  ConsumerState<WorkerJobsPage> createState() => _WorkerJobsPageState();
}

class _WorkerJobsPageState extends ConsumerState<WorkerJobsPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Silent refresh whenever this tab is opened (each bottom-nav tap
    // rebuilds this page via context.go) — cheap, keeps cached data visible
    // while refetching, and catches any assignment missed by the realtime
    // push handlers in app.dart.
    ref.read(workerJobsProvider.notifier).refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(workerJobsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    // In-place refresh on reconnect — same scoped, navigation-free
    // behaviour as the resume handler above.
    refreshOnReconnect(ref, () => ref.invalidate(workerJobsProvider));
    final jobsAsync = ref.watch(workerJobsProvider);
    final isShowingCachedData =
        ref.watch(workerJobsIsOfflineProvider) && jobsAsync.hasValue;
    final notifier  = ref.read(workerJobsProvider.notifier);
    final filter    = ref.watch(workerJobsProvider.notifier
        .select((n) => n.currentFilter));
    final workerProfile = ref.watch(workerProfileProvider).valueOrNull;
    // Unknown-yet counts as approved so the page doesn't flash the
    // incomplete-profile panel before the profile has even loaded once.
    final isApproved = workerProfile?.isOnboardingApproved ?? true;

    return Scaffold(
      backgroundColor: c.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                // Same wording as the Client "My Jobs" screen title. The
                // bottom-nav tab of the same name stays hard-coded English.
                context.l10n.clientJobsTitle,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (!isApproved)
              // Profile incomplete/not approved — nothing meaningful to
              // list or filter yet; never show it as a fetch error.
              Expanded(
                child: ProfileIncompleteState(
                  message: context.l10n.workerCompleteProfileForJobs,
                ),
              )
            else ...[
              // ── Filter tabs ──────────────────────────────────────────────
              _FilterTabs(active: filter, onTap: notifier.setFilter),

              const SizedBox(height: 4),

              if (isShowingCachedData) const OfflineDataBanner(),
              if (jobsAsync.hasError && jobsAsync.hasValue)
                const _RefreshFailedBanner(),

              // ── List ─────────────────────────────────────────────────────
              Expanded(
                child: jobsAsync.when(
                  skipError: true,
                  loading: () => const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: BookingSkeleton(),
                  ),
                  error: (err, _) => _ErrorState(
                    message: failureMessage(context.l10n, err, fallback: context.l10n.workerJobsLoadFailed),
                    onRetry: notifier.refresh,
                  ),
                  data: (jobs) => jobs.isEmpty
                      ? _EmptyState(filter: filter)
                      : RefreshIndicator(
                          color: c.primary,
                          backgroundColor: c.surface,
                          onRefresh: notifier.refresh,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                            itemCount: jobs.length,
                            itemBuilder: (ctx, i) =>
                                _JobCard(key: ValueKey(jobs[i].id), job: jobs[i]),
                        ),
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const WorkerBottomNavBar(currentIndex: 2),
    );
  }
}

// ── Filter tabs ───────────────────────────────────────────────────────────────

class _FilterTabs extends StatelessWidget {
  final WorkerJobFilter active;
  final ValueChanged<WorkerJobFilter> onTap;

  const _FilterTabs({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: WorkerJobFilter.values.map((f) {
          final isActive = f == active;
          return GestureDetector(
            onTap: () => onTap(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsetsDirectional.only(end: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? c.primary : c.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive ? c.primary : c.border,
                ),
              ),
              child: Text(
                workerJobFilterLabel(context.l10n, f),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? c.onPrimary : c.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Job card ──────────────────────────────────────────────────────────────────

class _JobCard extends ConsumerWidget {
  final BookingEntity job;
  const _JobCard({super.key, required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    // STANDARD/BIDDING lane: granular next-action button (On My Way / Arrived
    // / Start Job / Complete Job), shared with worker_job_detail_page.dart via
    // BookingEntity.standardWorkerNextAction/biddingWorkerNextAction so the
    // two can never disagree. INSPECTION lane: its own ladder (On My Way /
    // Arrived / Start Inspection / Fill Report / Waiting for Decision /
    // Complete Job) via BookingEntity.inspectionWorkerNextAction.
    //
    // Under My Jobs → Applied, an entry is this worker's BID, not necessarily
    // an assignment: a booking awarded to someone else is ACCEPTED while this
    // worker's own bid is REJECTED. The lifecycle getters above key off the
    // booking's status alone, so without this gate such a card would offer
    // "On My Way" on a job this worker never won. A bid that WAS accepted
    // means they are the assigned worker, so those keep their normal actions.
    final isOtherWorkersJob =
        job.myBidStatus != null && job.myBidStatus != BidOutcome.accepted;
    final standardAction = isOtherWorkersJob
        ? null
        : (job.standardWorkerNextAction ?? job.biddingWorkerNextAction);
    final inspectionAction =
        isOtherWorkersJob ? null : job.inspectionWorkerNextAction;
    final isActive = !isOtherWorkersJob && job.status.isWorkerActive;
    final canComplete =
        isActive && standardAction == null && inspectionAction == null;
    final cancelledByClient = job.status == BookingStatus.cancelled &&
        job.cancelledByRole == CancelledByRole.client;
    // The two tests the card already ran inline, lifted to names so the
    // headline and the supporting line cannot disagree about them. Both
    // expressions are character-for-character what they replaced.
    final hasTitle = job.title != null && job.title!.isNotEmpty;
    final hasClient = job.clientName != null && job.clientName!.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/worker/job/${job.id}').then((_) {
        ref.invalidate(workerJobsProvider);
      }),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status accent strip for active jobs ──────────────────────
          if (isActive)
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            )
          else if (cancelledByClient)
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: c.error,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),

          if (cancelledByClient)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: c.errorSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.error),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: c.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.workerClientCancelledBooking,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.error,
                          ),
                        ),
                        if (job.cancellationReason != null &&
                            job.cancellationReason!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            job.cancellationReason!,
                            style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status + flags on the left, money on the right ───────
                //
                // The prototype's job card leads with two things only: what
                // kind of job this is, and what it is worth. The amount used
                // to be an 11px item buried in a five-item Wrap between a
                // chip and a clock — the single number an Ustaad scans for,
                // rendered smaller than the address. It is the right-hand
                // anchor now, and everything that was competing with it has
                // moved below the divider.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // My Jobs → Applied shows THIS worker's own bid
                          // outcome, not the booking's status: a job awarded
                          // to someone else leaves the booking ACCEPTED while
                          // this worker's bid is REJECTED, and showing
                          // "Assigned" there would read as though they had
                          // won it.
                          if (job.myBidStatus != null)
                            _BidStatusChip(outcome: job.myBidStatus!)
                          else
                            _StatusChip(status: job.status),
                          _UrgencyPill(urgency: job.urgency),
                          if (job.inspection)
                            const InspectionBadge(small: true),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Price this Ustaad's work unit was hired/paid for — see
                    // BookingEntity.canonicalPrice. Under the Applied filter
                    // the job usually isn't assigned to this worker at all
                    // (canonicalPrice is null for a still-open BIDDING job),
                    // so their OWN bid amount is the only truthful figure to
                    // show there.
                    if ((job.myBidAmount ?? job.canonicalPrice) != null)
                      Text(
                        formatPkr(job.myBidAmount ?? job.canonicalPrice),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                          height: 1.1,
                        ),
                      ),
                  ],
                ),

                // ── What the job actually is ─────────────────────────────
                //
                // `title` is the job an Ustaad was hired for ("Distribution
                // Box Setup"); `serviceCategory` is the trade ("Electrician").
                // The card used to headline the trade and whisper the job in
                // 13px grey underneath, so three cards for three different
                // jobs all read "Electrician". The headline is the job now,
                // and the trade joins the client on the supporting line —
                // both fields still render, only their weight swapped.
                const SizedBox(height: 10),
                Text(
                  hasTitle ? job.title! : job.serviceCategory,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasTitle || hasClient) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (hasTitle) job.serviceCategory,
                      if (hasClient) job.clientName!,
                    ].join(' · '),
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),
                Divider(height: 1, color: c.divider),
                const SizedBox(height: 10),

                // ── Quiet meta: when, where, which booking ───────────────
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: c.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _fmtDate(context, job.acceptedAt ?? job.createdAt),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Kept, but no longer the second-loudest thing on the
                    // card — an Ustaad needs it when he calls support, not
                    // when he is scanning the list.
                    Text(
                      job.referenceId,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: c.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),

                // ── Address ──────────────────────────────────────────────
                if (job.address != null && job.address!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: c.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${job.city.isNotEmpty ? '${job.city}, ' : ''}${job.address!}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: c.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // ── Inspection-only completion strip ─────────────────────
                // The client chose "Find Other Ustaad", so this Ustaad's work
                // here was the inspection alone. Full-width (not a chip in
                // the meta Wrap) so the wording always fits unabbreviated on
                // any screen width, and so the card can never be misread as
                // a completed repair.
                if (job.isCompletedInspectionOnly) ...[
                  const SizedBox(height: 10),
                  const _InspectionOnlyCompletedBadge(),
                ],

                if (standardAction != null) ...[
                  const SizedBox(height: 12),
                  _StandardActionBtn(jobId: job.id, action: standardAction),
                ] else if (inspectionAction != null) ...[
                  const SizedBox(height: 12),
                  _InspectionActionBtn(jobId: job.id, action: inspectionAction),
                ] else if (canComplete) ...[
                  const SizedBox(height: 12),
                  _CompleteBtn(jobId: job.id),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  String _fmtDate(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return context.l10n.cardTodayAt(DateFormat('h:mm a').format(dt));
    }
    return DateFormat('MMM d, yyyy').format(dt);
  }
}

// ── "Inspection only" completed badge ────────────────────────────────────────

/// Shown on a completed job whose client chose "Find Other Ustaad" — this
/// Ustaad earned and completed the inspection, and someone else was (or will
/// be) hired for the repair. Deliberately worded so the card can never be
/// mistaken for a completed repair.
class _InspectionOnlyCompletedBadge extends StatelessWidget {
  const _InspectionOnlyCompletedBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.warningSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.warning),
      ),
      child: Row(
        children: [
          Icon(Icons.fact_check_outlined, size: 13, color: c.warning),
          const SizedBox(width: 6),
          // Flexible so the label can never overflow, however narrow the card.
          Flexible(
            child: Text(
              context.l10n.workerOnlyInspectionCompleted,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: c.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Complete button (inline in card) ─────────────────────────────────────────

class _CompleteBtn extends ConsumerWidget {
  final String jobId;
  const _CompleteBtn({required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    final isLoading = ref.watch(completeJobProvider).isLoading;

    return GestureDetector(
      onTap: isLoading ? null : () => _confirm(context, ref),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: c.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.onPrimary,
                ),
              )
            else
              Icon(
                Icons.check_circle_outline_rounded,
                size: 14,
                color: c.onPrimary,
              ),
            const SizedBox(width: 5),
            Text(
              isLoading
                  ? context.l10n.workerCompleting
                  : context.l10n.workerComplete,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.onPrimary,
              ),
            ),
          ],
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
            child: Text(context.l10n.commonCancel,
                style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: c.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
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
        }
      }
    }
  }
}

// ── STANDARD lane next-action button (inline in card) ────────────────────────
//
// Same action mapping and dispatch as worker_job_detail_page.dart's
// _StandardLifecycleSection (both go through BookingEntity
// .standardWorkerNextAction + WorkerLifecycleActionDispatchX.invoke), so the
// two surfaces cannot show a different button for the same booking. No
// confirmation dialog — matches the detail page's existing behavior for
// these actions.
class _StandardActionBtn extends ConsumerWidget {
  final String jobId;
  final WorkerLifecycleAction action;
  const _StandardActionBtn({required this.jobId, required this.action});

  IconData get _icon => switch (action) {
        WorkerLifecycleAction.onMyWay => Icons.directions_car_filled_rounded,
        WorkerLifecycleAction.arrived => Icons.location_on_rounded,
        WorkerLifecycleAction.start => Icons.play_circle_outline_rounded,
        WorkerLifecycleAction.complete => Icons.check_circle_outline_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    final isLoading = ref.watch(workerLifecycleNotifierProvider).isLoading;

    return GestureDetector(
      onTap: isLoading ? null : () => _run(context, ref),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: c.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.onPrimary,
                ),
              )
            else
              Icon(_icon, size: 14, color: c.onPrimary),
            const SizedBox(width: 5),
            Text(
              isLoading
                  ? '${lifecycleActionLabel(context.l10n, action)}...'
                  : lifecycleActionLabel(context.l10n, action),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    // Re-entry guard: a second tap that raced past the disabled button
    // (isLoading only updates on the next rebuild) must never fire a
    // duplicate lifecycle transition.
    if (ref.read(workerLifecycleNotifierProvider).isLoading) return;
    try {
      await action.invoke(ref, jobId);
      if (context.mounted) {
        final c = context.semanticColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lifecycleActionSuccess(context.l10n, action)),
            backgroundColor: c.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final c = context.semanticColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                failureMessage(context.l10n, e, fallback: context.l10n.inspectionActionFailed)),
            backgroundColor: c.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}

// ── INSPECTION lane next-action button (inline in card) ──────────────────────
//
// Same mapping and dispatch as worker_job_detail_page.dart's inspection
// section (both go through BookingEntity.inspectionWorkerNextAction +
// InspectionWorkerActionDispatchX.invoke). fillReport navigates to the
// report form; waitingForDecision renders as a disabled informational chip
// (not tappable) so a worker can never bypass the client's decision.
class _InspectionActionBtn extends ConsumerWidget {
  final String jobId;
  final InspectionWorkerAction action;
  const _InspectionActionBtn({required this.jobId, required this.action});

  IconData get _icon => switch (action) {
        InspectionWorkerAction.onMyWay => Icons.directions_car_filled_rounded,
        InspectionWorkerAction.arrived => Icons.location_on_rounded,
        InspectionWorkerAction.startInspection => Icons.search_rounded,
        InspectionWorkerAction.startWork => Icons.build_rounded,
        InspectionWorkerAction.fillReport => Icons.assignment_outlined,
        InspectionWorkerAction.waitingForDecision => Icons.hourglass_top_rounded,
        InspectionWorkerAction.complete => Icons.check_circle_outline_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    if (action == InspectionWorkerAction.waitingForDecision) {
      // Same "waiting" pairing as the prototype's own `.tg.w` tag class
      // (urg/urgT, not warn/warnT) — not tappable, purely informational.
      return Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: c.urgentSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.urgent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icon, size: 14, color: c.urgent),
            const SizedBox(width: 5),
            Text(
              inspectionActionLabel(context.l10n, action),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.urgent,
              ),
            ),
          ],
        ),
      );
    }

    final isLoading = action == InspectionWorkerAction.fillReport
        ? false
        : ref.watch(workerLifecycleNotifierProvider).isLoading;

    return GestureDetector(
      onTap: isLoading ? null : () => _run(context, ref),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: c.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.onPrimary,
                ),
              )
            else
              Icon(_icon, size: 14, color: c.onPrimary),
            const SizedBox(width: 5),
            Text(
              isLoading
                  ? '${inspectionActionLabel(context.l10n, action)}...'
                  : inspectionActionLabel(context.l10n, action),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    if (action == InspectionWorkerAction.fillReport) {
      await context.push('/worker/job/$jobId/inspection-report');
      if (context.mounted) ref.invalidate(workerJobsProvider);
      return;
    }
    try {
      await action.invoke(ref, jobId);
      if (context.mounted) {
        final c = context.semanticColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(inspectionActionSuccess(context.l10n, action)),
            backgroundColor: c.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final c = context.semanticColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                failureMessage(context.l10n, e, fallback: context.l10n.inspectionActionFailed)),
            backgroundColor: c.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final BookingStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final (bg, fg) = _colors(c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        workerJobStatusLabel(context.l10n, status),
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  (Color, Color) _colors(AppSemanticColors c) {
    if (status.isWorkerActive) {
      return (c.successSoft, c.success);
    }
    return switch (status) {
      BookingStatus.completed => (c.successSoft, c.success),
      BookingStatus.cancelled || BookingStatus.rejected =>
        (c.errorSoft, c.error),
      _ => (c.surfaceSubtle, c.textSecondary),
    };
  }
}

/// My Jobs → Applied: this worker's own bid outcome. Reuses the existing
/// bidStatus* wording (already translated in all three languages) rather
/// than inventing parallel strings, and deliberately never invents a
/// "not selected" state — REJECTED is what the server actually stores when
/// another worker is hired (see BidsRepository.acceptBid).
class _BidStatusChip extends StatelessWidget {
  final BidOutcome outcome;
  const _BidStatusChip({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final (bg, fg) = switch (outcome) {
      BidOutcome.accepted => (c.successSoft, c.success),
      BidOutcome.rejected => (c.errorSoft, c.error),
      // Same "waiting" pairing as the prototype's `.tg.w` tag class.
      BidOutcome.pending => (c.urgentSoft, c.urgent),
    };
    final label = switch (outcome) {
      BidOutcome.accepted => context.l10n.bidStatusAccepted,
      BidOutcome.rejected => context.l10n.bidStatusRejected,
      BidOutcome.pending => context.l10n.bidStatusPending,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _UrgencyPill extends StatelessWidget {
  final BookingUrgency urgency;
  const _UrgencyPill({required this.urgency});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final isUrgent = urgency == BookingUrgency.urgent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isUrgent ? c.urgentSoft : c.surfaceSubtle,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUrgent ? Icons.bolt_rounded : Icons.schedule_rounded,
            size: 10,
            color: isUrgent ? c.urgent : c.textSecondary,
          ),
          const SizedBox(width: 3),
          Text(
            isUrgent ? context.l10n.postJobUrgent : context.l10n.postJobNormal,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isUrgent ? c.urgent : c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final WorkerJobFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final l10n = context.l10n;
    final title = switch (filter) {
      WorkerJobFilter.active => l10n.workerNoActiveJobs,
      WorkerJobFilter.applied => l10n.workerNoAppliedJobs,
      WorkerJobFilter.completed => l10n.workerNoCompletedJobs,
      WorkerJobFilter.cancelled => l10n.workerNoCancelledJobs,
      WorkerJobFilter.all => l10n.workerNoJobsAssigned,
    };
    final subtitle = switch (filter) {
      WorkerJobFilter.active => l10n.workerNewRequestsHere,
      WorkerJobFilter.applied => l10n.workerAppliedJobsHere,
      WorkerJobFilter.completed => l10n.workerCompletedJobsHere,
      WorkerJobFilter.cancelled => l10n.workerCancelledJobsHere,
      WorkerJobFilter.all => l10n.workerAcceptToGetStarted,
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: c.softTeal,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🔧', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
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

/// Shown above the list only when a background poll failed but previous jobs
/// are still cached/visible — never replaces the list itself.
class _RefreshFailedBanner extends StatelessWidget {
  const _RefreshFailedBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      width: double.infinity,
      color: c.warningSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        context.l10n.myBookingsRefreshFailed,
        style: TextStyle(fontSize: 12, color: c.warning),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: c.errorSoft,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('⚠️', style: TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.myBookingsSomethingWrong,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: c.textSecondary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  context.l10n.commonRetry,
                  style: TextStyle(
                    color: c.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
