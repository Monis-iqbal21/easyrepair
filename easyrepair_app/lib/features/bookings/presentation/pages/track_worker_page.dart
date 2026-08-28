import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../domain/entities/booking_entity.dart';
import 'full_screen_map_page.dart';
import '../utils/booking_timeline.dart';
import '../providers/booking_providers.dart';
import '../widgets/inspection_report_card.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../client/presentation/widgets/client_state_view.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/errors/failure_messages.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class TrackWorkerPage extends ConsumerStatefulWidget {
  final String bookingId;
  const TrackWorkerPage({super.key, required this.bookingId});

  @override
  ConsumerState<TrackWorkerPage> createState() => _TrackWorkerPageState();
}

class _TrackWorkerPageState extends ConsumerState<TrackWorkerPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Re-fetches the whole booking (worker currentLat/currentLng included),
    // which is the only way to get fresher worker coordinates — there's no
    // dedicated live-location endpoint. 12s keeps the map/ETA reasonably
    // live without being an aggressive poll (per product spec: 10-15s while
    // this page is open).
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      // Stop polling once the job is no longer live/trackable (e.g. the
      // worker cancelled mid-job) — there's nothing left to track live.
      final status = ref
          .read(bookingDetailProvider(widget.bookingId))
          .valueOrNull
          ?.status;
      final isTerminal =
          status == BookingStatus.completed ||
          status == BookingStatus.cancelled ||
          status == BookingStatus.rejected ||
          status == BookingStatus.expired;
      if (isTerminal) {
        _refreshTimer?.cancel();
        return;
      }
      ref.invalidate(bookingDetailProvider(widget.bookingId));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/client/booking/${widget.bookingId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));
    final colors = context.semanticColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: bookingAsync.when(
          skipError: true,
          loading: () =>
              ClientStateView.loading(message: context.l10n.trackLoading),
          error: (err, _) => _ErrorBody(
            message: failureMessage(
              context.l10n,
              err,
              fallback: context.l10n.trackLoadFailed,
            ),
            onRetry: () =>
                ref.invalidate(bookingDetailProvider(widget.bookingId)),
            onBack: _goBack,
          ),
          data: (booking) => _TrackBody(booking: booking, onBack: _goBack),
        ),
      ),
    );
  }
}

// ── Track body ────────────────────────────────────────────────────────────────

