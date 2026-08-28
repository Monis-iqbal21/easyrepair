import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import 'track_worker_page.dart';
import '../../../bids/domain/entities/bid_entity.dart';
import '../../../bids/domain/repositories/bid_repository.dart';
import '../../../bids/presentation/providers/bid_providers.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../../bookings/presentation/providers/booking_providers.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../bookings/presentation/utils/worker_labels.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/errors/failure_messages.dart';

const double _rCard = 16;
const double _rButton = 14;
const double _hAction = 52;

// ── Page ─────────────────────────────────────────────────────────────────────

class WorkerDiscoveryMapPage extends ConsumerStatefulWidget {
  final BookingEntity booking;
  const WorkerDiscoveryMapPage({super.key, required this.booking});

  @override
  ConsumerState<WorkerDiscoveryMapPage> createState() =>
      _WorkerDiscoveryMapPageState();
}

class _WorkerDiscoveryMapPageState extends ConsumerState<WorkerDiscoveryMapPage> {
  GoogleMapController? _mapCtrl;
  Timer? _bidsRefreshTimer;

  // Deduplication: track workers already logged for missing location.
  final Set<String> _loggedMissingLocationWorkers = {};

  // Cache previous marker set to avoid rebuilding map when bids haven't changed.
  Set<Marker>? _cachedMarkers;
  List<BidWithWorkerEntity> _prevPendingBids = [];

