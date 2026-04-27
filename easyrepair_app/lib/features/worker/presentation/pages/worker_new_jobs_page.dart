import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failures.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../domain/entities/new_job_entity.dart';
import '../providers/worker_job_providers.dart';
import '../widgets/worker_bottom_nav_bar.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFDE7356);
const _kDark   = Color(0xFF1A1A1A);
const _kGray   = Color(0xFF6B7280);
const _kLight  = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);
const _kBg     = Color(0xFFF9FAFB);

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
    final jobsAsync = ref.watch(newJobsProvider);
    final notifier  = ref.read(newJobsProvider.notifier);

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
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Jobs',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _kDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pending jobs matching your skills',
                          style: TextStyle(fontSize: 13, color: _kGray),
                        ),
                      ],
                    ),
                  ),
                  // Refresh button
                  GestureDetector(
                    onTap: notifier.refresh,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder),
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: _kAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── List ─────────────────────────────────────────────────────
            Expanded(
              child: jobsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2),
                ),
                error: (err, _) => _ErrorState(
                  message: err is Failure
                      ? err.message
                      : 'Failed to load new jobs.',
                  onRetry: notifier.refresh,
                ),
                data: (jobs) => jobs.isEmpty
                    ? const _EmptyState()
                    : RefreshIndicator(
                        color: _kAccent,
                        backgroundColor: Colors.white,
                        onRefresh: notifier.refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                          itemCount: jobs.length,
                          itemBuilder: (ctx, i) => _NewJobCard(job: jobs[i]),
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

// ── Job card ──────────────────────────────────────────────────────────────────

class _NewJobCard extends StatelessWidget {
  final NewJobEntity job;
  const _NewJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final isUrgent = job.urgency == BookingUrgency.urgent;

    return GestureDetector(
      onTap: () => context.push('/worker/job/${job.id}'),
      child: Container(
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
            // Urgent accent strip
            if (isUrgent)
              Container(
                height: 3,
                decoration: const BoxDecoration(
                  color: Color(0xFFEA580C),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top row: category icon + title + urgency ──────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category icon box
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0EB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.build_circle_outlined,
                            color: _kAccent,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title + category
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.displayTitle,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: _kDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              job.category.name,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _kGray,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),
                      _UrgencyChip(isUrgent: isUrgent),
                    ],
                  ),

                  // ── Description snippet ───────────────────────────────
                  if (job.description != null && job.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      job.description!,
                      style: const TextStyle(
                        fontSize: 12.5,
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

                  // ── Meta row: city, distance, bids, date ──────────────
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      // City
                      if (job.city.isNotEmpty)
                        _MetaChip(
                          icon: Icons.location_on_outlined,
                          label: job.city,
                        ),
                      // Distance
                      if (job.distanceKm != null)
                        _MetaChip(
                          icon: Icons.near_me_outlined,
                          label: job.distanceLabel,
                        ),
                      // Bid count
                      _MetaChip(
                        icon: Icons.gavel_rounded,
                        label: '${job.bidCount} bid${job.bidCount == 1 ? '' : 's'}',
                      ),
                      // Posted time
                      _MetaChip(
                        icon: Icons.access_time_rounded,
                        label: _relativeTime(job.createdAt),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Place bid CTA ─────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/worker/job/${job.id}'),
                      icon: const Icon(Icons.gavel_rounded, size: 15),
                      label: const Text('View & Place Bid'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }
}

// ── Small urgency chip ────────────────────────────────────────────────────────

class _UrgencyChip extends StatelessWidget {
  final bool isUrgent;
  const _UrgencyChip({required this.isUrgent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isUrgent
            ? const Color(0xFFFFF7ED)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUrgent ? Icons.bolt_rounded : Icons.schedule_rounded,
            size: 11,
            color: isUrgent ? const Color(0xFFEA580C) : _kLight,
          ),
          const SizedBox(width: 3),
          Text(
            isUrgent ? 'Urgent' : 'Normal',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isUrgent ? const Color(0xFFEA580C) : _kLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meta chip ─────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: _kLight),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: _kGray),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
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
                child: Text('🔍', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No new jobs right now',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'New job requests matching your skills will appear here. Pull down to refresh.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _kLight,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _kAccent,
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
