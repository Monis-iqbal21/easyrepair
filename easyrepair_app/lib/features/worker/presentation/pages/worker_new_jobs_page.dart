import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/network/offline_banner.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../../bookings/presentation/widgets/inspection_badge.dart';
import '../../../bookings/presentation/widgets/booking_skeleton.dart';
import '../../domain/entities/new_job_entity.dart';
import '../../../../core/network/reconnect_refresh.dart';
import '../providers/worker_job_providers.dart';
import '../providers/worker_providers.dart';
import '../widgets/onboarding_gate.dart';
import '../widgets/worker_bottom_nav_bar.dart';
import '../widgets/worker_chat_action.dart';
import '../../../bookings/presentation/utils/worker_labels.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../utils/worker_status_labels.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
//
// There isn't one. Every colour comes from `context.semanticColors` — see
// `core/theme/app_semantic_colors.dart`, the one place HandyGo's colours are
// decided, and the only file that changes when light/dark is retuned.
//
// What used to live here: `_kAccent` (`#DB6234`, the old EasyRepair orange —
// absent from the Ustaad prototype entirely), `_kDark`, `_kGray`, `_kLight`,
// `_kBorder`, `_kBg`. All six are gone, along with the loose `#EA580C`,
// `#FFF7ED`, `#F1F5F9`, `#FEF3C7`, `#92400E`, `#FFF1F2` and `#E6F5F0` that
// were scattered through the widgets below.
//
// ── Prototype geometry ────────────────────────────────────────────────────────
//
// From the Ustaad prototype's stylesheet (`06 Handover to Monis/05 Design &
// UI/prototype/source/Handygo Ustaad V1.0 - Prototype.dc.html`, CSS 15–119;
// the leads list is `is_uleads`, lines 347–390).
//
// The prototype uses NO shadow inside a screen: `.crd` is `background +
// radius 16 + 1px solid var(--line)` and nothing more.
const double _rCard = 16;    // .crd
const double _rButton = 14;  // .btnp
const double _rPill = 999;   // .tg / filter chips
const double _hButton = 52;  // .btnp min-height
const double _hChip = 44;    // the prototype's filter chips are 44 tall
const double _gap = 11;      // the leads list's own gap, not the 14 Home uses

class WorkerNewJobsPage extends ConsumerStatefulWidget {
  const WorkerNewJobsPage({super.key});

  @override
  ConsumerState<WorkerNewJobsPage> createState() => _WorkerNewJobsPageState();
}

