import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/nearby_worker_entity.dart';
import '../../domain/entities/nearby_worker_profile_entity.dart';
import '../providers/booking_providers.dart';
import '../widgets/client_chat_action.dart';
import '../../../bookings/presentation/utils/worker_labels.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../utils/booking_labels.dart';

// Every colour on this screen comes from `context.semanticColors`. The six
// `_k*` constants that used to sit at the top of this file — including
// EasyRepair's orange `#DB6234`, which is not in the Ustaad prototype — are
// gone, and so is the card `BoxShadow`: a card here is `surface` + radius 16
// + a 1px `border` hairline, nothing else.

// Shared shape values, matching the Ustaad prototype.
const double _rCard = 16;
const double _rButton = 14;
const double _rPill = 999;

/// Minimum height of the two card actions. `Chunain` is the card's primary
/// button, so it takes the prototype's 52; the chat control matches it so the
/// pair reads as one row at every text scale.
const double _hAction = 52;

/// Worker-selection page for STANDARD and INSPECTION lane bookings (fixed
/// price/fee — no bidding). Shown right after a booking is confirmed for
/// those two lanes; the known-problem/BIDDING lane keeps using
/// WorkerDiscoveryMapPage instead.
class ChooseUstaadPage extends ConsumerStatefulWidget {
  final BookingEntity booking;

  const ChooseUstaadPage({super.key, required this.booking});

  @override
  ConsumerState<ChooseUstaadPage> createState() => _ChooseUstaadPageState();
}

class _ChooseUstaadPageState extends ConsumerState<ChooseUstaadPage> {
  bool _assigning = false;
  // Tracks which worker's chat request is currently in flight so a rapid
  // double-tap can't fire a second get-or-create for the same worker, while
  // still letting the client tap Chat on a different worker's card.
  String? _chattingWorkerId;

