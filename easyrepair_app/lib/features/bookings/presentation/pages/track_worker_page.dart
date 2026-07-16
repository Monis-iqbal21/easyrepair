import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../domain/entities/booking_entity.dart';
import '../providers/booking_providers.dart';
import '../widgets/inspection_report_card.dart';
import '../../../chat/presentation/providers/chat_providers.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kGreen  = Color(0xFFDB6234);
const _kDark   = Color(0xFF1A1A1A);
const _kLight  = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);
const _kBg     = Color(0xFFF9FAFB);

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
      if (mounted) ref.invalidate(bookingDetailProvider(widget.bookingId));
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
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: bookingAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
          ),
          error: (err, _) => _ErrorBody(
            message: err is Failure ? err.message : 'Failed to load tracking data.',
            onRetry: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
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
                booking.latitude != 0 &&
                booking.longitude != 0)
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
            _WorkerCard(worker: worker),
            const SizedBox(height: 16),
          ],
          _DistanceEtaCard(distanceM: distanceM, etaMin: etaMin),
          const SizedBox(height: 16),
          _ProgressTimeline(
            booking: booking,
            distanceM: distanceM,
            etaMin: etaMin,
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 1,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child:
                    Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _kDark),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Track Worker',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  booking.referenceId,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kLight,
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
  String? _iconLoadedForUrl;

  bool get _hasJobLoc =>
      widget.booking.latitude != 0 || widget.booking.longitude != 0;
  LatLng get _jobLatLng =>
      LatLng(widget.booking.latitude, widget.booking.longitude);

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _maybeLoadWorkerIcon() {
    final avatarUrl = widget.booking.assignedWorker?.avatarUrl;
    if (avatarUrl == null || avatarUrl.isEmpty) return;
    if (avatarUrl == _iconLoadedForUrl) return;
    _iconLoadedForUrl = avatarUrl;
    _buildAvatarMarkerIcon(avatarUrl).then((icon) {
      if (!mounted || icon == null || _iconLoadedForUrl != avatarUrl) return;
      setState(() => _workerIcon = icon);
    });
  }

  /// Composites the worker's avatar into a circular map marker (green ring,
  /// white border). Returns null on any failure (missing image, decode
  /// error, network timeout) so the caller falls back to a colored pin —
  /// this must never crash the tracking page.
  Future<BitmapDescriptor?> _buildAvatarMarkerIcon(String avatarUrl) async {
    try {
      final completer = Completer<ui.Image>();
      final stream = NetworkImage(avatarUrl).resolve(const ImageConfiguration());
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
      final image = await completer.future.timeout(const Duration(seconds: 6));

      const size = 128.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const center = Offset(size / 2, size / 2);
      const radius = size / 2;

      canvas.drawCircle(center, radius, Paint()..color = _kGreen);
      canvas.drawCircle(center, radius - 5, Paint()..color = Colors.white);
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius - 8)),
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        const Rect.fromLTWH(8, 8, size - 16, size - 16),
        Paint(),
      );
      canvas.restore();

      final rendered = await recorder.endRecording().toImage(
            size.toInt(),
            size.toInt(),
          );
      final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return null;
      return BitmapDescriptor.bytes(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  void _fitBounds() {
    final worker = widget.booking.assignedWorker;
    if (worker?.currentLat == null || worker?.currentLng == null || !_hasJobLoc) {
      return;
    }
    final points = [_jobLatLng, LatLng(worker!.currentLat!, worker.currentLng!)];
    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
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
          icon: _workerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: worker.fullName),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasJobLoc) {
      return Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_off_outlined, size: 16, color: _kLight),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Location not available for this booking.',
                    style: TextStyle(fontSize: 12.5, color: _kLight),
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
    final hasWorkerLoc = worker?.currentLat != null && worker?.currentLng != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          SizedBox(
            height: 200,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _jobLatLng, zoom: 14),
              markers: _buildMarkers(),
              onMapCreated: (c) {
                _mapCtrl = c;
                _fitBounds();
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),
          if (worker != null && !hasWorkerLoc)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_off_outlined, size: 14, color: _kLight),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Ustaad location abhi available nahi hai.',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
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

  bool get _isStandard => booking.lane == BookingLane.standard;
  bool get _isInspection => booking.lane == BookingLane.inspection;

  // STANDARD/INSPECTION lanes are direct-hire — never show "Bid Accepted"
  // wording for them. BIDDING keeps the existing headline unchanged.
  String get _headline {
    if (booking.status == BookingStatus.completed) return 'Job Completed ✓';
    if (_isInspection) {
      if (booking.inspectionDecisionStatus == InspectionDecisionStatus.acceptedRepair) {
        return 'Quote Accepted — Repair In Progress';
      }
      return switch (booking.status) {
        BookingStatus.enRoute => 'Ustaad On The Way',
        BookingStatus.arrived => 'Ustaad Arrived',
        BookingStatus.inProgress => booking.inspectionReportSubmitted
            ? 'Report Submitted'
            : 'Inspection In Progress',
        _ => 'Hired ✓',
      };
    }
    if (!_isStandard) return 'Bid Accepted ✓';
    return switch (booking.status) {
      BookingStatus.enRoute => 'Ustaad On The Way',
      BookingStatus.arrived => 'Ustaad Arrived',
      BookingStatus.inProgress => 'Work In Progress',
      _ => 'Hired ✓',
    };
  }

  String _subtext(String firstName) {
    if (booking.status == BookingStatus.completed) {
      return '$firstName has completed the job';
    }
    if (_isInspection) {
      if (booking.inspectionDecisionStatus == InspectionDecisionStatus.acceptedRepair) {
        return '$firstName is continuing the repair';
      }
      return switch (booking.status) {
        BookingStatus.enRoute => '$firstName is on the way to your location',
        BookingStatus.arrived => '$firstName has arrived at your location',
        BookingStatus.inProgress => booking.inspectionReportSubmitted
            ? 'Review the report below and decide how to proceed'
            : '$firstName is inspecting the issue',
        _ => '$firstName has been hired for this inspection',
      };
    }
    if (!_isStandard) return '$firstName is heading to your location';
    return switch (booking.status) {
      BookingStatus.enRoute => '$firstName is on the way to your location',
      BookingStatus.arrived => '$firstName has arrived at your location',
      BookingStatus.inProgress => '$firstName is working on your job',
      _ => '$firstName has been hired for this job',
    };
  }

  @override
  Widget build(BuildContext context) {
    final worker = booking.assignedWorker;
    final firstName = worker?.firstName ?? 'Worker';
    final price = booking.acceptedBidAmount ?? booking.finalPrice ?? booking.estimatedPrice;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B3010), Color(0xFFDB6234)],
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
                  color: _kGreen,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  booking.status == BookingStatus.completed
                      ? Icons.check_circle_rounded
                      : Icons.check_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _headline,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _subtext(firstName),
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
          if (price != null) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Text(
                'Hired at PKR ${price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
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
  final AssignedWorkerEntity worker;

  const _WorkerCard({required this.worker});

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
          .getOrCreate(widget.worker.id);
      if (mounted) {
        context.push('/client/chat/${conversation.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
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
        const SnackBar(
          content: Text('Phone number unavailable'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open phone dialer'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final worker = widget.worker;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ASSIGNED WORKER',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _kLight,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
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
                            '${worker.rating!.toStringAsFixed(1)} / 5.0',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
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
                    icon: _chatLoading ? null : Icons.chat_bubble_outline_rounded,
                    loading: _chatLoading,
                    onTap: _openChat,
                    tooltip: 'Chat',
                  ),
                  const SizedBox(width: 10),
                  _ActionCircle(
                    icon: Icons.phone_outlined,
                    loading: false,
                    onTap: _callWorker,
                    tooltip: 'Call',
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
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border:
                Border.all(color: _kGreen.withValues(alpha: 0.25)),
          ),
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(11),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kGreen),
                )
              : Icon(icon, size: 18, color: _kGreen),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasDistance
              ? [_kGreen, const Color(0xFFB84E25)]
              : [const Color(0xFF64748B), const Color(0xFF475569)],
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
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasDistance
                  ? Icons.directions_car_rounded
                  : Icons.location_off_outlined,
              color: Colors.white,
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
                      ? formatDistance(distanceM!)
                      : 'Location unavailable',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasDistance
                      ? 'Arriving in ~$etaMin ${etaMin == 1 ? 'minute' : 'minutes'}'
                      : 'ETA unavailable',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
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
  final double? distanceM;
  final int? etaMin;

  const _ProgressTimeline({
    required this.booking,
    required this.distanceM,
    required this.etaMin,
  });

  bool get _isStandard => booking.lane == BookingLane.standard;
  bool get _isInspection => booking.lane == BookingLane.inspection;

  // INSPECTION lane: Hired -> Ustaad on the way -> Arrived -> Inspection in
  // progress -> Report submitted -> Quote accepted/Closed after inspection ->
  // Completed. Never shows "Bid Accepted"/"Offer Accepted" wording.
  int _inspectionRank() {
    if (booking.status == BookingStatus.completed) return 7;
    if (booking.inspectionDecisionStatus == InspectionDecisionStatus.acceptedRepair ||
        booking.inspectionDecisionStatus == InspectionDecisionStatus.closedAfterInspection) {
      return 6;
    }
    if (booking.status == BookingStatus.inProgress) {
      return booking.inspectionReportSubmitted ? 5 : 4;
    }
    return switch (booking.status) {
      BookingStatus.enRoute => 2,
      BookingStatus.arrived => 3,
      _ => 1,
    };
  }

  List<_StepData> _inspectionSteps(DateFormat fmt) {
    return [
      _StepData(label: 'Hired', requiredRank: 1, timestamp: booking.acceptedAt, fmt: fmt),
      _StepData(label: 'Ustaad on the way', requiredRank: 2, timestamp: booking.enRouteAt, fmt: fmt),
      _StepData(label: 'Arrived', requiredRank: 3, timestamp: booking.arrivedAt, fmt: fmt),
      _StepData(label: 'Inspection in progress', requiredRank: 4, timestamp: booking.startedAt, fmt: fmt),
      _StepData(
        label: 'Report submitted',
        requiredRank: 5,
        timestamp: booking.inspectionReportSubmittedAt,
        fmt: fmt,
      ),
      _StepData(
        label: booking.inspectionDecisionStatus == InspectionDecisionStatus.closedAfterInspection
            ? 'Closed after inspection'
            : 'Quote accepted',
        requiredRank: 6,
        timestamp: null,
        fmt: fmt,
      ),
      _StepData(
        label: booking.review != null ? 'Reviewed' : 'Completed',
        requiredRank: 7,
        timestamp: booking.completedAt,
        fmt: fmt,
      ),
    ];
  }

  // Legacy 3-step ladder for BIDDING — unchanged: Bid Accepted
  // (rank 1), Arrived (rank 2, auto-triggered when distanceM < 150), Job
  // Completed (rank 3).
  int _legacyRank({double? distanceM}) {
    if (booking.status == BookingStatus.completed) return 3;
    if (booking.status == BookingStatus.inProgress) {
      // Treat in-progress as arrived
      return 2;
    }
    if (booking.status == BookingStatus.enRoute ||
        booking.status == BookingStatus.accepted) {
      if (distanceM != null && distanceM <= 150) return 2;
      return 1;
    }
    return 1;
  }

  // STANDARD lane has no bidding: Hired -> Ustaad on the way -> Arrived ->
  // Work in progress -> Completed -> Review. Rank 6 only once a review has
  // actually been submitted.
  int _standardRank() {
    return switch (booking.status) {
      BookingStatus.enRoute => 2,
      BookingStatus.arrived => 3,
      BookingStatus.inProgress => 4,
      BookingStatus.completed => booking.review != null ? 6 : 5,
      _ => 1, // accepted (or anything else — a worker shouldn't land here otherwise)
    };
  }

  DateTime? _historyDate(BookingStatus target) {
    for (final entry in booking.statusHistory.reversed) {
      if (entry.status == target) return entry.createdAt;
    }
    return null;
  }

  List<_StepData> _standardSteps(DateFormat fmt) {
    return [
      _StepData(label: 'Hired', requiredRank: 1, timestamp: booking.acceptedAt, fmt: fmt),
      _StepData(label: 'Ustaad on the way', requiredRank: 2, timestamp: booking.enRouteAt, fmt: fmt),
      _StepData(label: 'Arrived', requiredRank: 3, timestamp: booking.arrivedAt, fmt: fmt),
      _StepData(label: 'Work in progress', requiredRank: 4, timestamp: booking.startedAt, fmt: fmt),
      _StepData(label: 'Completed', requiredRank: 5, timestamp: booking.completedAt, fmt: fmt),
      _StepData(
        label: booking.review != null ? 'Reviewed' : 'Review pending',
        requiredRank: 6,
        timestamp: booking.review?.createdAt,
        fmt: fmt,
      ),
    ];
  }

  List<_StepData> _legacySteps(DateFormat fmt, int rank) {
    final arrivedAt = booking.status == BookingStatus.inProgress
        ? (_historyDate(BookingStatus.inProgress) ?? booking.startedAt)
        : (distanceM != null && distanceM! <= 150
            ? DateTime.now()
            : null);

    return [
      _StepData(
        label: 'Bid Accepted',
        requiredRank: 1,
        timestamp:
            _historyDate(BookingStatus.accepted) ?? booking.acceptedAt,
        fmt: fmt,
      ),
      _StepData(
        label: 'Arrived',
        requiredRank: 2,
        timestamp: arrivedAt,
        fmt: fmt,
        subtext: (rank == 1 && distanceM != null)
            ? 'ETA $etaMin min • Updated now'
            : null,
      ),
      _StepData(
        label: 'Job Completed',
        requiredRank: 3,
        timestamp:
            _historyDate(BookingStatus.completed) ?? booking.completedAt,
        fmt: fmt,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('h:mm a');
    final rank = _isStandard
        ? _standardRank()
        : _isInspection
            ? _inspectionRank()
            : _legacyRank(distanceM: distanceM);
    final steps = _isStandard
        ? _standardSteps(fmt)
        : _isInspection
            ? _inspectionSteps(fmt)
            : _legacySteps(fmt, rank);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              const Text(
                'Job Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kDark,
                ),
              ),
              const SizedBox(width: 10),
              _GreenLiveBadge(),
            ],
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < steps.length; i++)
            _TimelineStep(
              data: steps[i],
              rank: rank,
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _StepData {
  final String label;
  final int requiredRank;
  final DateTime? timestamp;
  final DateFormat fmt;
  final String? subtext;

  const _StepData({
    required this.label,
    required this.requiredRank,
    required this.timestamp,
    required this.fmt,
    this.subtext,
  });
}

class _TimelineStep extends StatelessWidget {
  final _StepData data;
  final int rank;
  final bool isLast;

  const _TimelineStep({
    required this.data,
    required this.rank,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isDone    = rank > data.requiredRank;
    final isActive  = rank == data.requiredRank;
    final isPending = !isDone && !isActive;

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
                    color: isDone ? _kGreen : Colors.white,
                    border: Border.all(
                      color: (isDone || isActive) ? _kGreen : _kBorder,
                      width: isDone ? 0 : 2,
                    ),
                  ),
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          size: 13, color: Colors.white)
                      : isActive
                          ? Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: _kGreen,
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
                        color: isDone ? _kGreen : _kBorder,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right: label + timestamp / subtext
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isPending ? _kLight : _kDark,
                    ),
                  ),
                  if (data.subtext != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      data.subtext!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _kGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else if (data.timestamp != null &&
                      (isDone || isActive)) ...[
                    const SizedBox(height: 3),
                    Text(
                      data.fmt.format(data.timestamp!),
                      style:
                          const TextStyle(fontSize: 11.5, color: _kLight),
                    ),
                  ] else ...[
                    const SizedBox(height: 3),
                    const Text(
                      '—',
                      style: TextStyle(
                          fontSize: 11.5, color: _kBorder),
                    ),
                  ],
                ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD0B5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: _kGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'Live',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _kGreen,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 1,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: _kDark),
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load tracking',
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
                    style: const TextStyle(
                        fontSize: 13, color: _kLight, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: onRetry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: _kGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Retry',
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
        ),
      ],
    );
  }
}
