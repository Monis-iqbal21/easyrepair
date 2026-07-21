import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../../../core/utils/currency_utils.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../domain/entities/worker_profile_entity.dart';
import '../../domain/entities/ongoing_job_entity.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/worker_review_entity.dart';
import '../providers/worker_providers.dart';
import '../providers/worker_review_providers.dart';
import '../widgets/worker_bottom_nav_bar.dart';
import '../widgets/profile_completion_modal.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kOrange     = Color(0xFFDB6234);
const _kDark       = Color(0xFF1A1A1A);
const _kGray       = Color(0xFF6B7280);
const _kLight      = Color(0xFF94A3B8);
const _kBorder     = Color(0xFFE2E8F0);
const _kBg         = Color(0xFFF7F8FA);
const _kHero       = Color(0xFF121826);

class WorkerHomePage extends ConsumerStatefulWidget {
  const WorkerHomePage({super.key});

  @override
  ConsumerState<WorkerHomePage> createState() => _WorkerHomePageState();
}

class _WorkerHomePageState extends ConsumerState<WorkerHomePage>
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
      ref.read(locationTrackerProvider.notifier).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(workerProfileProvider);

    // Show the "complete your profile" modal once per app session — fires on
    // the first Home build after login/registration/resume-triggered refresh
    // while onboarding isn't APPROVED yet. The persistent banner in
    // _HomeBody covers returning to this screen afterward.
    ref.listen(workerProfileProvider, (previous, next) {
      final profile = next.valueOrNull;
      if (profile == null || profile.isOnboardingApproved) return;
      if (ref.read(onboardingModalShownProvider)) return;
      ref.read(onboardingModalShownProvider.notifier).state = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) showProfileCompletionModal(context);
      });
    });

    return Scaffold(
      backgroundColor: _kBg,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: profileAsync.when(
          skipError: true,
          loading: () => const Center(
            child: CircularProgressIndicator(color: _kOrange),
          ),
          error: (err, _) => _ErrorView(
            message: err.toString(),
            onRetry: () => ref.read(workerProfileProvider.notifier).refresh(),
          ),
          data: (profile) => _HomeBody(
            profile: profile,
          ),
        ),
      ),
      bottomNavigationBar: const WorkerBottomNavBar(currentIndex: 0),
    );
  }
}

// ── Main body ─────────────────────────────────────────────────────────────────