  Future<void> _confirmAndSelectWorker(NearbyWorkerEntity worker) async {
    if (_assigning) return;
    final c = context.semanticColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          context.l10n.chooseHireConfirmTitle,
          style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary),
        ),
        content: Text(
          context.l10n.chooseHireConfirmBodyFull(worker.fullName),
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
                borderRadius: BorderRadius.circular(_rButton),
              ),
            ),
            child: Text(context.l10n.chooseSelect),
          ),
        ],
      ),
    );
    if (confirmed == true) await _selectWorker(worker);
  }

  Future<void> _selectWorker(NearbyWorkerEntity worker) async {
    if (_assigning) return;
    setState(() => _assigning = true);
    try {
      await ref
          .read(assignWorkerNotifierProvider.notifier)
          .assign(widget.booking.id, worker.id);
      // Booking is no longer eligible for worker selection — stop the
      // controlled STANDARD-lane recheck loop right away rather than
      // waiting for the page to dispose.
      if (widget.booking.lane == BookingLane.standard) {
        ref
            .read(
              standardNearbyWorkersNotifierProvider(widget.booking.id).notifier,
            )
            .stop();
      }
      if (!mounted) return;
      context.pushReplacement('/client/booking/${widget.booking.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _assigning = false);
      final isConflict = e is ConflictFailure;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isConflict ? e.message : context.l10n.chooseAssignFailed,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: context.semanticColors.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rButton),
          ),
        ),
      );
      if (isConflict) {
        // Worker became unavailable between list fetch and hire tap — refresh
        // so the now-busy worker drops out of the list (backend already
        // filters currentlyWorking=false, so a fresh fetch excludes them).
        await _refreshSearch();
      }
    }
  }

  Future<void> _refreshSearch() async {
    if (widget.booking.lane == BookingLane.standard) {
      await _refreshStandardSearch();
    } else {
      await ref
          .read(nearbyWorkersNotifierProvider(widget.booking.id).notifier)
          .refresh();
    }
  }

  Future<void> _chatWithWorker(NearbyWorkerEntity worker) async {
    if (_chattingWorkerId != null) return;
    setState(() => _chattingWorkerId = worker.id);
    try {
      // Uses the client-facing endpoint (workerProfileId-based) — this is a
      // candidate worker not yet assigned to the booking, so the worker-only
      // "for-booking" endpoint would 403 here. bookingId lets the backend
      // verify this worker is actually in this booking's eligible/nearby set.
      await openClientChatWithWorker(
        context,
        ref,
        widget.booking.id,
        worker.id,
      );
    } finally {
      if (mounted) setState(() => _chattingWorkerId = null);
    }
  }

  Future<void> _refreshStandardSearch() async {
    await ref
        .read(standardNearbyWorkersNotifierProvider(widget.booking.id).notifier)
        .refresh();
  }

  /// Opens the Ustaad's detail sheet ON this page — the list underneath keeps
  /// its scroll offset, and nothing about the worker is selected by looking.
  void _openProfileModal(NearbyWorkerEntity worker) {
    final c = context.semanticColors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) =>
          _WorkerProfileSheet(bookingId: widget.booking.id, worker: worker),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final booking = widget.booking;
    final bool isStandard = booking.lane == BookingLane.standard;
    // STANDARD lane uses the capped 5km->7km controlled-polling notifier;
    // INSPECTION keeps the existing wide-ladder notifier unchanged.
    final nearbyState = isStandard
        ? ref.watch(standardNearbyWorkersNotifierProvider(booking.id))
        : ref.watch(nearbyWorkersNotifierProvider(booking.id));

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(availableCount: nearbyState.workers.length),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              sliver: SliverToBoxAdapter(
                child: _JobSummaryCard(
                  booking: booking,
                  isStandard: isStandard,
                ),
              ),
            ),
            ..._bodySlivers(nearbyState, isStandard),
          ],
        ),
      ),
    );
  }

  /// The list (or its skeleton/empty stand-ins) as slivers.
  ///
  /// The header and the job summary scroll WITH the list rather than sitting
  /// in a fixed Column above it: at a 2.0 text scale on a 320px phone those
  /// two alone are taller than the viewport, and a Column would push the
  /// difference off the bottom instead of letting the client scroll to it.
  List<Widget> _bodySlivers(NearbyWorkersState state, bool isStandard) {
    final c = context.semanticColors;

    // First load in flight, nothing to show yet at all — skeleton cards
    // instead of a spinner or (worse) a scary error-looking empty state.
    if (state.isExpanding && state.workers.isEmpty && !state.hasError) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          sliver: SliverToBoxAdapter(
            child: Text(
              context.l10n.chooseFindingUstaads,
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          sliver: SliverList.builder(
            itemCount: 3,
            itemBuilder: (_, index) => Padding(
              padding: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
              child: const _WorkerCardSkeleton(),
            ),
          ),
        ),
      ];
    }

    if (state.hasError && state.workers.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _EmptyState(
            icon: Icons.wifi_off_rounded,
            title: context.l10n.chooseLoadFailed,
            onRefresh: _refreshSearch,
          ),
        ),
      ];
    }

    if (state.workers.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _EmptyState(
            icon: Icons.person_search_rounded,
            title: context.l10n.chooseNoUstaadAvailable,
            helper: isStandard
                ? context.l10n.chooseAutoRefreshNote
                : context.l10n.chooseRefreshOrWait,
            onRefresh: _refreshSearch,
          ),
        ),
      ];
    }

    final count = state.workers.length + (state.isExpanding ? 1 : 0);
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        sliver: SliverList.builder(
          itemCount: count,
          itemBuilder: (context, index) {
            if (index >= state.workers.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final worker = state.workers[index];
            return Padding(
              padding: EdgeInsets.only(bottom: index == count - 1 ? 0 : 12),
              child: _WorkerCard(
                key: ValueKey(worker.id),
                worker: worker,
                busy: _assigning,
                chatting: _chattingWorkerId == worker.id,
                onAvatarTap: () => _openProfileModal(worker),
                onSelect: () => _confirmAndSelectWorker(worker),
                onChat: () => _chatWithWorker(worker),
              ),
            );
          },
        ),
      ),
    ];
  }
}