class _WorkerNewJobsPageState extends ConsumerState<WorkerNewJobsPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Silent refresh whenever this tab is opened (each bottom-nav tap
    // rebuilds this page via context.go) — cheap, keeps cached data visible
    // while refetching, and catches any assignment missed by the realtime
    // push handlers in app.dart.
    ref.read(newJobsProvider.notifier).refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(newJobsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    // New Jobs is the most time-sensitive list in the app, so reconnecting
    // refetches it immediately — in place, without leaving this tab.
    refreshOnReconnect(ref, () => ref.invalidate(newJobsProvider));
    final jobsAsync = ref.watch(newJobsProvider);
    final isShowingCachedData =
        ref.watch(newJobsIsOfflineProvider) && jobsAsync.hasValue;
    final notifier  = ref.read(newJobsProvider.notifier);
    final workerProfile = ref.watch(workerProfileProvider).valueOrNull;
    // Unknown-yet counts as approved so the page doesn't flash the
    // incomplete-profile panel before the profile has even loaded once.
    final isApproved = workerProfile?.isOnboardingApproved ?? true;
    final c = context.semanticColors;

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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Prototype `.h1` (CSS line 42): 18px / 700 / -.01em.
                        // Nothing in the prototype is heavier than w700.
                        Text(
                          context.l10n.workerNewJobsTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: c.textPrimary,
                            letterSpacing: -0.18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.workerNewJobsSubtitle,
                          style: TextStyle(fontSize: 14, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Refresh button — always visible
                  GestureDetector(
                    onTap: notifier.refresh,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.border),
                      ),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 19,
                        color: c.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (!isApproved)
              // Profile incomplete/not approved — never a fetch error, and
              // there's nothing meaningful to filter/list yet either way.
              Expanded(
                child: ProfileIncompleteState(
                  message: context.l10n.workerCompleteProfileForNewJobs,
                ),
              )
            else ...[
              // ── Filter bar ───────────────────────────────────────────────
              _FilterBar(notifier: notifier),

              const SizedBox(height: 8),

              if (isShowingCachedData) const OfflineDataBanner(),
              if (jobsAsync.hasError && jobsAsync.hasValue)
                const _RefreshFailedBanner(),

              // ── List ─────────────────────────────────────────────────────
              Expanded(
                child: jobsAsync.when(
                  skipError: true,
                  loading: () => const Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: BookingSkeleton(),
                  ),
                  error: (err, _) => _ErrorState(
                    message: failureMessage(context.l10n, err,
                        fallback: context.l10n.workerNewJobsLoadFailed),
                    onRetry: notifier.refresh,
                  ),
                  data: (jobs) => jobs.isEmpty
                      ? const _EmptyState()
                      : RefreshIndicator(
                          color: c.primary,
                          backgroundColor: c.surface,
                          onRefresh: notifier.refresh,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                            itemCount: jobs.length,
                            itemBuilder: (ctx, i) => _NewJobCard(
                              key: ValueKey(jobs[i].id),
                              job: jobs[i],
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const WorkerBottomNavBar(currentIndex: 1),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  final NewJobsNotifier notifier;
  const _FilterBar({required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider to rebuild when filter changes.
    ref.watch(newJobsProvider);
    final current = notifier.currentFilter;
    final c = context.semanticColors;

    // Prototype filter chips (lines 348–352): 44 tall, 13.5px, fully round.
    // The taller target matters here — this row is the first thing an Ustaad
    // touches on the screen, often one-handed.
    return SizedBox(
      height: _hChip,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: NewJobFilter.values.map((f) {
          final selected = f == current;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: GestureDetector(
              onTap: () => notifier.setFilter(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: selected ? c.primary : c.surface,
                  borderRadius: BorderRadius.circular(_rPill),
                  border: Border.all(
                    color: selected ? c.primary : c.border,
                  ),
                ),
                child: Text(
                  newJobFilterLabel(context.l10n, f),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? c.onPrimary : c.textSecondary,
                  ),
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

class _NewJobCard extends ConsumerWidget {
  final NewJobEntity job;
  const _NewJobCard({super.key, required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUrgent = job.urgency == BookingUrgency.urgent;
    final isStandard = job.isStandardLane;
    // STANDARD and INSPECTION are both direct-assignment lanes — neither
    // supports bidding, so "Bid Now"/offer-count UI must never show for
    // either (previously only STANDARD was excluded, which incorrectly left
    // a "Bid Now" button on pending INSPECTION jobs).
    final isDirectAssign = job.isDirectAssignLane;
    final c = context.semanticColors;

    // The customer's name — the prototype puts it directly under the job
    // title, and unlike Home's ongoing job this payload actually carries it.
    final clientName =
        '${job.client.firstName} ${job.client.lastName}'.trim();

    // Everything the old card said in four separate 11.5px chips, on one
    // 15.5px line the way the prototype writes it. The pieces and their
    // conditions are unchanged — only the joining is new.
    final metaParts = <String>[
      if (job.city.isNotEmpty) job.city,
      if (job.distanceKm != null)
        workerDistanceLabel(context.l10n, job.distanceKm),
      if (!isDirectAssign) context.l10n.workerOfferCount(job.bidCount),
      _relativeTime(context, job.createdAt),
    ];

    return GestureDetector(
      onTap: () {
        debugPrint('[NewJobCard] card tapped job.id=${job.id} — navigating to details');
        context.push('/worker/job/${job.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: _gap),
        padding: const EdgeInsets.all(15),
        // Prototype `.crd`: surface, radius 16, one hairline. No shadow, and
        // no coloured strip — urgency is a tag now, which is how the
        // prototype says the same thing.
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(_rCard),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tags + money ──────────────────────────────────────────────
            //
            // Same three badge conditions as before, moved from a right-hand
            // column into the prototype's tag row.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (isDirectAssign)
                        const _StandardJobBadge()
                      else
                        _UrgencyChip(isUrgent: isUrgent),
                      if (!isDirectAssign && job.hasMyBid)
                        const _BidPlacedBadge(),
                      if (job.inspection) const InspectionBadge(small: true),
                    ],
                  ),
                ),
                // A price only exists on the STANDARD lane before hire. A
                // BIDDING job has none by definition — the Ustaad sets it —
                // and INSPECTION keeps its own labelled line below, because a
                // bare figure up here would read as the job price rather than
                // the inspection fee.
                //
                // Guarded on the items, not on the total: `standardServicesTotal`
                // is a non-nullable fold over them, so an empty list would
                // print "Rs 0" rather than nothing. Same guard the services
                // line below has always used.
                if (isStandard && job.standardServiceItems.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Text(
                    formatPkr(job.standardServicesTotal),
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // ── Title ─────────────────────────────────────────────────────
            Text(
              job.displayTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: c.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Customer ──────────────────────────────────────────────────
            if (clientName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                clientName,
                style: TextStyle(fontSize: 15.5, color: c.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // ── Meta ──────────────────────────────────────────────────────
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 16, color: c.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    metaParts.join(' · '),
                    style: TextStyle(fontSize: 15.5, color: c.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // ── STANDARD lane: what the customer actually listed ──────────
            // The total that used to sit under this line has moved to the
            // top-right; the services themselves stay.
            if (isStandard && job.standardServiceItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                job.standardServiceItems.map((i) => i.nameSnapshot).join(' + '),
                style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // ── INSPECTION lane: the fixed fee, known before hire ──────────
            // BIDDING never gets a price here — job.displayPrice is null
            // before a bid is accepted, and this card is always for a
            // not-yet-hired job.
            if (job.isInspectionLane && job.displayPrice != null) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.chooseInspectionFeeAmount(
                  formatPkr(job.displayPrice),
                ),
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: c.primary,
                ),
              ),
            ],

            // ── Description snippet ───────────────────────────────────────
            if (job.description != null && job.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                job.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: c.textSecondary,
                  height: 1.45,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // ── Action buttons ────────────────────────────────────────────
            //
            // "View Details" as a third control is gone: it pushed
            // `/worker/job/:id`, which is exactly where tapping the card
            // already goes. On a direct-assign job — where there is no offer
            // to send — it becomes the one big button instead, so that route
            // still has a control of its own. Chat keeps its own tap target.
            const SizedBox(height: 13),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _hButton,
                  height: _hButton,
                  child: GestureDetector(
                    onTap: () =>
                        openWorkerChatForBooking(context, ref, job.id),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.softTeal,
                        borderRadius: BorderRadius.circular(_rButton),
                        border: Border.all(color: c.primary),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: c.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                if (!isDirectAssign)
                  // Bid Now / Update Bid — same guard, same route, same
                  // title encoding as before.
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (!ensureApprovedOrWarn(context, ref)) return;
                        debugPrint('[NewJobCard] bid button pressed job.id=${job.id}');
                        final title = Uri.encodeComponent(job.displayTitle);
                        context.push('/worker/job/${job.id}/bid?title=$title');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.onPrimary,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(_hButton),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_rButton),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(job.hasMyBid
                          ? context.l10n.workerChangeOffer
                          : context.l10n.workerSendOffer),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        debugPrint('[NewJobCard] "View Details" pressed job.id=${job.id}');
                        context.push('/worker/job/${job.id}');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.onPrimary,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(_hButton),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_rButton),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(context.l10n.workerViewJobDetails),
                    ),
                  ),
              ],
            ),
            if (isDirectAssign) ...[
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: c.softTeal,
                  borderRadius: BorderRadius.circular(_rButton),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: c.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.l10n.workerDirectHireNote,
                        style: TextStyle(fontSize: 13, color: c.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _relativeTime(BuildContext context, DateTime dt) {
    final l10n = context.l10n;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return l10n.timeJustNow;
    if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
    return DateFormat('MMM d').format(dt);
  }
}

// ── Standard job badge ─────────────────────────────────────────────────────────

// ── Badges ────────────────────────────────────────────────────────────────────
//
// All three are the prototype's `.tg` tag (CSS lines 74–78): 12.5px / 700,
// fully round, a state colour on its own tint. Only the paint changed — which
// badge appears when is decided in _NewJobCard, exactly as before.

class _StandardJobBadge extends StatelessWidget {
  const _StandardJobBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.softTeal,
        borderRadius: BorderRadius.circular(_rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 13, color: c.primary),
          const SizedBox(width: 4),
          Text(
            context.l10n.workerListedJob,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: c.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BidPlacedBadge extends StatelessWidget {
  const _BidPlacedBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.successSoft,
        borderRadius: BorderRadius.circular(_rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 13, color: c.success),
          const SizedBox(width: 4),
          Text(
            context.l10n.workerOfferSent,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: c.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgencyChip extends StatelessWidget {
  final bool isUrgent;
  const _UrgencyChip({required this.isUrgent});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    // `urgent`, not `error`: the token file draws that line explicitly —
    // urgent is not a failure. A normal job is simply not urgent, so it takes
    // the muted tag rather than a colour of its own.
    final fg = isUrgent ? c.urgent : c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isUrgent ? c.urgentSoft : c.surfaceSubtle,
        borderRadius: BorderRadius.circular(_rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUrgent ? Icons.bolt_rounded : Icons.schedule_rounded,
            size: 13,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            isUrgent ? context.l10n.postJobUrgent : context.l10n.postJobNormal,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// `_MetaChip` is gone: the four 11.5px chips it drew are one 15.5px line on
// the card now, the way the prototype writes them.

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: c.softTeal,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🔍', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.workerNoNewJobs,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.workerNoNewJobsHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                color: c.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshFailedBanner extends StatelessWidget {
  const _RefreshFailedBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      width: double.infinity,
      color: c.warningSurface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      child: Text(
        context.l10n.myBookingsRefreshFailed,
        style: TextStyle(fontSize: 14, color: c.warning),
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
                color: c.urgentSoft,
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
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: c.textSecondary,
                height: 1.45,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                alignment: Alignment.center,
                constraints: const BoxConstraints(minHeight: _hButton),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(_rButton),
                ),
                child: Text(
                  context.l10n.commonRetry,
                  style: TextStyle(
                    color: c.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
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
