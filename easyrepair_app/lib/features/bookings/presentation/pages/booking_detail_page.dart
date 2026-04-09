import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/nearby_worker_entity.dart';
import '../../domain/entities/update_booking_request.dart';
import '../providers/booking_providers.dart';
import '../widgets/status_badge.dart';
import '../widgets/urgency_badge.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kGreen  = Color(0xFFFF5F15);
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

    return Scaffold(
      backgroundColor: _kBg,
      body: bookingAsync.when(
        loading: () => _LoadingSkeleton(bookingId: widget.bookingId),
        error: (err, _) => _ErrorScreen(
          message: err is Failure ? err.message : 'Failed to load booking.',
          onRetry: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
        ),
        data: (booking) => _DetailBody(booking: booking),
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
                onPressed: () => context.pop(),
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

class _DetailBody extends ConsumerWidget {
  final BookingEntity booking;

  const _DetailBody({required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLive = booking.status.tab == BookingTab.live;
    final isCompleted = booking.status == BookingStatus.completed;
    final isCancelled = booking.status.tab == BookingTab.cancelled;
    final canEdit = booking.status == BookingStatus.pending &&
        booking.assignedWorker == null;

    return CustomScrollView(
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

                // Service info
                _InfoCard(
                  title: 'Service Details',
                  children: [
                    _InfoRow(
                      icon: Icons.build_circle_outlined,
                      label: 'Service',
                      value: '${booking.serviceEmoji}  ${booking.serviceCategory}',
                    ),
                    if (booking.title != null && booking.title!.isNotEmpty)
                      _InfoRow(
                        icon: Icons.title_rounded,
                        label: 'Issue',
                        value: booking.title!,
                      ),
                    if (booking.description != null &&
                        booking.description!.isNotEmpty)
                      _InfoRow(
                        icon: Icons.description_outlined,
                        label: 'Description',
                        value: booking.description!,
                        multiline: true,
                      ),
                    _InfoRow(
                      icon: Icons.bolt_rounded,
                      label: 'Urgency',
                      value: booking.urgency == BookingUrgency.urgent
                          ? 'Urgent'
                          : 'Normal',
                    ),
                    if (booking.timeSlot != null)
                      _InfoRow(
                        icon: Icons.access_time_rounded,
                        label: 'Time Window',
                        value: booking.timeSlot!.label,
                      ),
                    if (booking.scheduledDate != null)
                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Scheduled Date',
                        value: DateFormat('EEE, d MMM yyyy')
                            .format(booking.scheduledDate!),
                      ),
                    _InfoRow(
                      icon: Icons.access_time_filled_rounded,
                      label: 'Created',
                      value: DateFormat('d MMM yyyy, h:mm a')
                          .format(booking.createdAt),
                    ),
                    if (isCompleted && booking.completedAt != null)
                      _InfoRow(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Completed',
                        value: DateFormat('d MMM yyyy, h:mm a')
                            .format(booking.completedAt!),
                      ),
                    if (isCancelled &&
                        booking.cancellationReason != null &&
                        booking.cancellationReason!.isNotEmpty)
                      _InfoRow(
                        icon: Icons.cancel_outlined,
                        label: 'Cancellation Reason',
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

                // Pricing
                if (booking.estimatedPrice != null || booking.finalPrice != null)
                  _PricingCard(booking: booking),

                // Worker section
                if (booking.assignedWorker != null) ...[
                  if (booking.estimatedPrice != null ||
                      booking.finalPrice != null)
                    const SizedBox(height: 16),
                  _WorkerCard(worker: booking.assignedWorker!),
                  const SizedBox(height: 16),
                  _WorkerMapSection(
                    worker: booking.assignedWorker!,
                    jobLat: booking.latitude,
                    jobLng: booking.longitude,
                  ),
                ] else if (booking.status == BookingStatus.pending) ...[
                  const SizedBox(height: 16),
                  _NearbyWorkersSection(bookingId: booking.id),
                ],
                const SizedBox(height: 16),

                // Review section (completed bookings only)
                if (isCompleted) ...[
                  _ReviewSection(booking: booking),
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
        onPressed: () => context.pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking Details',
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
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(booking.serviceEmoji,
                  style: const TextStyle(fontSize: 24)),
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
                Row(
                  children: [
                    StatusBadge(status: booking.status),
                    const SizedBox(width: 6),
                    UrgencyBadge(urgency: booking.urgency, small: true),
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
          const Text(
            'Service Address',
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
                  color: Color(0xFFFF5F15),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasAddress ? address : 'No address provided',
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
          const Text(
            'Attachments',
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
              label: 'Photos (${images.length})',
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) => _ImageThumbnail(url: images[i].url),
              ),
            ),
          ],

          // ── Videos ──────────────────────────────────────────────────────
          if (videos.isNotEmpty) ...[
            if (images.isNotEmpty) const SizedBox(height: 14),
            _attachmentSectionLabel(
              icon: Icons.videocam_outlined,
              label: 'Videos (${videos.length})',
            ),
            const SizedBox(height: 8),
            Column(
              children: videos
                  .map((v) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _VideoTile(attachment: v),
                      ))
                  .toList(),
            ),
          ],

          // ── Audio ────────────────────────────────────────────────────────
          if (audios.isNotEmpty) ...[
            if (images.isNotEmpty || videos.isNotEmpty)
              const SizedBox(height: 14),
            _attachmentSectionLabel(
              icon: Icons.mic_none_rounded,
              label: 'Voice Note',
            ),
            const SizedBox(height: 8),
            ...audios.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AudioTile(attachment: a),
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

class _ImageThumbnail extends StatelessWidget {
  final String url;
  const _ImageThumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullImage(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.broken_image_outlined, color: _kLight),
          ),
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kGreen,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final BookingAttachmentEntity attachment;
  const _VideoTile({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.play_circle_outline_rounded,
              color: Color(0xFFFF5F15),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName ?? 'Video',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _kDark,
                  ),
                ),
                const Text(
                  'Video attachment',
                  style: TextStyle(fontSize: 11, color: _kLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioTile extends StatelessWidget {
  final BookingAttachmentEntity attachment;
  const _AudioTile({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: Color(0xFF15803D),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName ?? 'Voice Note',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF166534),
                  ),
                ),
                const Text(
                  'Audio recording',
                  style: TextStyle(fontSize: 11, color: Color(0xFF4ADE80)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pricing card ──────────────────────────────────────────────────────────────

class _PricingCard extends StatelessWidget {
  final BookingEntity booking;

  const _PricingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final isCompleted = booking.status == BookingStatus.completed;

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
          const Text(
            'Pricing',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 12),
          if (booking.estimatedPrice != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estimated Price',
                  style: TextStyle(fontSize: 13, color: _kGray),
                ),
                Text(
                  'EGP ${booking.estimatedPrice!.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isCompleted ? _kLight : _kDark,
                    decoration: isCompleted && booking.finalPrice != null
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ],
            ),
          if (isCompleted && booking.finalPrice != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Final Price',
                  style: TextStyle(fontSize: 13, color: _kGray),
                ),
                Text(
                  'EGP ${booking.finalPrice!.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
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

// ── Worker card ───────────────────────────────────────────────────────────────

class _WorkerCard extends StatelessWidget {
  final AssignedWorkerEntity worker;

  const _WorkerCard({required this.worker});

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
          const Text(
            'Assigned Worker',
            style: TextStyle(
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
                          errorBuilder: (_, __, ___) =>
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

class _WorkerMapSection extends StatelessWidget {
  final AssignedWorkerEntity worker;
  final double jobLat;
  final double jobLng;

  const _WorkerMapSection({
    required this.worker,
    required this.jobLat,
    required this.jobLng,
  });

  static const _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  @override
  Widget build(BuildContext context) {
    final hasLocation = worker.currentLat != null && worker.currentLng != null;
    final canShowMap = hasLocation && _apiKey.isNotEmpty;

    final distanceM = hasLocation
        ? haversineDistanceMeters(
            worker.currentLat!, worker.currentLng!, jobLat, jobLng)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Location',
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
                          ? 'Tracking ${worker.fullName.split(' ').first}'
                          : 'Waiting for worker to share location',
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
            _StaticMap(
              workerLat: worker.currentLat!,
              workerLng: worker.currentLng!,
              jobLat: jobLat,
              jobLng: jobLng,
              apiKey: _apiKey,
            )
          else
            _MapFallback(hasLocation: hasLocation),

          // ── Distance bar ──────────────────────────────────────────────────
          if (hasLocation && distanceM != null)
            _DistanceBar(distanceM: distanceM)
          else if (!hasLocation)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Text(
                'Live location not available yet',
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
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'Live',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF15803D),
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Static map ────────────────────────────────────────────────────────────────

class _StaticMap extends StatelessWidget {
  final double workerLat;
  final double workerLng;
  final double jobLat;
  final double jobLng;
  final String apiKey;

  const _StaticMap({
    required this.workerLat,
    required this.workerLng,
    required this.jobLat,
    required this.jobLng,
    required this.apiKey,
  });

  String get _mapUrl {
    // Use `visible` to auto-fit both markers — more robust than manual center+zoom.
    final wLat = workerLat.toStringAsFixed(6);
    final wLng = workerLng.toStringAsFixed(6);
    final jLat = jobLat.toStringAsFixed(6);
    final jLng = jobLng.toStringAsFixed(6);

    // Styled markers: filled blue circle for worker, red pin for job.
    final workerMarker = 'color:0x1B5E4B%7Csize:mid%7Clabel:W%7C$wLat,$wLng';
    final jobMarker = 'color:0xDC2626%7Csize:mid%7Clabel:J%7C$jLat,$jLng';

    // Clean map styles: hide POI, transit, simplify labels.
    const styles =
        '&style=feature:poi%7Cvisibility:off'
        '&style=feature:transit%7Cvisibility:off'
        '&style=feature:road%7Celement:labels.icon%7Cvisibility:off'
        '&style=feature:administrative.neighborhood%7Cvisibility:off';

    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?visible=$wLat,$wLng'
        '&visible=$jLat,$jLng'
        '&size=640x320'
        '&scale=2'
        '&maptype=roadmap'
        '&markers=$workerMarker'
        '&markers=$jobMarker'
        '$styles'
        '&key=$apiKey';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      width: double.infinity,
      child: Image.network(
        _mapUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _MapFallback(hasLocation: true),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _kGreen,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Map fallback ──────────────────────────────────────────────────────────────

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
            hasLocation ? 'Map preview unavailable' : 'Location pending',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kGray,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            hasLocation
                ? 'Could not load the map image'
                : 'Will appear once the worker is en route',
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
    final label = formatDistance(distanceM);
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
              color: isClose
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isClose
                  ? Icons.directions_walk_rounded
                  : Icons.directions_car_rounded,
              size: 18,
              color: isClose
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFFF5F15),
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
                isClose ? 'Worker is nearly there' : 'Worker is on the way',
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
          const Text(
            'Live · Updated now',
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

// ── Nearby workers section ────────────────────────────────────────────────────

class _NearbyWorkersSection extends ConsumerWidget {
  final String bookingId;

  const _NearbyWorkersSection({required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nearbyWorkersNotifierProvider(bookingId));

    // ── Dynamic header subtitle ──────────────────────────────────────────────
    final String subtitle;
    if (state.hasError && state.workers.isEmpty) {
      subtitle = 'Could not load workers';
    } else if (state.workers.isEmpty && state.isExpanding) {
      subtitle = 'Searching nearby workers...';
    } else if (state.workers.isNotEmpty && state.isExpanding) {
      subtitle = '${state.workers.length} found · searching wider area...';
    } else if (state.workers.isEmpty) {
      subtitle = 'No workers found within 20 km';
    } else {
      final r = state.searchedRadiusKm.toStringAsFixed(0);
      subtitle = '${state.workers.length} available · within $r km';
    }

    // ── Content ──────────────────────────────────────────────────────────────
    final Widget content;
    if (state.hasError && state.workers.isEmpty) {
      content = _WorkersErrorState(
        message: state.error is Failure
            ? (state.error as Failure).message
            : 'Could not load workers.',
        onRetry: () => ref.invalidate(nearbyWorkersNotifierProvider(bookingId)),
      );
    } else if (state.workers.isEmpty && state.isExpanding) {
      content = const _WorkersLoadingState();
    } else if (state.workers.isEmpty) {
      content = const _WorkersEmptyState();
    } else {
      content = Column(
        children: [
          ...state.workers.map(
            (w) => _NearbyWorkerCard(worker: w, bookingId: bookingId),
          ),
          // Subtle "searching more" banner shown while expansion continues.
          if (state.isExpanding)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
              child: Row(
                children: const [
                  SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(_kLight),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Searching wider area for more workers...',
                    style: TextStyle(fontSize: 11.5, color: _kLight),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nearby Workers',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: _kLight,
                        ),
                      ),
                    ],
                  ),
                ),
                // Refresh restarts the full expansion from 2 km.
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: _kGray),
                  tooltip: 'Refresh',
                  onPressed: () =>
                      ref.invalidate(nearbyWorkersNotifierProvider(bookingId)),
                ),
              ],
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────────
          content,
        ],
      ),
    );
  }
}

// ── Loading state ─────────────────────────────────────────────────────────────

class _WorkersLoadingState extends StatelessWidget {
  const _WorkersLoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      child: Column(
        children: List.generate(
          2,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _WorkersEmptyState extends StatelessWidget {
  const _WorkersEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_search_rounded,
                size: 24, color: _kLight),
          ),
          const SizedBox(height: 12),
          const Text(
            'No nearby workers found right now',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'We searched up to 20 km. Try again in a few minutes\nas more workers come online.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _kLight, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _WorkersErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _WorkersErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: _kGray),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try again'),
            style: TextButton.styleFrom(foregroundColor: _kGreen),
          ),
        ],
      ),
    );
  }
}

// ── Nearby worker card ────────────────────────────────────────────────────────

class _NearbyWorkerCard extends ConsumerWidget {
  final NearbyWorkerEntity worker;
  final String bookingId;

  const _NearbyWorkerCard({required this.worker, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignState = ref.watch(assignWorkerNotifierProvider);
    final isAssigning = assignState.isLoading;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          _WorkerAvatar(worker: worker),
          const SizedBox(width: 12),

          // Info + buttons
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row + distance chip
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        worker.fullName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    _DistanceChip(label: worker.distanceLabel),
                  ],
                ),
                const SizedBox(height: 4),

                // Rating + completed jobs + skills
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 13, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 3),
                    Text(
                      worker.ratingLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kGray,
                      ),
                    ),
                    if (worker.skills.isNotEmpty) ...[
                      const Text(
                        '  ·  ',
                        style: TextStyle(color: _kLight, fontSize: 12),
                      ),
                      Expanded(
                        child: Text(
                          worker.skills.take(3).join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kGray,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    // Chat placeholder
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('Chat coming soon'),
                          duration: Duration(seconds: 2),
                        )),
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 15,
                        ),
                        label: const Text('Chat'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kGray,
                          side: const BorderSide(color: _kBorder),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          textStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Assign button
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: isAssigning
                            ? null
                            : () => _assign(context, ref),
                        icon: isAssigning
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 15,
                              ),
                        label: Text(isAssigning ? 'Assigning…' : 'Assign Worker'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _kGreen,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          textStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(assignWorkerNotifierProvider.notifier)
          .assign(bookingId, worker.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${worker.firstName} has been assigned to your job.'),
          backgroundColor: const Color(0xFF15803D),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is Failure ? e.message : 'Failed to assign worker.'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }
}

class _WorkerAvatar extends StatelessWidget {
  final NearbyWorkerEntity worker;

  const _WorkerAvatar({required this.worker});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
      child: worker.avatarUrl != null
          ? ClipOval(
              child: Image.network(
                worker.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _Initials(worker.initials),
              ),
            )
          : _Initials(worker.initials),
    );
  }
}

class _Initials extends StatelessWidget {
  final String initials;
  const _Initials(this.initials);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DistanceChip extends StatelessWidget {
  final String label;
  const _DistanceChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.near_me_rounded, size: 10, color: Color(0xFF0284C7)),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0284C7),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Review section ────────────────────────────────────────────────────────────

class _ReviewSection extends ConsumerStatefulWidget {
  final BookingEntity booking;

  const _ReviewSection({required this.booking});

  @override
  ConsumerState<_ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends ConsumerState<_ReviewSection> {
  int _selectedRating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existingReview = widget.booking.review;

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
            children: const [
              Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
              SizedBox(width: 6),
              Text(
                'Review',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (existingReview != null)
            _ExistingReview(review: existingReview)
          else
            _ReviewForm(
              selectedRating: _selectedRating,
              commentCtrl: _commentCtrl,
              submitting: _submitting,
              onRatingChanged: (r) => setState(() => _selectedRating = r),
              onSubmit: _submit,
            ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a star rating.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(reviewNotifierProvider.notifier).submit(
            ReviewRequest(
              bookingId: widget.booking.id,
              rating: _selectedRating,
              comment: _commentCtrl.text.trim().isEmpty
                  ? null
                  : _commentCtrl.text.trim(),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Review submitted. Thank you!'),
            backgroundColor: _kGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is Failure ? e.message : 'Failed to submit review.'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _ExistingReview extends StatelessWidget {
  final BookingReviewEntity review;

  const _ExistingReview({required this.review});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    );
  }
}

class _ReviewForm extends StatelessWidget {
  final int selectedRating;
  final TextEditingController commentCtrl;
  final bool submitting;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSubmit;

  const _ReviewForm({
    required this.selectedRating,
    required this.commentCtrl,
    required this.submitting,
    required this.onRatingChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How was the service?',
          style: TextStyle(fontSize: 13, color: _kGray),
        ),
        const SizedBox(height: 10),
        // Star rating picker
        Row(
          children: List.generate(
            5,
            (i) => GestureDetector(
              onTap: () => onRatingChanged(i + 1),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.star_rounded,
                  size: 32,
                  color: i < selectedRating
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Comment field
        TextField(
          controller: commentCtrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 13, color: _kDark),
          decoration: InputDecoration(
            hintText: 'Add a comment (optional)...',
            hintStyle: const TextStyle(fontSize: 13, color: _kLight),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kGreen),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: submitting ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              disabledBackgroundColor: _kGreen.withValues(alpha: 0.5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Submit Review',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
          ),
        ),
      ],
    );
  }
}

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
    final showCancel = booking.status == BookingStatus.pending &&
        booking.assignedWorker == null;
    final showChat = booking.assignedWorker != null;

    if (!canEdit && !showCancel && !showChat) return const SizedBox.shrink();

    return Column(
      children: [
        if (showChat)
          _FullBtn(
            label: 'Chat with Worker',
            icon: Icons.chat_bubble_outline_rounded,
            color: const Color(0xFFFF5F15),
            bgColor: const Color(0xFFFFF0EB),
            onTap: () => context.push('/client/chat'),
          ),
        if (showChat && (canEdit || showCancel)) const SizedBox(height: 10),
        if (canEdit)
          _FullBtn(
            label: 'Edit Booking',
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
            label: 'Cancel Booking',
            icon: Icons.close_rounded,
            color: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFFF1F2),
            onTap: () => _confirmCancel(context, ref),
          ),
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Cancel Booking?',
          style: TextStyle(fontWeight: FontWeight.w700, color: _kDark),
        ),
        content: Text(
          'Cancel ${booking.serviceCategory} request ${booking.referenceId}?',
          style: const TextStyle(color: _kGray, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it',
                style: TextStyle(color: _kGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, cancel',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(bookingsNotifierProvider.notifier)
            .cancelBooking(booking.id);
        if (context.mounted) context.pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  e is Failure ? e.message : 'Failed to cancel booking.'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
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
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Booking Details',
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
              const Text(
                'Failed to load booking',
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
    );
  }
}
