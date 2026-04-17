import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failures.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../../bookings/presentation/widgets/booking_skeleton.dart';
import '../providers/worker_job_providers.dart';
import '../widgets/worker_bottom_nav_bar.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kGreen  = Color(0xFFDE7356);
const _kDark   = Color(0xFF1A1A1A);
const _kGray   = Color(0xFF6B7280);
const _kLight  = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);
const _kBg     = Color(0xFFF9FAFB);

class WorkerJobsPage extends ConsumerWidget {
  const WorkerJobsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(workerJobsProvider);
    final notifier  = ref.read(workerJobsProvider.notifier);
    final filter    = ref.watch(workerJobsProvider.notifier
        .select((n) => n.currentFilter));

    return Scaffold(
      backgroundColor: _kBg,
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
                'My Jobs',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _kDark,
                  letterSpacing: -0.3,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Filter tabs ──────────────────────────────────────────────
            _FilterTabs(active: filter, onTap: notifier.setFilter),

            const SizedBox(height: 4),

            // ── List ─────────────────────────────────────────────────────
            Expanded(
              child: jobsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: BookingSkeleton(),
                ),
                error: (err, _) => _ErrorState(
                  message: err is Failure
                      ? err.message
                      : 'Failed to load jobs. Please try again.',
                  onRetry: notifier.refresh,
                ),
                data: (jobs) => jobs.isEmpty
                    ? _EmptyState(filter: filter)
                    : RefreshIndicator(
                        color: _kGreen,
                        backgroundColor: Colors.white,
                        onRefresh: notifier.refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                          itemCount: jobs.length,
                          itemBuilder: (ctx, i) => _JobCard(job: jobs[i]),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const WorkerBottomNavBar(currentIndex: 1),
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
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? _kGreen : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? _kGreen : _kBorder,
                ),
              ),
              child: Text(
                f.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : _kGray,
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
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canComplete = job.status.isWorkerActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status accent strip for active jobs ──────────────────────
          if (canComplete)
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: _kGreen,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row ──────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji icon
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0EB),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          job.serviceEmoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.serviceCategory,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: _kDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                job.referenceId,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _kLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (job.clientName != null &&
                                  job.clientName!.isNotEmpty) ...[
                                const Text(
                                  ' · ',
                                  style: TextStyle(
                                      fontSize: 11, color: _kLight),
                                ),
                                const Icon(
                                  Icons.person_outline_rounded,
                                  size: 10,
                                  color: _kLight,
                                ),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    job.clientName!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _kLight,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status chip
                    _StatusChip(status: job.status),
                  ],
                ),

                // ── Title ────────────────────────────────────────────────
                if (job.title != null && job.title!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    job.title!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _kGray,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // ── Meta row ─────────────────────────────────────────────
                Row(
                  children: [
                    // Urgency badge
                    _UrgencyPill(urgency: job.urgency),
                    const SizedBox(width: 8),
                    // Date
                    const Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: _kLight,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _fmtDate(job.acceptedAt ?? job.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: _kLight,
                      ),
                    ),
                  ],
                ),

                // ── Address ──────────────────────────────────────────────
                if (job.address != null && job.address!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: _kLight,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '${job.city.isNotEmpty ? '${job.city}, ' : ''}${job.address!}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _kLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // ── Action buttons ────────────────────────────────────────
                Row(
                  children: [
                    // View Details
                    Expanded(
                      child: _OutlineBtn(
                        label: 'View Details',
                        icon: Icons.open_in_new_rounded,
                        onTap: () =>
                            context.push('/worker/job/${job.id}'),
                      ),
                    ),
                    if (canComplete) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CompleteBtn(jobId: job.id),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today, ${DateFormat('h:mm a').format(dt)}';
    }
    return DateFormat('MMM d, yyyy').format(dt);
  }
}

// ── Complete button (inline in card) ─────────────────────────────────────────

class _CompleteBtn extends ConsumerWidget {
  final String jobId;
  const _CompleteBtn({required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(completeJobProvider).isLoading;

    return GestureDetector(
      onTap: isLoading ? null : () => _confirm(context, ref),
      child: Container(
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _kGreen,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 14,
                color: Colors.white,
              ),
            const SizedBox(width: 5),
            Text(
              isLoading ? 'Completing...' : 'Complete',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
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
            child: const Text('Cancel',
                style: TextStyle(color: _kLight)),
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
        }
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
    final (bg, fg) = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.workerLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  (Color, Color) _colors() {
    if (status.isWorkerActive) {
      return (const Color(0xFFDCFCE7), const Color(0xFF15803D));
    }
    return switch (status) {
      BookingStatus.completed =>
        (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      BookingStatus.cancelled || BookingStatus.rejected =>
        (const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
      _ => (const Color(0xFFF1F5F9), _kGray),
    };
  }
}

class _UrgencyPill extends StatelessWidget {
  final BookingUrgency urgency;
  const _UrgencyPill({required this.urgency});

  @override
  Widget build(BuildContext context) {
    final isUrgent = urgency == BookingUrgency.urgent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:
            isUrgent ? const Color(0xFFFFF7ED) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUrgent ? Icons.bolt_rounded : Icons.schedule_rounded,
            size: 10,
            color: isUrgent
                ? const Color(0xFFEA580C)
                : _kLight,
          ),
          const SizedBox(width: 3),
          Text(
            isUrgent ? 'Urgent' : 'Normal',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isUrgent ? const Color(0xFFEA580C) : _kLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlineBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: _kGray),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final WorkerJobFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final title = switch (filter) {
      WorkerJobFilter.active => 'No active jobs',
      WorkerJobFilter.completed => 'No completed jobs yet',
      WorkerJobFilter.cancelled => 'No cancelled jobs',
      WorkerJobFilter.all => 'No jobs assigned yet',
    };
    final subtitle = switch (filter) {
      WorkerJobFilter.active => 'New requests will appear here',
      WorkerJobFilter.completed => 'Completed jobs will show up here',
      WorkerJobFilter.cancelled => 'Cancelled jobs will show up here',
      WorkerJobFilter.all => 'Accept a booking request to get started',
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
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0EB),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🔧', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _kLight,
                height: 1.4,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF1F2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('⚠️', style: TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: _kLight,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
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
    );
  }
}