/// Back action + "Ustaad chunain" + the nearest-first / availability line.
///
/// A plain header rather than an `AppBar` so the two-line title grows with the
/// text scale instead of being clipped to a fixed toolbar height.
class _Header extends StatelessWidget {
  final int availableCount;

  const _Header({required this.availableCount});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final l10n = context.l10n;
    final subtitle = availableCount > 0
        ? '${l10n.chooseNearestFirst} · ${l10n.chooseAvailableCount(availableCount)}'
        : l10n.chooseNearestFirst;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            iconSize: 22,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            color: c.textPrimary,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.bookingChooseUstaad,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: c.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The job the client is hiring for, as one compact bordered surface.
///
/// STANDARD shows the selected services and their total; INSPECTION shows the
/// inspection fee. The pricing semantics are the booking's own — this only
/// lays them out.
class _JobSummaryCard extends StatelessWidget {
  final BookingEntity booking;
  final bool isStandard;

  const _JobSummaryCard({required this.booking, required this.isStandard});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final l10n = context.l10n;
    final double? standardTotal = isStandard
        ? booking.standardServicesTotal
        : null;

    // The headline line of the card: for STANDARD the selected services read
    // better than the bare category; INSPECTION keeps the category.
    final items = booking.standardServiceItems;
    final String headline = isStandard && items.isNotEmpty
        ? items
              .map(
                (i) => i.quantity > 1
                    ? l10n.bookingServiceQuantity(i.nameSnapshot, i.quantity)
                    : i.nameSnapshot,
              )
              .join(', ')
        : booking.serviceCategory;

    final String? amount = isStandard
        ? (standardTotal != null ? formatPkr(standardTotal) : null)
        : (booking.inspectionFeeSnapshot != null
              ? formatPkr(booking.inspectionFeeSnapshot)
              : null);

