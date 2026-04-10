import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failures.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../providers/worker_job_providers.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kGreen  = Color(0xFFFF5F15);
const _kDark   = Color(0xFF1A1A1A);
const _kGray   = Color(0xFF6B7280);
const _kLight  = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);
const _kBg     = Color(0xFFF9FAFB);

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
    final jobAsync = ref.watch(workerJobDetailProvider(jobId));

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _AppBar(),
      body: jobAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: _kDark,
            size: 20,
          ),
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
    final canComplete = job.status.isWorkerActive;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status card ──────────────────────────────────────────
                _StatusCard(job: job),
                const SizedBox(height: 16),

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
                      if (job.description != null &&
                          job.description!.isNotEmpty)
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
                _Section(
                  title: 'Location',
                  child: Column(
                    children: [
                      if (job.address != null && job.address!.isNotEmpty)
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'Address',
                          value: job.address!,
                          multiline: true,
                        ),
                      if (job.city.isNotEmpty)
                        _InfoRow(
                          icon: Icons.location_city_rounded,
                          label: 'City',
                          value: job.city,
                        ),
                      if (job.latitude != 0 || job.longitude != 0)
                        _InfoRow(
                          icon: Icons.my_location_rounded,
                          label: 'Coordinates',
                          value:
                              '${job.latitude.toStringAsFixed(5)}, ${job.longitude.toStringAsFixed(5)}',
                        ),
                    ],
                  ),
                ),
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
                if (job.estimatedPrice != null || job.finalPrice != null)
                  _Section(
                    title: 'Pricing',
                    child: Column(
                      children: [
                        if (job.estimatedPrice != null)
                          _InfoRow(
                            icon: Icons.attach_money_rounded,
                            label: 'Estimated',
                            value:
                                'EGP ${job.estimatedPrice!.toStringAsFixed(0)}',
                          ),
                        if (job.finalPrice != null)
                          _InfoRow(
                            icon: Icons.payments_outlined,
                            label: 'Final Price',
                            value:
                                'EGP ${job.finalPrice!.toStringAsFixed(0)}',
                          ),
                      ],
                    ),
                  ),

                if (job.estimatedPrice != null || job.finalPrice != null)
                  const SizedBox(height: 16),

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
        if (canComplete)
          _CompleteJobBar(jobId: job.id),
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
              color: const Color(0xFFFFF0EB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                job.serviceEmoji,
                style: const TextStyle(fontSize: 24),
              ),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
        (const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
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
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: _kLight),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: _kDark,
                    height: 1.4,
                  ),
                  maxLines: multiline ? null : 2,
                  overflow:
                      multiline ? null : TextOverflow.ellipsis,
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
    final images =
        attachments.where((a) => a.type == AttachmentType.image).toList();
    final videos =
        attachments.where((a) => a.type == AttachmentType.video).toList();
    final audios =
        attachments.where((a) => a.type == AttachmentType.audio).toList();

    return _Section(
      title: 'Attachments',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty) ...[
            const Text(
              'Photos',
              style: TextStyle(fontSize: 12, color: _kLight),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    images[i].url,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: const Color(0xFFF1F5F9),
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: _kLight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (videos.isNotEmpty) ...[
            const Text(
              'Videos',
              style: TextStyle(fontSize: 12, color: _kLight),
            ),
            const SizedBox(height: 8),
            ...videos.map(
              (v) => _MediaRow(
                icon: Icons.videocam_outlined,
                label: v.fileName ?? 'Video',
                color: const Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (audios.isNotEmpty) ...[
            const Text(
              'Voice Notes',
              style: TextStyle(fontSize: 12, color: _kLight),
            ),
            const SizedBox(height: 8),
            ...audios.map(
              (a) => _MediaRow(
                icon: Icons.mic_outlined,
                label: a.fileName ?? 'Audio',
                color: const Color(0xFF0891B2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MediaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MediaRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
  const _StatusHistorySection({required this.history, this.review});

  @override
  Widget build(BuildContext context) {
    final hasReview = review != null;
    return _Section(
      title: 'Status History',
      child: Column(
        children: [
          ...history.asMap().entries.map((e) {
            // When a review row follows, no history entry is the visual last
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
                      Container(
                        width: 1,
                        height: 28,
                        color: _kBorder,
                      ),
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
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: _kGray,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          DateFormat('d MMM, h:mm a').format(entry.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: _kLight,
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
                            ...List.generate(5, (i) => Icon(
                              i < review!.rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 12,
                              color: i < review!.rating
                                  ? const Color(0xFFF59E0B)
                                  : _kBorder,
                            )),
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline_rounded, size: 18),
          label: Text(isLoading ? 'Completing...' : 'Mark as Completed'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
            child:
                const Text('Cancel', style: TextStyle(color: _kLight)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
          // Navigate back (or to home if opened directly from notification).
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
          // Stars + date
          Row(
            children: [
              ...List.generate(5, (i) => Icon(
                i < review.rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
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

          // Comment
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF374151),
                height: 1.5,
              ),
            ),
          ],

          // Client name
          if (clientName != null && clientName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 13, color: _kLight),
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
            const Icon(Icons.error_outline_rounded,
                size: 56, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: _kGray, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