class _HomeBody extends ConsumerWidget {
  final WorkerProfileEntity profile;
  const _HomeBody({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: _kOrange,
      onRefresh: () => ref.read(workerProfileProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header
          const SliverToBoxAdapter(child: _Header()),
          // Persistent profile-completion CTA — always visible (not just the
          // modal) so the worker has a way back without waiting for a resume.
          if (!profile.isOnboardingApproved)
            SliverToBoxAdapter(
              child: _ProfileCompletionBanner(profile: profile),
            ),
          // Hero card (online status + stats)
          SliverToBoxAdapter(child: _HeroCard(profile: profile)),
          // View New Jobs CTA
          SliverToBoxAdapter(child: _NewJobsCta()),
          // Today section
          SliverToBoxAdapter(child: _TodaySection(profile: profile)),
          // Performance section
          SliverToBoxAdapter(child: _PerformanceSection(profile: profile)),
          // Reviews section
          SliverToBoxAdapter(child: _ReviewsSection(profile: profile)),
          // Bottom spacer for nav bar
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ── Profile completion banner ────────────────────────────────────────────────

class _ProfileCompletionBanner extends StatelessWidget {
  final WorkerProfileEntity profile;
  const _ProfileCompletionBanner({required this.profile});

  (String, String) get _statusLabel => switch (profile.onboardingStatus) {
        'SUBMITTED_FOR_REVIEW' => (
            'Submitted for Review',
            'Aap ki profile admin review mein hai.',
          ),
        'CHANGES_REQUIRED' => (
            'Changes Required',
            'Profile mein tabdeeli zaroori hai — details dekhein.',
          ),
        'REJECTED' => (
            'Rejected',
            'Profile reject ho gayi — wajah dekhein.',
          ),
        _ => (
            'Profile Incomplete',
            'Jobs hasil karne ke liye pehle profile approval zaroori hai.',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _statusLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GestureDetector(
        onTap: () => context.push('/worker/profile-completion'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDBA74)),
          ),
          child: Row(
            children: [
              const Icon(Icons.assignment_late_outlined,
                  color: Color(0xFFC2541D), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC2541D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: _kGray),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFC2541D), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
//
// Left: the worker's main skill (e.g. "Electrician") — logout moved to
// Profile/settings, it no longer lives on Home top-left.
// Right: notification bell.

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(workerProfileProvider).valueOrNull?.skills;
    final skillName = (skills != null && skills.isNotEmpty) ? skills.first.categoryName : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              skillName ?? 'Skill not selected',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: skillName != null ? _kDark : _kGray,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Notification bell
          GestureDetector(
            onTap: () => context.push('/notifications'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    size: 20,
                    color: _kDark,
                  ),
                ),
                Consumer(builder: (context, ref, child) {
                  final count =
                      ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: _kOrange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: const TextStyle(
                            fontSize: 7,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Card ─────────────────────────────────────────────────────────────────

class _HeroCard extends ConsumerWidget {
  final WorkerProfileEntity profile;
  const _HeroCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = profile.availabilityStatus;
    final isLoading = ref.watch(availabilityNotifierProvider).isLoading;
    final isOnline = status == AvailabilityStatus.online;
    final isBusy = status == AvailabilityStatus.busy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _kHero,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _kHero.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative orange glow circle
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _kOrange.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status row + toggle
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: isBusy
                              ? const Color(0xFFF59E0B)
                              : isOnline
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFF64748B),
                          shape: BoxShape.circle,
                          boxShadow: (isOnline || isBusy)
                              ? [
                                  BoxShadow(
                                    color: (isOnline
                                            ? const Color(0xFF22C55E)
                                            : const Color(0xFFF59E0B))
                                        .withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isBusy
                            ? 'On Active Job'
                            : isOnline
                                ? 'Online'
                                : 'Offline',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isBusy
                              ? const Color(0xFFF59E0B)
                              : isOnline
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFF94A3B8),
                        ),
                      ),
                      const Spacer(),
                      if (!isBusy)
                        _HeroToggleBtn(
                          label: isLoading
                              ? (isOnline ? 'Going offline...' : 'Connecting...')
                              : (isOnline ? 'Go Offline' : 'Go Online'),
                          isOnline: isOnline,
                          loading: isLoading,
                          locked: !isOnline && !profile.isOnboardingApproved,
                          onTap: () => isOnline
                              ? _handleGoOffline(context, ref)
                              : _handleGoOnline(context, ref),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Earnings
                  const Text(
                    'Aaj ki Kamai',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    "Today's Earnings",
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatPkr(profile.stats.todayEarnings),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats row
                  Row(
                    children: [
                      _HeroStat(
                        label: 'Completed',
                        value: '${profile.stats.completedJobs}',
                        icon: Icons.check_circle_outline_rounded,
                      ),
                      const SizedBox(width: 10),
                      _HeroStat(
                        label: 'Rating',
                        value: profile.rating > 0
                            ? profile.rating.toStringAsFixed(1)
                            : '—',
                        icon: Icons.star_outline_rounded,
                      ),
                      const SizedBox(width: 10),
                      _HeroStat(
                        label: 'Active',
                        value: '${profile.stats.activeJobs}',
                        icon: Icons.bolt_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGoOnline(BuildContext context, WidgetRef ref) async {
    if (!profile.isOnboardingApproved) {
      _showSnack(
        context,
        'Profile approval required before receiving jobs.\n'
        'Jobs hasil karne ke liye pehle profile approval zaroori hai.',
      );
      return;
    }
    final result =
        await ref.read(availabilityNotifierProvider.notifier).goOnline();
    if (result == AvailabilityToggleResult.needsSkills && context.mounted) {
      await showSkillsSheet(context, ref);
    } else if (context.mounted) {
      final err = ref.read(availabilityNotifierProvider).error;
      if (err != null) _showSnack(context, err.toString());
    }
  }

  Future<void> _handleGoOffline(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Go Offline?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: const Text('You will stop appearing to nearby clients.',
            style: TextStyle(color: _kGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _kGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Yes, Go Offline'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(availabilityNotifierProvider.notifier).goOffline();
      if (context.mounted) {
        final err = ref.read(availabilityNotifierProvider).error;
        if (err != null) _showSnack(context, err.toString());
      }
    }
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

class _HeroToggleBtn extends StatelessWidget {
  final String label;
  final bool isOnline;
  final bool loading;
  final bool locked;
  final VoidCallback onTap;
  const _HeroToggleBtn({
    required this.label,
    required this.isOnline,
    required this.loading,
    this.locked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Opacity(
        opacity: locked ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isOnline
                ? Colors.white.withValues(alpha: 0.1)
                : _kOrange,
            borderRadius: BorderRadius.circular(20),
            border: isOnline
                ? Border.all(color: Colors.white.withValues(alpha: 0.2))
                : null,
          ),
          child: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (locked) ...[
                      const Icon(Icons.lock_outline_rounded, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _HeroStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: _kOrange),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── View New Jobs CTA ─────────────────────────────────────────────────────────

class _NewJobsCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => context.go('/worker/new-jobs'),
          icon: const Icon(Icons.work_outline_rounded, size: 18),
          label: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Naya Kaam Dhondain',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Text(
                'View New Jobs',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
              ),
            ],
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kOrange,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            shadowColor: _kOrange.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

// ── Today Section ─────────────────────────────────────────────────────────────

class _TodaySection extends StatelessWidget {
  final WorkerProfileEntity profile;
  const _TodaySection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final job = profile.ongoingJob;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Today',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kDark,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go('/worker/jobs'),
                child: const Text(
                  'My Jobs',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          job != null
              ? _ActiveJobCard(job: job)
              : _NoJobCard(),
        ],
      ),
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  final OngoingJobEntity job;
  const _ActiveJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel(job.status);
    final statusColor = _statusColor(job.status);

    return GestureDetector(
      onTap: () => context.push('/worker/job/${job.id}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _kOrange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'ACTIVE JOB',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _kOrange,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              job.title ?? job.categoryName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 12, color: _kLight),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    job.clientArea,
                    style: const TextStyle(fontSize: 12, color: _kGray),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'View details →',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kOrange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
        return 'Accepted';
      case 'EN_ROUTE':
        return 'En Route';
      case 'IN_PROGRESS':
        return 'In Progress';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
        return const Color(0xFF3B82F6);
      case 'EN_ROUTE':
        return const Color(0xFFF59E0B);
      case 'IN_PROGRESS':
        return _kOrange;
      default:
        return _kGray;
    }
  }
}

class _NoJobCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inbox_outlined, color: _kLight, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'No active job right now',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kDark,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Online rahein, nazdeek ka kaam dhondne ke liye.',
                  style: TextStyle(fontSize: 12, color: _kGray),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Ready',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF16A34A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Performance Section ───────────────────────────────────────────────────────

class _PerformanceSection extends StatelessWidget {
  final WorkerProfileEntity profile;
  const _PerformanceSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _PerfCard(
                label: 'Jobs Done',
                value: '${profile.stats.completedJobs}',
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF22C55E),
              ),
              const SizedBox(width: 10),
              _PerfCard(
                label: 'Cancel Rate',
                value: '${profile.stats.cancellationRate}%',
                icon: Icons.cancel_outlined,
                iconColor: const Color(0xFFEF4444),
              ),
              const SizedBox(width: 10),
              _PerfCard(
                label: 'Response',
                value: profile.stats.responseLabel ?? '—',
                icon: Icons.bolt_rounded,
                iconColor: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerfCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  const _PerfCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: _kGray),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reviews section ───────────────────────────────────────────────────────────

class _ReviewsSection extends ConsumerWidget {
  final WorkerProfileEntity profile;
  const _ReviewsSection({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(workerRecentReviewsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Reviews',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kDark,
                ),
              ),
              if (profile.totalRatings > 0) ...[
                const SizedBox(width: 8),
                const Icon(Icons.star_rounded,
                    size: 14, color: Color(0xFFF59E0B)),
                const SizedBox(width: 3),
                Text(
                  '${profile.rating.toStringAsFixed(1)} · ${profile.totalRatings}',
                  style: const TextStyle(fontSize: 12, color: _kGray),
                ),
              ],
              const Spacer(),
              if (profile.totalRatings > 0)
                GestureDetector(
                  onTap: () => context.push('/worker/reviews'),
                  child: const Text(
                    'See all →',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kOrange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          reviewsAsync.when(
            loading: () => const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kOrange),
            ),
            error: (e, s) => const SizedBox.shrink(),
            data: (reviews) => reviews.isEmpty
                ? _EmptyReviews()
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: reviews
                          .asMap()
                          .entries
                          .map((e) => _ReviewItem(
                                review: e.value,
                                isLast: e.key == reviews.length - 1,
                              ))
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star_outline_rounded,
              color: Color(0xFFF59E0B),
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No reviews yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Client reviews will appear here after your completed jobs.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _kGray, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final WorkerReviewEntity review;
  final bool isLast;
  const _ReviewItem({required this.review, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      return Icon(
                        i < review.rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 13,
                        color: i < review.rating
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFD1D5DB),
                      );
                    }),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('MMM d, yyyy').format(review.createdAt),
                    style: const TextStyle(fontSize: 10, color: _kLight),
                  ),
                ],
              ),
              if (review.comment != null && review.comment!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  review.comment!,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                      height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    review.serviceCategory,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _kOrange,
                    ),
                  ),
                  if (review.clientName != null &&
                      review.clientName!.isNotEmpty) ...[
                    const Text('  ·  ',
                        style: TextStyle(fontSize: 11, color: _kLight)),
                    Text(
                      review.clientName!,
                      style: const TextStyle(fontSize: 11, color: _kGray),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: _kBorder),
      ],
    );
  }
}

// ── Skills bottom sheet ───────────────────────────────────────────────────────

Future<void> showSkillsSheet(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(workerProfileProvider).valueOrNull;
  // Only one main skill is allowed — pre-select just the first existing one
  // (legacy profiles saved before this rule may carry more than one; opening
  // the sheet already narrows the working selection down to a single skill).
  final existingId = profile?.skills.isNotEmpty == true
      ? profile!.skills.first.categoryId
      : null;
  ref.read(selectedCategoryIdsProvider.notifier).state =
      existingId != null ? {existingId} : {};

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: const _SkillsSheet(),
    ),
  );
}

class _SkillsSheet extends ConsumerWidget {
  const _SkillsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final selected = ref.watch(selectedCategoryIdsProvider);
    final isSaving = ref.watch(skillsNotifierProvider).isLoading;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select your main skill',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Select your main skill to start receiving work',
                  style: TextStyle(fontSize: 13, color: _kGray),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          categoriesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                  child: CircularProgressIndicator(color: _kOrange)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Failed to load categories: $e'),
            ),
            data: (categories) => _CategoryChips(
              categories: categories,
              selected: selected,
              // Single-select: choosing a category always replaces the
              // current selection (radio-button semantics) rather than
              // toggling membership — a worker may have only one main skill.
              onToggle: (id) {
                ref.read(selectedCategoryIdsProvider.notifier).state = {id};
              },
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (isSaving || selected.isEmpty)
                    ? null
                    : () async {
                        final saved = await ref
                            .read(skillsNotifierProvider.notifier)
                            .saveSkills(selected.toList());
                        if (!context.mounted) return;
                        if (saved) {
                          Navigator.pop(context);
                          await ref
                              .read(availabilityNotifierProvider.notifier)
                              .goOnline();
                        } else {
                          final err =
                              ref.read(skillsNotifierProvider).error;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err?.toString() ??
                                  'Failed to save skills. Please try again.'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        selected.isEmpty
                            ? 'Select your main skill'
                            : 'Save & Go Online',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<CategoryEntity> categories;
  final Set<String> selected;
  final void Function(String id) onToggle;

  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: categories.map((cat) {
          final isSelected = selected.contains(cat.id);
          return GestureDetector(
            onTap: () => onToggle(cat.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? _kOrange : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: isSelected ? _kOrange : _kBorder,
                ),
              ),
              child: Text(
                cat.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : _kGray,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: _kLight),
            const SizedBox(height: 12),
            const Text(
              'Failed to load dashboard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _kGray),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