    final String? amountLabel = isStandard
        ? l10n.postJobTotal
        : (amount != null ? l10n.postJobInspectionFeeLower : null);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                    height: 1.35,
                  ),
                ),
                if (!isStandard) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.inspectionBadge,
                    style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (amount != null) ...[
            const SizedBox(width: 12),
            Flexible(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (amountLabel != null)
                    Text(
                      amountLabel,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: c.textSecondary,
                      ),
                    ),
                  Text(
                    amount,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.primary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? helper;
  final Future<void> Function() onRefresh;

  const _EmptyState({
    required this.icon,
    required this.title,
    this.helper,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: c.textSecondary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(
              helper!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: c.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _RefreshButton(onTap: onRefresh),
        ],
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RefreshButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: c.primary,
        side: BorderSide(color: c.controlBorder),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rButton),
        ),
      ),
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: Text(
        context.l10n.discoveryRefresh,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Pulsing placeholder shown in place of a [_WorkerCard] while the first
/// nearby-workers fetch is in flight. Matches _WorkerCard's shape so the list
/// doesn't jump when real cards swap in.
class _WorkerCardSkeleton extends StatefulWidget {
  const _WorkerCardSkeleton();

  @override
  State<_WorkerCardSkeleton> createState() => _WorkerCardSkeletonState();
}

class _WorkerCardSkeletonState extends State<_WorkerCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bone(BuildContext context, {double? width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.semanticColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return FadeTransition(
      opacity: Tween(begin: 0.5, end: 1.0).animate(_controller),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(_rCard),
          border: Border.all(color: c.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surfaceSubtle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bone(context, width: 120, height: 14),
                  const SizedBox(height: 8),
                  _bone(context, width: 80, height: 12),
                  const SizedBox(height: 12),
                  _bone(context, height: _hAction),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One Ustaad in the list: identity + the facts a client picks on, then the
/// two actions. Deliberately compact — the rest of the profile lives in the
/// detail sheet behind the avatar.
class _WorkerCard extends StatelessWidget {
  final NearbyWorkerEntity worker;
  final bool busy;
  final bool chatting;
  final VoidCallback onAvatarTap;
  final VoidCallback onSelect;
  final VoidCallback onChat;

  const _WorkerCard({
    super.key,
    required this.worker,
    required this.busy,
    this.chatting = false,
    required this.onAvatarTap,
    required this.onSelect,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: l10n.chooseViewProfile,
                child: Tooltip(
                  message: l10n.chooseViewProfile,
                  child: InkWell(
                    onTap: onAvatarTap,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      // Keeps the tap target comfortably past 48dp without
                      // growing the avatar itself.
                      padding: const EdgeInsets.all(2),
                      child: _WorkerAvatar.forWorker(worker: worker, radius: 26),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            worker.fullName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: _LevelBadge(
                            label: workerLevelBadge(l10n, worker.completedJobs),
                          ),
                        ),
                      ],
                    ),
                    if (worker.recommended) ...[
                      const SizedBox(height: 6),
                      const _RecommendedBadge(),
                    ],
                    const SizedBox(height: 6),
                    _WorkerMetaLine(worker: worker),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ChatButton(
                busy: busy,
                chatting: chatting,
                onChat: onChat,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _hAction),
                  child: ElevatedButton(
                    onPressed: busy ? null : onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: c.onPrimary,
                      disabledBackgroundColor: c.surfaceSubtle,
                      disabledForegroundColor: c.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_rButton),
                      ),
                      elevation: 0,
                    ),
                    child: busy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.textSecondary,
                            ),
                          )
                        : Text(
                            l10n.chooseSelect,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

/// The facts a client scans a card for, as one wrapping line. Every value
/// comes from the nearby-workers payload — nothing here is derived.
class _WorkerMetaLine extends StatelessWidget {
  final NearbyWorkerEntity worker;

  const _WorkerMetaLine({required this.worker});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final l10n = context.l10n;

    Widget chip(IconData icon, String label, {Color? color}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? c.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: color ?? c.textSecondary,
              fontWeight: color != null ? FontWeight.w600 : null,
            ),
          ),
        ),
      ],
    );

    final years = worker.relevantExperienceYears;

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        // Server-computed from the admin's CNIC-vs-selfie match; the card
        // never derives it from status or profile completeness.
        if (worker.cnicVerified)
          chip(
            Icons.verified_rounded,
            l10n.chooseCnicVerified,
            color: c.success,
          ),
        chip(
          Icons.star_rounded,
          worker.rating > 0
              ? worker.rating.toStringAsFixed(1)
              : l10n.chooseNewBadge,
        ),
        // Years on the skill this booking is about — never a sum, and absent
        // rather than zero when the backend has none.
        if (years != null && years > 0)
          chip(Icons.workspace_premium_rounded, l10n.chooseExperienceYears(years)),
        chip(Icons.task_alt_rounded, l10n.bidJobCount(worker.completedJobs)),
        chip(
          Icons.location_on_rounded,
          workerDistanceLabel(l10n, worker.distanceKm),
        ),
      ],
    );
  }
}

/// Secondary action beside `Chunain` — opens (or creates, idempotently) the
/// conversation with this Ustaad and pushes it, so back returns here.
class _ChatButton extends StatelessWidget {
  final bool busy;
  final bool chatting;
  final VoidCallback onChat;

  const _ChatButton({
    required this.busy,
    required this.chatting,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final label = context.l10n.chatTitleFallback;

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: OutlinedButton(
          onPressed: (busy || chatting) ? null : onChat,
          style: OutlinedButton.styleFrom(
            foregroundColor: c.primary,
            backgroundColor: c.surfaceSubtle,
            disabledForegroundColor: c.textSecondary,
            side: BorderSide(color: c.controlBorder),
            padding: EdgeInsets.zero,
            minimumSize: const Size(_hAction, _hAction),
            fixedSize: const Size(_hAction, _hAction),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_rButton),
            ),
          ),
          child: chatting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.primary,
                  ),
                )
              : const Icon(Icons.chat_bubble_outline_rounded, size: 20),
        ),
      ),
    );
  }
}