class _TrackBody extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback onBack;

  const _TrackBody({required this.booking, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final worker = booking.assignedWorker;

    final double? distanceM =
        (worker?.currentLat != null &&
            worker?.currentLng != null &&
            booking.hasLocation)
        ? haversineDistanceMeters(
            worker!.currentLat!,
            worker.currentLng!,
            booking.latitude,
            booking.longitude,
          )
        : null;

    final double? distanceKm = distanceM != null ? distanceM / 1000 : null;
    final int? etaMin = distanceKm != null
        ? math.max(1, (distanceKm / 25 * 60).round())
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBar(booking: booking, onBack: onBack),
          const SizedBox(height: 16),
          _TrackingMap(booking: booking),
          const SizedBox(height: 16),
          _StatusCard(booking: booking),
          const SizedBox(height: 16),
          if (worker != null) ...[
            _WorkerCard(bookingId: booking.id, worker: worker),
            const SizedBox(height: 16),
          ],
          _DistanceEtaCard(distanceM: distanceM, etaMin: etaMin),
          const SizedBox(height: 16),
          _ProgressTimeline(booking: booking),
          if (booking.lane == BookingLane.inspection) ...[
            const SizedBox(height: 8),
            ViewInspectionReportButton(
              bookingId: booking.id,
              route: '/client/booking/${booking.id}/inspection-report',
            ),
          ],
        ],
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback onBack;

  const _TopBar({required this.booking, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Material(
            color: colors.surface,
            shape: const CircleBorder(),
            elevation: 1,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.bookingTrackWorker,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  booking.referenceId,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tracking map preview ─────────────────────────────────────────────────────
//
// Shows the job/client location pin and, when available, the assigned
// worker's current position (avatar marker when their profile photo can be
// loaded, colored pin fallback otherwise). Rebuilds from whatever `booking`
// the parent passes down — the page-level 12s poll (see
// _TrackWorkerPageState) is what actually keeps the coordinates fresh; this
// widget itself does no network polling of its own, only marker/camera work.
class _TrackingMap extends StatefulWidget {
  final BookingEntity booking;
  const _TrackingMap({required this.booking});

  @override
  State<_TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<_TrackingMap> {
  GoogleMapController? _mapCtrl;
  BitmapDescriptor? _workerIcon;
  String? _iconLoadedForKey;

  /// The avatar circle's radius as a fraction of the composited icon's total
  /// height — used as the marker anchor so the pin still points at the
  /// worker's actual coordinate, not the name label below it.
  double _workerIconAnchorY = 1.0;

  /// True once the client has manually panned/zoomed the map. After that,
  /// the periodic booking-refresh poll (every 12s, see
  /// _TrackWorkerPageState) must never force the camera again — only the
  /// client's own gestures move it from here on.
  bool _userInteracted = false;

  /// Set right before this widget's own animateCamera call so the resulting
  /// onCameraMoveStarted isn't mistaken for a user gesture.
  bool _isProgrammaticCameraMove = false;

  /// Mirror of the inline map's markers, handed to the full-screen page so it
  /// keeps receiving live Ustaad position updates while open.
  final _fullScreenMarkers = ValueNotifier<Set<Marker>>(<Marker>{});

  bool get _hasJobLoc => widget.booking.hasLocation;
  LatLng get _jobLatLng =>
      LatLng(widget.booking.latitude, widget.booking.longitude);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoadWorkerIcon();
  }

  @override
  void didUpdateWidget(covariant _TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeLoadWorkerIcon();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    _fullScreenMarkers.dispose();
    super.dispose();
  }

  void _maybeLoadWorkerIcon() {
    final worker = widget.booking.assignedWorker;
    if (worker == null) return;
    // The raster is density-dependent, so the pixel ratio is part of the
    // cache key — otherwise a density change would reuse a bitmap built for
    // the wrong scale. The key check is also what stops the icon being
    // rebuilt (and appearing to grow) on every map refresh.
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final brightness = Theme.of(context).brightness.name;
    final key = '${worker.avatarUrl}|${worker.firstName}|$dpr|$brightness';
    if (key == _iconLoadedForKey) return;
    _iconLoadedForKey = key;
    _buildWorkerMarkerIcon(worker.firstName, worker.avatarUrl, dpr).then((
      built,
    ) {
      if (!mounted || built == null || _iconLoadedForKey != key) return;
      setState(() {
        _workerIcon = built.icon;
        _workerIconAnchorY = built.anchorY;
      });
    });
  }

  /// Composites the worker's avatar (or initials, if no photo) plus an
  /// always-visible name label into one marker bitmap — InfoWindow only
  /// shows on tap, but the client needs the Ustaad's name visible at a
  /// glance while tracking. Returns null on any failure (missing image,
  /// decode error, network timeout) so the caller falls back to a plain
  /// colored pin — this must never crash the tracking page.
  Future<({BitmapDescriptor icon, double anchorY})?> _buildWorkerMarkerIcon(
    String name,
    String? avatarUrl,
    double devicePixelRatio,
  ) async {
    final colors = context.semanticColors;
    try {
      // ── Sizing is in LOGICAL dp, then rasterised at [devicePixelRatio] ──
      //
      // This is the whole fix for the oversized marker. The previous version
      // rasterised a 160x168 PIXEL canvas and handed it to
      // BitmapDescriptor.bytes WITHOUT imagePixelRatio, so those bytes were
      // interpreted at ratio 1.0 - i.e. 160x168 *logical dp*, roughly
      // 480x504 physical px on a 3x phone, against a default pin of ~27x43dp.
      //
      // Now the marker is defined at a deliberate ~44dp avatar (comparable to
      // the other pins), drawn on a canvas scaled up by the device ratio for
      // crispness, and BitmapDescriptor is told that ratio so it renders back
      // down to the intended dp size on every density.
      const avatarDp = 44.0;
      const gapDp = 4.0;
      const labelHeightDp = 18.0;
      const canvasWidthDp = 104.0;
      const canvasHeightDp = avatarDp + gapDp + labelHeightDp;
      const avatarCenter = Offset(canvasWidthDp / 2, avatarDp / 2);
      const avatarRadius = avatarDp / 2;
      const ringDp = 2.0;
      const photoInsetDp = 3.0;

      ui.Image? avatarImage;
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        avatarImage = await _loadNetworkImage(avatarUrl);
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // Everything below is authored in dp; this single scale makes the
      // output physical-pixel crisp without changing any of the geometry.
      canvas.scale(devicePixelRatio);

      canvas.drawCircle(
        avatarCenter,
        avatarRadius,
        Paint()..color = colors.primary,
      );
      canvas.drawCircle(
        avatarCenter,
        avatarRadius - ringDp,
        Paint()..color = colors.surface,
      );
      if (avatarImage != null) {
        canvas.save();
        canvas.clipPath(
          Path()..addOval(
            Rect.fromCircle(
              center: avatarCenter,
              radius: avatarRadius - photoInsetDp,
            ),
          ),
        );
        canvas.drawImageRect(
          avatarImage,
          Rect.fromLTWH(
            0,
            0,
            avatarImage.width.toDouble(),
            avatarImage.height.toDouble(),
          ),
          Rect.fromCircle(
            center: avatarCenter,
            radius: avatarRadius - photoInsetDp,
          ),
          Paint(),
        );
        canvas.restore();
      } else {
        // Fallback initial, kept in proportion to the smaller avatar.
        final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
        final initialsPainter = TextPainter(
          text: TextSpan(
            text: initials,
            style: TextStyle(
              color: colors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        initialsPainter.paint(
          canvas,
          avatarCenter -
              Offset(initialsPainter.width / 2, initialsPainter.height / 2),
        );
      }

      final namePainter = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            color: colors.onPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: canvasWidthDp - 12);

      final labelRect = Rect.fromLTWH(
        (canvasWidthDp - (namePainter.width + 12)) / 2,
        avatarDp + gapDp,
        namePainter.width + 12,
        labelHeightDp,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          labelRect,
          const Radius.circular(labelHeightDp / 2),
        ),
        Paint()..color = colors.textPrimary,
      );
      namePainter.paint(
        canvas,
        Offset(
          labelRect.left + 6,
          labelRect.top + (labelHeightDp - namePainter.height) / 2,
        ),
      );

      // Raster dimensions are dp * ratio; imagePixelRatio below converts them
      // back to the intended dp footprint on screen.
      final rendered = await recorder.endRecording().toImage(
        (canvasWidthDp * devicePixelRatio).round(),
        (canvasHeightDp * devicePixelRatio).round(),
      );
      final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return null;
      return (
        icon: BitmapDescriptor.bytes(
          bytes.buffer.asUint8List(),
          imagePixelRatio: devicePixelRatio,
        ),
        anchorY: avatarDp / 2 / canvasHeightDp,
      );
    } catch (_) {
      return null;
    }
  }

  Future<ui.Image> _loadNetworkImage(String url) async {
    final completer = Completer<ui.Image>();
    final stream = NetworkImage(url).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (error, stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future.timeout(const Duration(seconds: 6));
  }

  void _fitBounds() {
    // Respect the client's own pan/zoom — the 12s poll must not keep
    // yanking the camera back to a fit bounds view once they've taken over.
    if (_userInteracted) return;
    final worker = widget.booking.assignedWorker;
    if (worker?.currentLat == null ||
        worker?.currentLng == null ||
        !_hasJobLoc) {
      return;
    }
    final points = [
      _jobLatLng,
      LatLng(worker!.currentLat!, worker.currentLng!),
    ];
    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    _isProgrammaticCameraMove = true;
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

  void _onCameraMoveStarted() {
    if (_isProgrammaticCameraMove) {
      _isProgrammaticCameraMove = false;
    } else {
      _userInteracted = true;
    }
  }

  /// Opens the shared in-app full-screen map with the SAME markers, kept
  /// live: [_fullScreenMarkers] is refreshed on every rebuild, so the
  /// Ustaad's position continues updating while the full-screen page is open.
  /// Never launches an external maps app; back returns to this page.
  void _openFullScreenMap() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullScreenMapPage(
          title: context.l10n.trackTitleUstaad,
          markersListenable: _fullScreenMarkers,
          initialTarget: _jobLatLng,
        ),
      ),
    );
  }

  /// Builds the marker set AND publishes it to [_fullScreenMarkers] so both
  /// maps always show the same thing.
  Set<Marker> _syncedMarkers() {
    final markers = _buildMarkers();
    // Deferred: this runs during build, and ValueNotifier would otherwise
    // trigger a listener rebuild mid-frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fullScreenMarkers.value = markers;
    });
    return markers;
  }

  Set<Marker> _buildMarkers() {
    final worker = widget.booking.assignedWorker;
    final markers = <Marker>{};
    if (_hasJobLoc) {
      markers.add(
        Marker(
          markerId: const MarkerId('job'),
          position: _jobLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: widget.booking.serviceCategory,
            snippet: widget.booking.address,
          ),
        ),
      );
    }
    if (worker?.currentLat != null && worker?.currentLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('worker'),
          position: LatLng(worker!.currentLat!, worker.currentLng!),
          icon:
              _workerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          // The composited icon has the name label below the avatar circle,
          // so the anchor must point at the circle's center, not the image
          // center, or the pin would visually sit south of the actual fix.
          anchor: Offset(0.5, _workerIcon != null ? _workerIconAnchorY : 1.0),
          infoWindow: InfoWindow(title: worker.fullName),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    if (!_hasJobLoc) {
      return Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_off_outlined,
                  size: 16,
                  color: colors.textSecondary,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    context.l10n.trackNoLocationForBooking,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final worker = widget.booking.assignedWorker;
    final hasWorkerLoc =
        worker?.currentLat != null && worker?.currentLng != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          SizedBox(
            height: 200,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _jobLatLng,
                zoom: 14,
              ),
              markers: _syncedMarkers(),
              onMapCreated: (c) {
                _mapCtrl = c;
                _fitBounds();
              },
              onCameraMoveStarted: _onCameraMoveStarted,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              mapToolbarEnabled: false,
              // This map sits inside the page's SingleChildScrollView — claim
              // pan/zoom gestures within its own bounds immediately so they
              // aren't lost to the page's scroll gesture (same fix as the
              // client location picker and the worker job-location map).
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
            ),
          ),
          // Expand to the in-app full-screen map. Bottom-right so it never
          // covers Google's attribution (bottom-left). When the
          // "location unavailable" banner is showing it is lifted above it.
          Positioned(
            right: 10,
            bottom: (worker != null && !hasWorkerLoc) ? 52 : 10,
            child: MapExpandButton(onTap: _openFullScreenMap),
          ),
          if (worker != null && !hasWorkerLoc)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: colors.scrim.withValues(alpha: 0.1),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      size: 14,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        context.l10n.trackUstaadLocationUnavailable,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

// ── Status card ───────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final BookingEntity booking;

  const _StatusCard({required this.booking});

  // Once a DIFFERENT worker than the original inspector has been hired via
  // "Find Other Ustaad", they're performing WORK, not inspecting — even
  // though booking.lane stays INSPECTION and decisionStatus stays
  // FIND_OTHER_USTAAD forever. Falling through to the STANDARD/BIDDING
  // branch below gives correct "Work In Progress" wording with zero
  // duplication.
  bool get _isInspection =>
      booking.lane == BookingLane.inspection &&
      !booking.isDifferentWorkerPerformingWork;

  // STANDARD/BIDDING share the same status-driven headline — once hired,
  // wording is identical regardless of whether the hire came from direct
  // assignment or an accepted bid. INSPECTION keeps its richer branching.
  String _headlineFor(BuildContext context) {
    if (booking.status == BookingStatus.completed) {
      return context.l10n.trackJobCompleted;
    }
    if (_isInspection) {
      if (booking.inspectionDecisionStatus ==
          InspectionDecisionStatus.acceptedRepair) {
        return context.l10n.trackQuoteAcceptedRepairInProgress;
      }
      return switch (booking.status) {
        BookingStatus.enRoute => context.l10n.trackHeadlineUstaadOnTheWay,
        BookingStatus.arrived => context.l10n.trackHeadlineUstaadArrived,
        BookingStatus.inProgress =>
          booking.inspectionReportSubmitted
              ? context.l10n.trackReportSubmitted
              : context.l10n.trackInspectionInProgress,
        _ => context.l10n.trackHeadlineHired,
      };
    }
    return switch (booking.status) {
      BookingStatus.enRoute => context.l10n.trackHeadlineUstaadOnTheWay,
      BookingStatus.arrived => context.l10n.trackHeadlineUstaadArrived,
      BookingStatus.inProgress => context.l10n.trackHeadlineWorkInProgress,
      _ => context.l10n.trackHeadlineHired,
    };
  }

  String _subtext(BuildContext context, String firstName) {
    if (booking.status == BookingStatus.completed) {
      return context.l10n.trackSubtextCompleted(firstName);
    }
    if (_isInspection) {
      if (booking.inspectionDecisionStatus ==
          InspectionDecisionStatus.acceptedRepair) {
        return context.l10n.trackSubtextContinuingRepair(firstName);
      }
      return switch (booking.status) {
        BookingStatus.enRoute => context.l10n.trackSubtextOnTheWay(firstName),
        BookingStatus.arrived => context.l10n.trackSubtextArrived(firstName),
        BookingStatus.inProgress =>
          booking.inspectionReportSubmitted
              ? context.l10n.trackReviewReportAndDecide
              : context.l10n.trackSubtextInspecting(firstName),
        _ => context.l10n.trackSubtextHiredForInspection(firstName),
      };
    }
    return switch (booking.status) {
      BookingStatus.enRoute => context.l10n.trackSubtextOnTheWay(firstName),
      BookingStatus.arrived => context.l10n.trackSubtextArrived(firstName),
      BookingStatus.inProgress => context.l10n.trackSubtextWorking(firstName),
      _ => context.l10n.trackSubtextHiredForJob(firstName),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final worker = booking.assignedWorker;
    final firstName = worker?.firstName ?? context.l10n.trackWorkerLabel;
    // Shared with Booking Details' "Qeemat" row — see
    // BookingEntity.canonicalPrice. Never estimatedPrice: HandyGo has no
    // estimate concept, and this pill is only shown once a worker is hired.
    final price = booking.canonicalPrice;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryPressed, colors.primary],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.onPrimary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  booking.status == BookingStatus.completed
                      ? Icons.check_circle_rounded
                      : Icons.check_rounded,
                  color: colors.onPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _headlineFor(context),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _subtext(context, firstName),
            style: TextStyle(
              fontSize: 14,
              color: colors.onPrimaryMuted,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
          if (price != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors.onPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.onPrimary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                context.l10n.trackHiredAt(formatPkr(price)),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.onPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Worker card ───────────────────────────────────────────────────────────────

class _WorkerCard extends ConsumerStatefulWidget {
  final String bookingId;
  final AssignedWorkerEntity worker;

  const _WorkerCard({required this.bookingId, required this.worker});

  @override
  ConsumerState<_WorkerCard> createState() => _WorkerCardState();
}

class _WorkerCardState extends ConsumerState<_WorkerCard> {
  bool _chatLoading = false;

  Future<void> _openChat() async {
    if (_chatLoading) return;
    setState(() => _chatLoading = true);
    try {
      final conversation = await ref
          .read(getOrCreateConversationProvider.notifier)
          .getOrCreate(widget.bookingId, widget.worker.id);
      if (mounted) {
        context.push('/client/chat/${conversation.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failureMessage(context.l10n, e)),
            backgroundColor: context.semanticColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  Future<void> _callWorker() async {
    final phone = widget.worker.phone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.trackPhoneUnavailable),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.trackDialerFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final worker = widget.worker;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.scrim.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.trackAssignedWorkerCaps,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.primary,
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (worker.rating != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: colors.warning,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            context.l10n.trackRatingOutOfFive(
                              worker.rating!.toStringAsFixed(1),
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionCircle(
                    icon: _chatLoading
                        ? null
                        : Icons.chat_bubble_outline_rounded,
                    loading: _chatLoading,
                    onTap: _openChat,
                    tooltip: context.l10n.chatTitleFallback,
                  ),
                  const SizedBox(width: 10),
                  _ActionCircle(
                    icon: Icons.phone_outlined,
                    loading: false,
                    onTap: _callWorker,
                    tooltip: context.l10n.trackCall,
                  ),
                ],
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
    final colors = context.semanticColors;
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: colors.onPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionCircle extends StatelessWidget {
  final IconData? icon;
  final bool loading;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionCircle({
    required this.icon,
    required this.loading,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.softTeal,
            shape: BoxShape.circle,
            border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
          ),
          child: loading
              ? Padding(
                  padding: const EdgeInsets.all(11),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                )
              : Icon(icon, size: 18, color: colors.primary),
        ),
      ),
    );
  }
}

// ── Distance / ETA card ───────────────────────────────────────────────────────

class _DistanceEtaCard extends StatelessWidget {
  final double? distanceM;
  final int? etaMin;

  const _DistanceEtaCard({required this.distanceM, required this.etaMin});

  @override
  Widget build(BuildContext context) {
    final hasDistance = distanceM != null;
    final colors = context.semanticColors;
    final foreground = hasDistance ? colors.onPrimary : colors.onScrim;
    final mutedForeground = hasDistance
        ? colors.onPrimaryMuted
        : colors.onScrim.withValues(alpha: 0.85);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasDistance
              ? [colors.primary, colors.primaryPressed]
              : [colors.textSecondary, colors.controlBorder],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasDistance
                  ? Icons.directions_car_rounded
                  : Icons.location_off_outlined,
              color: foreground,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasDistance
                      ? formatDistanceLabel(context.l10n, distanceM!)
                      : context.l10n.trackLocationUnavailable,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasDistance
                      ? context.l10n.trackArrivingIn(etaMin!)
                      : context.l10n.trackEtaUnavailable,
                  style: TextStyle(
                    fontSize: 13,
                    color: mutedForeground,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (hasDistance) _LiveDotBadge(),
        ],
      ),
    );
  }
}

class _LiveDotBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.onPrimary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colors.onPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            context.l10n.trackLiveBadge,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colors.onPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress timeline ─────────────────────────────────────────────────────────

class _ProgressTimeline extends StatelessWidget {
  final BookingEntity booking;

  const _ProgressTimeline({required this.booking});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final steps = bookingTimelineSteps(context.l10n, booking);

    return Container(
      key: const Key('track-worker-timeline'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.scrim.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.trackJobProgress,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              _GreenLiveBadge(),
            ],
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < steps.length; i++)
            _TimelineStep(step: steps[i], isLast: i == steps.length - 1),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final BookingTimelineStep step;
  final bool isLast;

  const _TimelineStep({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final isDone = step.state == BookingTimelineStepState.complete;
    final isActive = step.state == BookingTimelineStepState.current;
    final isPending = step.state == BookingTimelineStepState.pending;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: dot + connector line
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? colors.primary : colors.surface,
                    border: Border.all(
                      color: (isDone || isActive)
                          ? colors.primary
                          : colors.controlBorder,
                      width: isDone ? 0 : 2,
                    ),
                  ),
                  child: isDone
                      ? Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: colors.onPrimary,
                        )
                      : isActive
                      ? Center(
                          child: Container(
                            key: const Key('track-worker-timeline-current'),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: isDone ? colors.primary : colors.border,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right: label only. Lifecycle stamps drive terminal freeze logic
          // in the shared helper but are never rendered on either page.
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Text(
                step.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive || isDone
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: isPending ? colors.textSecondary : colors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GreenLiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.softTeal,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            context.l10n.bookingStatusLive,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ErrorBody({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            color: colors.surface,
            shape: const CircleBorder(),
            elevation: 1,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack,
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
        Expanded(
          child: ClientStateView.error(
            title: context.l10n.trackLoadFailedShort,
            message: message,
            actionLabel: context.l10n.commonRetry,
            onAction: onRetry,
          ),
        ),
      ],
    );
  }
}
