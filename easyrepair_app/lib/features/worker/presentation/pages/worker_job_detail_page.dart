import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/failures.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../../bookings/presentation/widgets/media_attachment_widgets.dart';
import '../providers/worker_job_providers.dart';
import '../providers/worker_providers.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kGreen  = Color(0xFF1D9E75);
const _kDark   = Color(0xFF1A1A1A);
const _kGray   = Color(0xFF6B7280);
const _kLight  = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);
const _kBg     = Color(0xFFF9FAFB);
const _kRed    = Color(0xFFEF4444);

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
  const WorkerJobDetailPage({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('[WorkerJobDetailPage] build — jobId received=$jobId');
    final jobAsync = ref.watch(workerJobDetailProvider(jobId));

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _AppBar(),
      body: jobAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(
          color: _kGreen,
        )),
        error: (err, _) => _ErrorScreen(
          message: err is Failure ? err.message : 'Failed to load job.',
          onRetry: () => ref.invalidate(workerJobDetailProvider(jobId)),
        ),
        data: (job) => _JobBody(job: job),
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
    return AppBar(
      backgroundColor: _kBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: GestureDetector(
        onTap: () => _goBackOrHome(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(Icons.arrow_back_rounded, color: _kDark, size: 20),
        ),
      ),
      title: const Text(
        'Job Details',
        style: TextStyle(
          color: _kDark,
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
  const _JobBody({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending   = job.status == BookingStatus.pending;
    final canComplete = job.status.isWorkerActive;

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

                // ── Bid Now button (PENDING jobs only) ───────────────────
                if (isPending) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final title = job.title?.isNotEmpty == true
                            ? job.title!
                            : job.serviceCategory;
                        context.push(
                          '/worker/job/${job.id}/bid?title=${Uri.encodeComponent(title)}',
                        );
                      },
                      icon: const Icon(Icons.gavel_rounded, size: 16),
                      label: const Text('Bid Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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

                // ── Client info ──────────────────────────────────────────
                if (job.clientName != null && job.clientName!.isNotEmpty) ...[
                  _Section(
                    title: 'Client',
                    child: _InfoRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Posted by',
                      value: job.clientName!,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Service details ──────────────────────────────────────
                _Section(
                  title: 'Service Details',
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.category_outlined,
                        label: 'Category',
                        value: job.serviceCategory,
                      ),
                      if (job.title != null && job.title!.isNotEmpty)
                        _InfoRow(
                          icon: Icons.title_rounded,
                          label: 'Title',
                          value: job.title!,
                        ),
                      if (job.description != null && job.description!.isNotEmpty)
                        _InfoRow(
                          icon: Icons.description_outlined,
                          label: 'Description',
                          value: job.description!,
                          multiline: true,
                        ),
                      _InfoRow(
                        icon: Icons.bolt_rounded,
                        label: 'Urgency',
                        value: job.urgency == BookingUrgency.urgent
                            ? 'Urgent'
                            : 'Normal',
                      ),
                      if (job.timeSlot != null)
                        _InfoRow(
                          icon: Icons.schedule_rounded,
                          label: 'Time Slot',
                          value: job.timeSlot!.label,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Location ─────────────────────────────────────────────
                _LocationSection(job: job),
                const SizedBox(height: 16),

                // ── Timeline ─────────────────────────────────────────────
                _Section(
                  title: 'Timeline',
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'Created',
                        value: _fmtDateTime(job.createdAt),
                      ),
                      if (job.scheduledDate != null)
                        _InfoRow(
                          icon: Icons.event_rounded,
                          label: 'Scheduled',
                          value: _fmtDateTime(job.scheduledDate!),
                        ),
                      if (job.acceptedAt != null)
                        _InfoRow(
                          icon: Icons.handshake_outlined,
                          label: 'Accepted',
                          value: _fmtDateTime(job.acceptedAt!),
                        ),
                      if (job.startedAt != null)
                        _InfoRow(
                          icon: Icons.play_circle_outline_rounded,
                          label: 'Started',
                          value: _fmtDateTime(job.startedAt!),
                        ),
                      if (job.completedAt != null)
                        _InfoRow(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Completed',
                          value: _fmtDateTime(job.completedAt!),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Pricing ───────────────────────────────────────────────
                if (job.estimatedPrice != null || job.finalPrice != null) ...[
                  _Section(
                    title: 'Pricing',
                    child: Column(
                      children: [
                        if (job.estimatedPrice != null)
                          _InfoRow(
                            icon: Icons.attach_money_rounded,
                            label: 'Estimated',
                            value: 'PKR ${job.estimatedPrice!.toStringAsFixed(0)}',
                          ),
                        if (job.finalPrice != null)
                          _InfoRow(
                            icon: Icons.payments_outlined,
                            label: 'Final Price',
                            value: 'PKR ${job.finalPrice!.toStringAsFixed(0)}',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Attachments ───────────────────────────────────────────
                if (job.attachments.isNotEmpty) ...[
                  _AttachmentsSection(attachments: job.attachments),
                  const SizedBox(height: 16),
                ],

                // ── Status history ────────────────────────────────────────
                if (job.statusHistory.isNotEmpty) ...[
                  _StatusHistorySection(
                    history: job.statusHistory,
                    review: job.review,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Review ────────────────────────────────────────────────
                if (job.review != null) ...[
                  _ReviewSection(review: job.review!, clientName: job.clientName),
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

  String _fmtDateTime(DateTime dt) =>
      DateFormat('d MMM yyyy, h:mm a').format(dt);
}

// ── Status card ───────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final BookingEntity job;
  const _StatusCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _chipColors(job.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(job.serviceEmoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.serviceCategory,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  job.referenceId,
                  style: const TextStyle(fontSize: 12, color: _kLight),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              job.status.workerLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _chipColors(BookingStatus s) {
    if (s.isWorkerActive) {
      return (const Color(0xFFDCFCE7), const Color(0xFF15803D));
    }
    return switch (s) {
      BookingStatus.completed =>
        (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      BookingStatus.cancelled || BookingStatus.rejected =>
        (const Color(0xFFFEF2F2), _kRed),
      _ => (const Color(0xFFF1F5F9), _kGray),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment:
            multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: _kLight),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: _kLight)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: _kDark,
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

// ── Attachments ───────────────────────────────────────────────────────────────

class _AttachmentsSection extends StatelessWidget {
  final List<BookingAttachmentEntity> attachments;
  const _AttachmentsSection({required this.attachments});

  @override
  Widget build(BuildContext context) {
    final images = attachments.where((a) => a.type == AttachmentType.image).toList();
    final videos = attachments.where((a) => a.type == AttachmentType.video).toList();
    final audios = attachments.where((a) => a.type == AttachmentType.audio).toList();

    return _Section(
      title: 'Attachments',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty) ...[
            const Text('Photos', style: TextStyle(fontSize: 12, color: _kLight)),
            const SizedBox(height: 10),
            BookingImageGrid(images: images),
          ],
          if (videos.isNotEmpty) ...[
            if (images.isNotEmpty) const SizedBox(height: 14),
            const Text('Videos', style: TextStyle(fontSize: 12, color: _kLight)),
            const SizedBox(height: 8),
            ...videos.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BookingVideoTile(attachment: v),
                )),
          ],
          if (audios.isNotEmpty) ...[
            if (images.isNotEmpty || videos.isNotEmpty) const SizedBox(height: 14),
            const Text('Voice Notes', style: TextStyle(fontSize: 12, color: _kLight)),
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
}

// ── Status history ────────────────────────────────────────────────────────────

class _StatusHistorySection extends StatelessWidget {
  final List<BookingStatusHistoryEntry> history;
  final BookingReviewEntity? review;
  const _StatusHistorySection({required this.history, this.review});

  @override
  Widget build(BuildContext context) {
    final hasReview = review != null;
    return _Section(
      title: 'Status History',
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
                        color: isLast ? _kGreen : _kLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Container(width: 1, height: 28, color: _kBorder),
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
                          entry.status.workerLabel,
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
          if (hasReview)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
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
                            const Text(
                              'Reviewed',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF59E0B),
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
                                color: i < r
                                    ? const Color(0xFFF59E0B)
                                    : _kBorder,
                              );
                            }),
                          ],
                        ),
                        Text(
                          DateFormat('d MMM, h:mm a').format(review!.createdAt),
                          style: const TextStyle(fontSize: 11, color: _kLight),
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
    final isLoading = ref.watch(completeJobProvider).isLoading;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : () => _confirm(context, ref),
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle_outline_rounded, size: 18),
          label: Text(isLoading ? 'Completing...' : 'Mark as Completed'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Mark as Completed?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: const Text(
          'This will close the job and notify the client.',
          style: TextStyle(color: _kGray, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _kLight)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(completeJobProvider.notifier).complete(jobId);
      if (context.mounted) {
        final err = ref.read(completeJobProvider).error;
        if (err != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err.toString()),
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
    return _Section(
      title: 'Client Review',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(5, (i) => Icon(
                i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 18,
                color: i < review.rating
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFD1D5DB),
              )),
              const SizedBox(width: 8),
              Text(
                '${review.rating}/5',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kDark,
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('d MMM yyyy').format(review.createdAt),
                style: const TextStyle(fontSize: 11, color: _kLight),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF374151), height: 1.5),
            ),
          ],
          if (clientName != null && clientName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 13, color: _kLight),
                const SizedBox(width: 4),
                Text(
                  clientName!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kGray,
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
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
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
      final encoded =
          routes[0]['overview_polyline']['points'] as String;
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

class _LocationSection extends ConsumerStatefulWidget {
  final BookingEntity job;
  const _LocationSection({required this.job});

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

  bool get _hasJobLoc =>
      widget.job.latitude != 0 || widget.job.longitude != 0;
  LatLng get _jobLatLng =>
      LatLng(widget.job.latitude, widget.job.longitude);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dirTimer?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
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

    if (AppConfig.googleMapsApiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Road route is not configured yet. Opening Google Maps for navigation.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _openExternalMaps();
      }
      return;
    }

    setState(() => _gettingLocation = true);

    LatLng? workerPos;

    final tracker = ref.read(locationTrackerProvider);
    if (tracker.lastSyncedLat != null && tracker.lastSyncedLng != null) {
      workerPos = LatLng(tracker.lastSyncedLat!, tracker.lastSyncedLng!);
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
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) workerPos = LatLng(last.latitude, last.longitude);
      }
    }

    if (!mounted) return;

    if (workerPos == null) {
      setState(() => _gettingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get your location for directions.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _workerPos = workerPos;
      _directionsActive = true;
      _gettingLocation = false;
    });
    _fitBoundsForPoints([workerPos, _jobLatLng]);

    final route = await _fetchRoadRoute(workerPos, _jobLatLng);
    if (!mounted) return;

    if (route != null && route.isNotEmpty) {
      setState(() => _routePoints = route);
      _fitBoundsForPoints(route);
    } else {
      debugPrint(
          '[Directions] Road route unavailable — straight-line emergency fallback active.');
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
          const SnackBar(
            content: Text('You have arrived at the job location.'),
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
              BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
    };
  }

  Set<Polyline> _buildPolylines() {
    if (!_directionsActive) return {};
    if (_routePoints.isNotEmpty) {
      return {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: _kGreen,
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
        color: _kGreen,
        width: 3,
        patterns: [PatternItem.dash(16), PatternItem.gap(8)],
      ),
    };
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_hasJobLoc) {
      return _Section(
        title: 'Location',
        child: Column(
          children: [
            if (widget.job.address != null && widget.job.address!.isNotEmpty)
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: widget.job.address!,
                multiline: true,
              ),
            if (widget.job.city.isNotEmpty)
              _InfoRow(
                icon: Icons.location_city_rounded,
                label: 'City',
                value: widget.job.city,
              ),
          ],
        ),
      );
    }

    return _Section(
      title: 'Location',
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
                  ),
                ),
                // Expand / fullscreen button
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () async {
                      _dirTimer?.cancel();
                      _dirTimer = null;
                      final result =
                          await Navigator.push<_DirectionsResult>(
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
                            : (_workerPos != null
                                ? [_workerPos!, _jobLatLng]
                                : <LatLng>[]);
                        _fitBoundsForPoints(pts);
                        _startDirTimer();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fullscreen_rounded,
                        size: 18,
                        color: _kDark,
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
              color: _kBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              children: [
                if (widget.job.address != null &&
                    widget.job.address!.isNotEmpty) ...[
                  _InfoRow(
                    icon: Icons.home_work_outlined,
                    label: 'Client Address',
                    value: widget.job.address!,
                    multiline: true,
                  ),
                  const Divider(height: 1, thickness: 0.5, color: _kBorder),
                  const SizedBox(height: 8),
                ],
                _InfoRow(
                  icon: Icons.location_on_rounded,
                  label: 'Pinned Job Location',
                  value: 'Pinned on map',
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
                    onPressed:
                        _gettingLocation ? null : _startDirections,
                    icon: _gettingLocation
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _kGreen,
                            ),
                          )
                        : const Icon(
                            Icons.directions_rounded,
                            size: 16,
                            color: _kGreen,
                          ),
                    label: Text(
                      _gettingLocation
                          ? 'Getting location...'
                          : 'Directions',
                      style: const TextStyle(
                          color: _kGreen, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kGreen),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openExternalMaps,
                    icon: const Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: _kGray,
                    ),
                    label: const Text(
                      'Open in Maps',
                      style:
                          TextStyle(color: _kGray, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kBorder),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 9),
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
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.navigation_rounded,
                            size: 16, color: _kGreen),
                        SizedBox(width: 6),
                        Text(
                          'Directions active',
                          style: TextStyle(
                            color: _kGreen,
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
                    side: const BorderSide(color: _kRed),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 9, horizontal: 16),
                  ),
                  child: const Text(
                    'Stop',
                    style:
                        TextStyle(color: _kRed, fontSize: 13),
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
              label: 'City',
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
  ConsumerState<_FullScreenMapPage> createState() =>
      _FullScreenMapPageState();
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

  LatLng get _jobLatLng =>
      LatLng(widget.job.latitude, widget.job.longitude);

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

    if (AppConfig.googleMapsApiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Road route is not configured yet. Opening Google Maps for navigation.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _openExternalMaps();
      }
      return;
    }

    setState(() => _gettingLocation = true);

    LatLng? workerPos;
    final tracker = ref.read(locationTrackerProvider);
    if (tracker.lastSyncedLat != null && tracker.lastSyncedLng != null) {
      workerPos = LatLng(tracker.lastSyncedLat!, tracker.lastSyncedLng!);
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
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) workerPos = LatLng(last.latitude, last.longitude);
      }
    }

    if (!mounted) return;

    if (workerPos == null) {
      setState(() => _gettingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get your location for directions.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _workerPos = workerPos;
      _directionsActive = true;
      _gettingLocation = false;
    });
    _fitBoundsForPoints([workerPos, _jobLatLng]);

    final route = await _fetchRoadRoute(workerPos, _jobLatLng);
    if (!mounted) return;

    if (route != null && route.isNotEmpty) {
      setState(() => _routePoints = route);
      _fitBoundsForPoints(route);
    } else {
      debugPrint(
          '[Directions/FS] Road route unavailable — straight-line emergency fallback active.');
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
        '[DirectionsMode/FS] Distance to job: ${dist.toStringAsFixed(1)}m');

    if (dist <= _kReachedMeters) {
      debugPrint('[DirectionsMode/FS] Reached job — stopping directions.');
      _stopDirections();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have arrived at the job location.'),
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
              BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
    };
  }

  Set<Polyline> _buildPolylines() {
    if (!_directionsActive) return {};
    if (_routePoints.isNotEmpty) {
      return {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: _kGreen,
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
        color: _kGreen,
        width: 3,
        patterns: [PatternItem.dash(16), PatternItem.gap(8)],
      ),
    };
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _popWithResult();
      },
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: _kDark,
          leading: BackButton(onPressed: _popWithResult),
          title: Text(
            widget.job.serviceCategory,
            style: const TextStyle(
              color: _kDark,
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
                            label: 'Directions active',
                            icon: Icons.navigation_rounded,
                            color: _kGreen,
                            onPressed: null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _MapButton(
                          label: 'Stop',
                          icon: Icons.stop_rounded,
                          color: _kRed,
                          onPressed: _stopDirections,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _MapButton(
                            label: _gettingLocation
                                ? 'Getting location...'
                                : 'Directions',
                            icon: Icons.directions_rounded,
                            color: _kGreen,
                            onPressed:
                                _gettingLocation ? null : _startDirections,
                            loading: _gettingLocation,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MapButton(
                            label: 'Open in Maps',
                            icon: Icons.open_in_new_rounded,
                            color: _kGray,
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
    final effective = onPressed == null && !loading
        ? color.withValues(alpha: 0.6)
        : color;
    return Material(
      color: effective,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: _kGray, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