class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.warningSurface,
        borderRadius: BorderRadius.circular(_rPill),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.thumb_up_alt_rounded, size: 13, color: c.warning),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              context.l10n.chooseRecommended,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

class _LevelBadge extends StatelessWidget {
  final String label;

  const _LevelBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.softTeal,
        borderRadius: BorderRadius.circular(_rPill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: c.primary,
        ),
      ),
    );
  }
}

class _WorkerAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final double radius;

  const _WorkerAvatar({
    required this.avatarUrl,
    required this.initials,
    required this.radius,
  });

  _WorkerAvatar.forWorker({required NearbyWorkerEntity worker, required this.radius})
    : avatarUrl = worker.avatarUrl,
      initials = worker.initials;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final url = avatarUrl;
    final hasImage = url != null && url.isNotEmpty;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.softTeal,
        image: hasImage
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasImage
          ? null
          : Text(
              initials,
              style: TextStyle(
                fontSize: radius * 0.55,
                fontWeight: FontWeight.w700,
                color: c.primary,
              ),
            ),
    );
  }
}

/// Ustaad detail, opened by tapping the avatar and dismissed by dragging or
/// tapping outside. Scrolls, so long names, many skills, long review text and
/// a 2.0 text scale all stay reachable on a small phone.
///
/// The identity strip renders instantly from the list row the client already
/// tapped; everything behind it comes from
/// GET /bookings/:id/nearby-workers/:workerProfileId/profile, which is only
/// requested when this sheet opens. A failed request degrades to a retry
/// inside the sheet — it never closes the sheet or the list underneath.
class _WorkerProfileSheet extends ConsumerWidget {
  final String bookingId;
  final NearbyWorkerEntity worker;

  const _WorkerProfileSheet({required this.bookingId, required this.worker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.semanticColors;
    final key = (bookingId: bookingId, workerProfileId: worker.id);
    final profileAsync = ref.watch(nearbyWorkerProfileProvider(key));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(_rPill),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    _ProfileIdentity(
                      worker: worker,
                      profile: profileAsync.valueOrNull,
                    ),
                    const SizedBox(height: 18),
                    profileAsync.when(
                      data: (profile) => _ProfileDetail(profile: profile),
                      loading: () => const _ProfileLoading(),
                      error: (_, _) => _ProfileError(
                        onRetry: () => ref.invalidate(
                          nearbyWorkerProfileProvider(key),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Avatar, name and — once the profile arrives — the CNIC badge and rating.
/// Rendered from the list row first so the sheet is never blank.
class _ProfileIdentity extends StatelessWidget {
  final NearbyWorkerEntity worker;
  final NearbyWorkerProfileEntity? profile;

  const _ProfileIdentity({required this.worker, this.profile});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final l10n = context.l10n;
    final rating = profile?.averageRating ?? worker.rating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: _WorkerAvatar(
            avatarUrl: profile?.avatarUrl ?? worker.avatarUrl,
            initials: profile?.initials ?? worker.initials,
            radius: 44,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          profile?.fullName ?? worker.fullName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
            height: 1.25,
          ),
        ),
        if (profile?.cnicVerified ?? false) ...[
          const SizedBox(height: 8),
          const Center(child: _CnicVerifiedBadge()),
        ],
        const SizedBox(height: 8),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, size: 18, color: c.warning),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  rating > 0
                      ? rating.toStringAsFixed(1)
                      : l10n.workerRatingNone,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
              ),
              if (profile != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.reviewsCount(profile!.totalReviews),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "✓ CNIC Verified Ustaad" — shown only when the backend says an admin
/// matched the CNIC photos to the live selfie. Never renders the CNIC number
/// or any document image.
class _CnicVerifiedBadge extends StatelessWidget {
  const _CnicVerifiedBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: c.successSoft,
        borderRadius: BorderRadius.circular(_rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 15, color: c.success),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              context.l10n.chooseCnicVerifiedUstaad,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: c.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing stand-ins while the profile request is in flight.
class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    Widget bone({double? width, required double height}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
          ),
        ),
        const SizedBox(height: 20),
        bone(width: 140, height: 14),
        const SizedBox(height: 10),
        bone(height: 46),
        const SizedBox(height: 18),
        bone(width: 100, height: 14),
        const SizedBox(height: 10),
        bone(height: 72),
      ],
    );
  }
}

/// The profile failed to load. Only this section is replaced — the sheet
/// stays open and the Ustaad list underneath is untouched.
class _ProfileError extends StatelessWidget {
  final VoidCallback onRetry;