  @override
  void initState() {
    super.initState();
    _bidsRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) ref.invalidate(bookingBidsProvider(widget.booking.id));
    });
  }

  @override
  void dispose() {
    _bidsRefreshTimer?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Set<Circle> _buildCircles(LatLng jobPos) {
    final colors = context.semanticColors;
    return {
      Circle(
        circleId: const CircleId('job_search_radius_outer'),
        center: jobPos,
        radius: 400,
        fillColor: colors.softTeal.withValues(alpha: 0.8),
        strokeColor: colors.primary.withValues(alpha: 0.55),
        strokeWidth: 2,
      ),
      Circle(
        circleId: const CircleId('job_search_radius_inner'),
        center: jobPos,
        radius: 180,
        fillColor: colors.softTeal,
        strokeColor: colors.primary.withValues(alpha: 0.7),
        strokeWidth: 1,
      ),
    };
  }

  Set<Marker> _buildMarkers(
    LatLng? jobPos,
    List<BidWithWorkerEntity> pending,
  ) {
    // Only rebuild when bids actually changed.
    if (_cachedMarkers != null &&
        _listsEqual(_prevPendingBids, pending)) {
      return _cachedMarkers!;
    }
    _prevPendingBids = pending;

    final markers = <Marker>{};

    if (jobPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('job'),
        position: jobPos,
        infoWindow: InfoWindow(
          title: context.l10n.discoveryJobLocation,
          snippet: widget.booking.address ?? widget.booking.city,
        ),
      ));
    }

    for (final bw in pending) {
      if (bw.currentLat == null || bw.currentLng == null) {
        _loggedMissingLocationWorkers.add(bw.workerProfileId);
        continue;
      }
      markers.add(
        Marker(
          markerId: MarkerId('worker_${bw.workerProfileId}'),
          position: LatLng(bw.currentLat!, bw.currentLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: bw.firstName,
            snippet: formatPkr(bw.bid.amount),
          ),
        ),
      );
    }
    _cachedMarkers = markers;
    return markers;
  }

  bool _listsEqual(
      List<BidWithWorkerEntity> a, List<BidWithWorkerEntity> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].workerProfileId != b[i].workerProfileId ||
          a[i].bid.amount != b[i].bid.amount) { return false; }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final safeTop = MediaQuery.of(context).padding.top;

    final jobLat = widget.booking.latitude;
    final jobLng = widget.booking.longitude;
    final hasLocation = jobLat != 0 || jobLng != 0;
    final jobPos = hasLocation
        ? LatLng(jobLat, jobLng)
        : const LatLng(24.8607, 67.0011);

    final bidsAsync = ref.watch(bookingBidsProvider(widget.booking.id));
    final pendingBids = bidsAsync.whenOrNull(
          data: (bids) => bids
              .where((b) => b.bid.status == BidStatus.pending)
              .toList(),
        ) ??
        [];

    final markers = _buildMarkers(hasLocation ? jobPos : null, pendingBids);
    final circles = hasLocation ? _buildCircles(jobPos) : <Circle>{};

    // Debug: confirm full-screen constraints are received.
    final screenSize = MediaQuery.of(context).size;
    debugPrint('[WorkerBidsMap] screen=${screenSize.width}x${screenSize.height}');

    final Widget mapWidget = GoogleMap(
      initialCameraPosition:
          CameraPosition(target: jobPos, zoom: hasLocation ? 13.5 : 11.0),
      onMapCreated: (c) => _mapCtrl = c,
      markers: markers,
      circles: circles,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );

    return Scaffold(
      body: Stack(
        // StackFit.expand forces every non-Positioned child to fill the Stack,
        // which is what gives DraggableScrollableSheet(expand:false) the full
        // screen height it needs to calculate childSize percentages correctly.
        fit: StackFit.expand,
        children: [
          // ── Full-screen map ────────────────────────────────────────────────
          Positioned.fill(child: mapWidget),

          // ── No location banner ─────────────────────────────────────────────
          if (!hasLocation)
            Positioned(
              top: safeTop + 12,
              left: 60,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  context.l10n.discoveryJobLocationUnavailable,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ),
            ),

          // ── Back button ────────────────────────────────────────────────────
          Positioned(
            top: safeTop + 8,
            left: 12,
            child: Material(
              color: colors.surface,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),

          // ── Draggable bottom sheet ─────────────────────────────────────────
          // Placed directly in Stack with StackFit.expand — it receives
          // full-screen constraints and anchors itself to the bottom.
          DraggableScrollableSheet(
            initialChildSize: 0.20,
            minChildSize: 0.20,
            maxChildSize: 0.60,
            snap: true,
            snapSizes: const [0.20, 0.40, 0.60],
            expand: false,
            builder: (ctx, scrollCtrl) {
              return Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  border: Border.all(color: colors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: _BidsSheet(
                  booking: widget.booking,
                  scrollController: scrollCtrl,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Draggable sheet ────────────────────────────────────────────────────────────

class _BidsSheet extends ConsumerWidget {
  final BookingEntity booking;
  final ScrollController scrollController;

  const _BidsSheet({required this.booking, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.semanticColors;
    final bidsAsync = ref.watch(bookingBidsProvider(booking.id));

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        // ── Fixed header (drag handle + title + divider) ──────────────────
        SliverToBoxAdapter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header row
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 2, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.discoveryLiveWorkerOffers,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _SheetSubtitle(bidsAsync: bidsAsync),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                      tooltip: context.l10n.discoveryRefresh,
                      onPressed: () =>
                          ref.invalidate(bookingBidsProvider(booking.id)),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: colors.border),
            ],
          ),
        ),

        // ── Pinned inspecting-Ustaad card (post-inspection "Find Other
        // Ustaad" flow only) — not a normal competing bid, shown once above
        // the bid list, with the option to re-hire them using their
        // original quote instead of a submitted Bid.
        if (booking.isOpenForFindOtherUstaadBidding &&
            booking.inspectingWorker != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _InspectingWorkerOfferCard(
                worker: booking.inspectingWorker!,
                bookingId: booking.id,
              ),
            ),
          ),

        // ── Bid list / states ─────────────────────────────────────────────
        bidsAsync.when(
          skipError: true,
          loading: () =>
              SliverToBoxAdapter(child: _LoadingState()),
          error: (err, _) => SliverToBoxAdapter(
            child: _ErrorState(
              message:
                  failureMessage(context.l10n, err, fallback: context.l10n.discoveryBidsLoadFailed),
              onRetry: () =>
                  ref.invalidate(bookingBidsProvider(booking.id)),
            ),
          ),
          data: (bids) {
            final pending = bids
                .where((b) => b.bid.status == BidStatus.pending)
                .toList()
              ..sort((a, b) => a.bid.amount.compareTo(b.bid.amount));

            if (pending.isEmpty) {
              return const SliverToBoxAdapter(child: _EmptyState());
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final index = i ~/ 2;
                    if (i.isOdd) {
                      return const SizedBox(height: 10);
                    }
                    return _BidOfferCard(
                      key: ValueKey(pending[index].bid.id),
                      bidWorker: pending[index],
                      bookingId: booking.id,
                      isPostInspectionReopen:
                          booking.isOpenForFindOtherUstaadBidding,
                    );
                  },
                  childCount: pending.length * 2 - 1,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Sheet subtitle ────────────────────────────────────────────────────────────

class _SheetSubtitle extends StatelessWidget {
  final AsyncValue<List<BidWithWorkerEntity>> bidsAsync;
  const _SheetSubtitle({required this.bidsAsync});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final text = bidsAsync.when(
      skipError: true,
      loading: () => context.l10n.discoveryLoadingBids,
      error: (e, st) => context.l10n.discoveryBidsLoadFailedShort,
      data: (bids) {
        final count = bids.where((b) => b.bid.status == BidStatus.pending).length;
        if (count == 0) return context.l10n.discoveryNoBidsYet;
        return context.l10n.discoveryPendingBidsSorted(count);
      },
    );
    return Text(
      text,
      style: TextStyle(fontSize: 12, color: colors.textSecondary),
    );
  }
}

// ── Bid offer card ─────────────────────────────────────────────────────────────

class _BidOfferCard extends ConsumerWidget {
  final BidWithWorkerEntity bidWorker;
  final String bookingId;

  /// True when this bid is on a job reopened after inspection (the booking
  /// still has an original inspecting Ustaad) — hiring this bidder is hiring
  /// a DIFFERENT worker than whoever inspected, so the client must be told
  /// the inspection fee is charged separately from this bid.
  final bool isPostInspectionReopen;

  const _BidOfferCard({
    super.key,
    required this.bidWorker,
    required this.bookingId,
    this.isPostInspectionReopen = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.semanticColors;
    final isHiring = ref.watch(acceptBidProvider).isLoading;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Identity follows the Standard/Inspection worker-card hierarchy.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BidAvatar(bidWorker: bidWorker),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bidWorker.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _BidWorkerMetaLine(bidWorker: bidWorker),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // This remains visibly an offer card, not a fixed-price selection
          // card. Keeping the amount on its own trailing-aligned line also
          // lets long names and scaled text wrap without fighting it.
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: colors.softTeal,
                borderRadius: BorderRadius.circular(_rCard),
                border: Border.all(color: colors.primary),
              ),
              child: Text(
                formatPkr(bidWorker.bid.amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
            ),
          ),

          // ── Worker message ─────────────────────────────────────────────────
          if (bidWorker.bid.message != null &&
              bidWorker.bid.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                bidWorker.bid.message!,
                style: TextStyle(
                  fontSize: 12.5,
                  color: colors.textSecondary,
                  height: 1.4,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Action buttons ─────────────────────────────────────────────────
          Row(
            children: [
              _ChatButton(
                bookingId: bookingId,
                workerProfileId: bidWorker.workerProfileId,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _hAction),
                  child: FilledButton.icon(
                    onPressed:
                        isHiring ? null : () => _confirmHire(context, ref),
                    icon: isHiring
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.textSecondary,
                            ),
                          )
                        : const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                          ),
                    label: Text(
                      isHiring
                          ? context.l10n.discoveryHiring
                          : context.l10n.discoveryHire,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      disabledBackgroundColor: colors.surfaceSubtle,
                      disabledForegroundColor: colors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_rButton),
                      ),
                      textStyle: const TextStyle(
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

  Future<void> _confirmHire(BuildContext context, WidgetRef ref) async {
    final colors = context.semanticColors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.l10n.discoveryHireNamed(bidWorker.firstName),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.discoveryAcceptBid(
            bidWorker.fullName,
            formatPkr(bidWorker.bid.amount),
          ),
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
            const SizedBox(height: 10),
            Text(
              isPostInspectionReopen
                  ? context.l10n.discoveryBidInspectionBasedNote
                  : context.l10n.discoveryBidLabourOnlyNote,
              style: TextStyle(
                fontSize: 12.5,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            if (isPostInspectionReopen) ...[
              const SizedBox(height: 10),
              Text(
                context.l10n.discoveryInspectionFeeSeparate,
                style: TextStyle(
                  fontSize: 12.5,
                  color: colors.warning,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              context.l10n.commonCancel,
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
            ),
            child: Text(context.l10n.discoveryHire),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;
    // Re-entry guard — a tap that raced past the disabled button must not
    // fire a second hire request.
    if (ref.read(acceptBidProvider).isLoading) return;

    try {
      await ref.read(acceptBidProvider.notifier).accept(
            bidId: bidWorker.bid.id,
            bookingId: bookingId,
          );
      if (context.mounted) {
        ref.invalidate(bookingDetailProvider(bookingId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.discoveryWorkerHired),
            backgroundColor: colors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => TrackWorkerPage(bookingId: bookingId),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failureMessage(context.l10n, e, fallback: context.l10n.discoveryHireFailed)),
            backgroundColor: colors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

class _BidWorkerMetaLine extends StatelessWidget {
  final BidWithWorkerEntity bidWorker;

  const _BidWorkerMetaLine({required this.bidWorker});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    Widget item(IconData icon, String label, {Color? color}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color ?? colors.textSecondary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: color ?? colors.textSecondary,
                ),
              ),
            ),
          ],
        );

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        item(
          Icons.star_rounded,
          workerRatingLabel(
            context.l10n,
            bidWorker.rating,
            bidWorker.completedJobs,
          ),
          color: colors.warning,
        ),
        item(
          Icons.location_on_rounded,
          workerDistanceLabel(context.l10n, bidWorker.distanceKm),
        ),
        if (bidWorker.skills.isNotEmpty)
          item(
            Icons.home_repair_service_outlined,
            bidWorker.skills.take(3).join(' · '),
          ),
      ],
    );
  }
}

// ── Pinned inspecting-Ustaad card ───────────────────────────────────────────────
// Not a normal competing bid — the customer can re-hire this worker using
// their already-submitted inspection quote instead of accepting a Bid row.

class _InspectingWorkerOfferCard extends ConsumerWidget {
  final AssignedWorkerEntity worker;
  final String bookingId;

  const _InspectingWorkerOfferCard({
    required this.worker,
    required this.bookingId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.semanticColors;
    final reportAsync = ref.watch(inspectionReportProvider(bookingId));
    final isHiring = ref.watch(inspectionDecisionNotifierProvider).isLoading;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.warningSurface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: colors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.warning,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              context.l10n.discoveryInspectedThisJob,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: colors.surface,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
                child: worker.avatarUrl != null
                    ? ClipOval(
                        child: Image.network(
                          worker.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _InitialsLabel(worker.initials),
                        ),
                      )
                    : _InitialsLabel(worker.initials),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (worker.rating != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: colors.warning,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            worker.rating!.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              reportAsync.maybeWhen(
                data: (r) => r.repairQuoteTotal != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colors.warning),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatPkr(r.repairQuoteTotal!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colors.warning,
                              ),
                            ),
                            Text(
                              context.l10n.discoveryTheirQuote,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.warning,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.discoveryInspectionCompletedByThis,
            style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
          ),
          const SizedBox(height: 10),
          // Optional full technical report — never required before deciding.
          GestureDetector(
            onTap: () => context.push(
              '/client/booking/$bookingId/inspection-report?readOnly=1',
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 15,
                  color: colors.warning,
                ),
                const SizedBox(width: 5),
                // Flexible so the label can never overflow this card on a
                // narrow screen.
                Flexible(
                  child: Text(
                    context.l10n.discoveryViewInspectionReport,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: colors.warning,
                      decoration: TextDecoration.underline,
                      decorationColor: colors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ChatButton(
                bookingId: bookingId,
                workerProfileId: worker.id,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _hAction),
                  child: FilledButton.icon(
                    onPressed:
                        isHiring ? null : () => _confirmHire(context, ref),
                    icon: isHiring
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.textSecondary,
                            ),
                          )
                        : const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                          ),
                    label: Text(
                      isHiring
                          ? context.l10n.discoveryHiring
                          : context.l10n.discoveryHireAgain,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.warning,
                      foregroundColor: colors.surface,
                      disabledBackgroundColor: colors.surfaceSubtle,
                      disabledForegroundColor: colors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_rButton),
                      ),
                      textStyle: const TextStyle(
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

  Future<void> _confirmHire(BuildContext context, WidgetRef ref) async {
    final colors = context.semanticColors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.l10n.discoveryHireAgainNamed(worker.firstName),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          context.l10n.discoveryOriginalQuoteContinues,
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              context.l10n.commonCancel,
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.warning,
              foregroundColor: colors.surface,
            ),
            child: Text(context.l10n.discoveryHire),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;
    // Re-entry guard — a tap that raced past the disabled button must not
    // fire a second hire request.
    if (ref.read(inspectionDecisionNotifierProvider).isLoading) return;

    try {
      await ref.read(inspectionDecisionNotifierProvider.notifier).hireInspectingWorker(bookingId);
      if (context.mounted) {
        ref.invalidate(bookingDetailProvider(bookingId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.discoveryWorkerHired),
            backgroundColor: colors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => TrackWorkerPage(bookingId: bookingId),
          ),
        );
      }
    } on InspectorBusyFailure catch (e) {
      // The inspecting Ustaad took another job in the meantime. Nothing was
      // hired and the job is still open — deliberately stay on this bidding
      // list, keep every loaded bid usable, and do NOT invalidate the bids
      // provider or navigate anywhere, so the client can simply pick someone
      // else from the list below.
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: colors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 5),
            ),
          );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failureMessage(context.l10n, e, fallback: context.l10n.discoveryHireFailed)),
            backgroundColor: colors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _BidAvatar extends StatelessWidget {
  final BidWithWorkerEntity bidWorker;
  const _BidAvatar({required this.bidWorker});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
      child: bidWorker.avatarUrl != null
          ? ClipOval(
              child: Image.network(
                bidWorker.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _InitialsLabel(bidWorker.initials),
              ),
            )
          : _InitialsLabel(bidWorker.initials),
    );
  }
}

class _InitialsLabel extends StatelessWidget {
  final String initials;
  const _InitialsLabel(this.initials);

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: colors.onPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Chat button ───────────────────────────────────────────────────────────────

class _ChatButton extends ConsumerStatefulWidget {
  final String bookingId;
  final String workerProfileId;
  const _ChatButton({required this.bookingId, required this.workerProfileId});

  @override
  ConsumerState<_ChatButton> createState() => _ChatButtonState();
}

class _ChatButtonState extends ConsumerState<_ChatButton> {
  bool _loading = false;

  Future<void> _openChat() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final conversation = await ref
          .read(getOrCreateConversationProvider.notifier)
          .getOrCreate(widget.bookingId, widget.workerProfileId);
      if (mounted) {
        context.push('/client/chat/${conversation.id}');
      }
    } catch (e) {
      if (mounted) {
        final colors = context.semanticColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failureMessage(context.l10n, e)),
            backgroundColor: colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final label = context.l10n.chatTitleFallback;

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: OutlinedButton(
          onPressed: _loading ? null : _openChat,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.primary,
            backgroundColor: colors.surfaceSubtle,
            disabledForegroundColor: colors.textSecondary,
            side: BorderSide(color: colors.controlBorder),
            padding: EdgeInsets.zero,
            minimumSize: const Size(_hAction, _hAction),
            fixedSize: const Size(_hAction, _hAction),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_rButton),
            ),
          ),
          child: _loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                )
              : const Icon(Icons.chat_bubble_outline_rounded, size: 20),
        ),
      ),
    );
  }
}

// ── States ────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        children: List.generate(
          2,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(_rCard),
                border: Border.all(color: colors.border),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.softTeal,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.gavel_rounded,
                size: 28,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.discoveryNoBidsYet,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.discoveryWorkersWillAppear,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
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
    final colors = context.semanticColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(context.l10n.discoveryTryAgain),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