  const _ProfileError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Column(
      children: [
        Icon(Icons.wifi_off_rounded, size: 28, color: c.textSecondary),
        const SizedBox(height: 10),
        Text(
          context.l10n.chooseProfileLoadFailed,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            foregroundColor: c.primary,
            side: BorderSide(color: c.controlBorder),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_rButton),
            ),
          ),
          child: Text(
            context.l10n.commonRetry,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Stats, skills, contact and reviews — all from the profile endpoint.
class _ProfileDetail extends StatelessWidget {
  final NearbyWorkerProfileEntity profile;

  const _ProfileDetail({required this.profile});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final l10n = context.l10n;
    final years = profile.relevantExperienceYears;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 14,
          children: [
            _StatBlock(
              value: '${profile.completedJobs}',
              label: l10n.workerJobsDone,
            ),
            if (years != null)
              _StatBlock(
                value: '$years',
                label: l10n.workerExperienceYears,
              ),
            _StatBlock(
              value: '${profile.totalReviews}',
              label: l10n.workerReviews,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SheetSectionTitle(label: l10n.chooseSkills),
        const SizedBox(height: 8),
        if (profile.skills.isEmpty)
          Text(
            l10n.workerSkillNotSelected,
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final skill in profile.skills)
                _SkillChip(
                  label: skill.yearsExperience > 0
                      ? '${skill.name} · ${l10n.chooseExperienceYears(skill.yearsExperience)}'
                      : skill.name,
                ),
            ],
          ),
        if (profile.phone != null && profile.phone!.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SheetSectionTitle(label: l10n.choosePhoneLabel),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.phone_rounded, size: 16, color: c.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  profile.phone!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        _SheetSectionTitle(label: l10n.workerReviews),
        const SizedBox(height: 8),
        if (profile.reviews.isEmpty)
          Text(
            l10n.chooseNoReviews,
            style: TextStyle(fontSize: 14, color: c.textSecondary),
          )
        else
          for (final review in profile.reviews)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ReviewCard(review: review),
            ),
      ],
    );
  }
}

/// One real review. Reviewer text is rendered verbatim and wraps freely.
class _ReviewCard extends StatelessWidget {
  final NearbyWorkerReviewEntity review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final comment = review.comment?.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.star_rounded, size: 15, color: c.warning),
              const SizedBox(width: 3),
              Text(
                '${review.rating}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              // Reviewer and date share one wrapping run rather than sitting
              // in two fixed cells — at a 2.0 text scale a localised medium
              // date is wider than the whole card.
              Expanded(
                child: Text(
                  '${review.reviewerName ?? review.serviceCategory} · '
                  '${MaterialLocalizations.of(context).formatMediumDate(review.createdAt)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              comment,
              style: TextStyle(
                fontSize: 13.5,
                color: c.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SheetSectionTitle extends StatelessWidget {
  final String label;

  const _SheetSectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: context.semanticColors.textPrimary,
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String value;
  final String label;

  const _StatBlock({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: c.textSecondary),
        ),
      ],
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String label;

  const _SkillChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(_rPill),
        border: Border.all(color: c.border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12.5, color: c.textPrimary),
      ),
    );
  }
}
