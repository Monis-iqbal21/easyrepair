import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../domain/entities/worker_profile_entity.dart';
import '../../domain/entities/ongoing_job_entity.dart';
import '../../domain/entities/worker_skill_entity.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/worker_review_entity.dart';
import '../providers/worker_providers.dart';
import '../providers/worker_review_providers.dart';
import '../widgets/worker_bottom_nav_bar.dart';

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
    final authState = ref.watch(authStateProvider);
    final firstName = authState.valueOrNull?.firstName ?? 'there';
    final profileAsync = ref.watch(workerProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $firstName 👋',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        profileAsync.when(
                          data: (p) => Text(
                            _subtitle(p.availabilityStatus),
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          loading: () => const Text(
                            'Loading your dashboard...',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          error: (_, __) => const Text(
                            'Ready to start work today?',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            size: 20,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Consumer(
                          builder: (_, ref, __) {
                            final count = ref
                                .watch(unreadNotificationCountProvider)
                                .valueOrNull ?? 0;
                            if (count == 0) return const SizedBox.shrink();
                            return Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDE7356),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                ),
                                child: Center(
                                  child: Text(
                                    count > 9 ? '9+' : '$count',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => ref.read(logoutNotifierProvider.notifier).logout(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: Color(0xFFDE7356),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Scrollable content ───────────────────────────────────────
            Expanded(
              child: profileAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => _ErrorCard(
                  message: err.toString(),
                  onRetry: () => ref.read(workerProfileProvider.notifier).refresh(),
                ),
                data: (profile) => _DashboardContent(profile: profile),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const WorkerBottomNavBar(currentIndex: 0),
    );
  }

  String _subtitle(AvailabilityStatus status) {
    switch (status) {
      case AvailabilityStatus.online:
        return 'You are live and accepting jobs';
      case AvailabilityStatus.busy:
        return 'You have an active job in progress';
      case AvailabilityStatus.offline:
        return 'Ready to start work today?';
    }
  }
}

// ── Dashboard Content (after data loads) ─────────────────────────────────────

class _DashboardContent extends ConsumerWidget {
  final WorkerProfileEntity profile;
  const _DashboardContent({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(workerProfileProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Availability Card
            _AvailabilityCard(profile: profile),
            const SizedBox(height: 20),

            // 2. Ongoing Job
            _OngoingJobCard(job: profile.ongoingJob),
            const SizedBox(height: 20),

            // 3. Skills Section
            _SkillsSection(skills: profile.skills),
            const SizedBox(height: 20),

            // 4. Stats Section
            _StatsSection(profile: profile),
            const SizedBox(height: 20),

            // 5. Reviews Section
            _ReviewsSection(profile: profile),
            const SizedBox(height: 20),

            // 6. Info Card
            _InfoCard(status: profile.availabilityStatus, hasSkills: profile.skills.isNotEmpty),
            const SizedBox(height: 100), // nav clearance
          ],
        ),
      ),
    );
  }
}

// ── 1. Availability Card ─────────────────────────────────────────────────────

class _AvailabilityCard extends ConsumerWidget {
  final WorkerProfileEntity profile;
  const _AvailabilityCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = profile.availabilityStatus;
    final isLoading =
        ref.watch(availabilityNotifierProvider).isLoading;

    final cardColor = _cardColor(status);
    final dotColor = _dotColor(status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: dotColor.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _labelColor(status),
                ),
              ),
              const Spacer(),
              if (status == AvailabilityStatus.busy)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Active Job',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status.helperText,
            style: TextStyle(
              fontSize: 13,
              color: _labelColor(status).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(context, ref, status, isLoading),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    WidgetRef ref,
    AvailabilityStatus status,
    bool isLoading,
  ) {
    if (status == AvailabilityStatus.busy) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.work_rounded, size: 18),
        label: const Text('On Active Job'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B35).withOpacity(0.15),
          foregroundColor: const Color(0xFFFF6B35),
          disabledBackgroundColor: const Color(0xFFFF6B35).withOpacity(0.10),
          disabledForegroundColor: const Color(0xFFFF6B35).withOpacity(0.5),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }

    if (status == AvailabilityStatus.offline) {
      return ElevatedButton.icon(
        onPressed: isLoading ? null : () => _handleGoOnline(context, ref),
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.power_settings_new_rounded, size: 18),
        label: Text(isLoading ? 'Connecting...' : 'Go Online'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDE7356),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }

    // Online → show Go Offline
    return ElevatedButton.icon(
      onPressed: isLoading ? null : () => _handleGoOffline(context, ref),
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.power_settings_new_rounded, size: 18),
      label: Text(isLoading ? 'Going offline...' : 'Go Offline'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFDE7356),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFDE7356), width: 1.5),
        ),
      ),
    );
  }

  Future<void> _handleGoOnline(BuildContext context, WidgetRef ref) async {
    final result =
        await ref.read(availabilityNotifierProvider.notifier).goOnline();

    if (result == AvailabilityToggleResult.needsSkills && context.mounted) {
      await _showSkillsSheet(context, ref);
    } else if (context.mounted) {
      final err = ref.read(availabilityNotifierProvider).error;
      if (err != null) {
        _showSnack(context, err.toString());
      }
    }
  }

  Future<void> _handleGoOffline(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Go Offline?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: const Text(
          'You will stop appearing to nearby clients.',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDE7356),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Color _cardColor(AvailabilityStatus s) {
    switch (s) {
      case AvailabilityStatus.online:
        return const Color(0xFFE8F5E9);
      case AvailabilityStatus.busy:
        return const Color(0xFFFFF3E0);
      case AvailabilityStatus.offline:
        return Colors.white;
    }
  }

  Color _dotColor(AvailabilityStatus s) {
    switch (s) {
      case AvailabilityStatus.online:
        return const Color(0xFF2E7D32);
      case AvailabilityStatus.busy:
        return const Color(0xFFFF6B35);
      case AvailabilityStatus.offline:
        return Colors.grey.shade400;
    }
  }

  Color _labelColor(AvailabilityStatus s) {
    switch (s) {
      case AvailabilityStatus.online:
        return const Color(0xFF1B5E20);
      case AvailabilityStatus.busy:
        return const Color(0xFFE65100);
      case AvailabilityStatus.offline:
        return const Color(0xFF1A1A1A);
    }
  }
}

// ── Skills Bottom Sheet ──────────────────────────────────────────────────────

Future<void> _showSkillsSheet(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(workerProfileProvider).valueOrNull;
  final existingIds = profile?.skills.map((s) => s.categoryId).toSet() ?? {};
  ref.read(selectedCategoryIdsProvider.notifier).state = existingIds;

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
                  'Add your skills first',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Select at least one service to start receiving work',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          categoriesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Failed to load categories: $e'),
            ),
            data: (categories) => _CategoryChips(
              categories: categories,
              selected: selected,
              onToggle: (id) {
                final current = Set<String>.from(ref.read(selectedCategoryIdsProvider));
                if (current.contains(id)) {
                  current.remove(id);
                } else {
                  current.add(id);
                }
                ref.read(selectedCategoryIdsProvider.notifier).state = current;
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
                          // After saving skills, attempt go online again
                          await ref
                              .read(availabilityNotifierProvider.notifier)
                              .goOnline();
                        } else {
                          final err = ref.read(skillsNotifierProvider).error;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                err?.toString() ??
                                    'Failed to save skills. Please try again.',
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDE7356),
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
                        selected.isEmpty ? 'Select at least one skill' : 'Save & Go Online',
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFDE7356)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFDE7356)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                cat.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 2. Ongoing Job Card ──────────────────────────────────────────────────────

class _OngoingJobCard extends StatelessWidget {
  final OngoingJobEntity? job;
  const _OngoingJobCard({this.job});

  @override
  Widget build(BuildContext context) {
    if (job == null) {
      return _sectionCard(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.work_outline_rounded,
                  color: Color(0xFF94A3B8), size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No active job right now',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Once you accept or get assigned a job, it will appear here',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final statusColor = _statusColor(job!.status);

    return GestureDetector(
      onTap: () => context.push('/worker/job/${job!.id}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFDE7356),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDE7356).withOpacity(0.30),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Ongoing Job',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    job!.displayStatus,
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
              job!.title ?? job!.categoryName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.construction_rounded,
                    size: 13, color: Colors.white54),
                const SizedBox(width: 4),
                Text(
                  job!.categoryName,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.location_on_rounded,
                    size: 13, color: Colors.white54),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    job!.clientArea,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/worker/job/${job!.id}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFDE7356),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'View Full Job',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
        return const Color(0xFF64B5F6);
      case 'EN_ROUTE':
        return const Color(0xFFFFD54F);
      case 'IN_PROGRESS':
        return const Color(0xFF81C784);
      default:
        return Colors.white70;
    }
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── 3. Skills Section ────────────────────────────────────────────────────────

class _SkillsSection extends ConsumerWidget {
  final List<WorkerSkillEntity> skills;
  const _SkillsSection({required this.skills});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
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
                'Your Skills',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showSkillsSheet(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDE7356).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    skills.isEmpty ? '+ Add Skills' : 'Edit Skills',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDE7356),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (skills.isEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.build_circle_outlined,
                    color: Color(0xFF94A3B8),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No skills added yet',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        'Add skills to start receiving jobs',
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills.map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: Text(
                    skill.categoryName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 4. Stats Section ─────────────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  final WorkerProfileEntity profile;
  const _StatsSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Completed',
            value: '${profile.stats.completedJobs}',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFFDE7356),
            bg: const Color(0xFFE8F5E9),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Rating',
            value: profile.rating > 0 ? profile.rating.toStringAsFixed(1) : '—',
            icon: Icons.star_rounded,
            color: const Color(0xFFF59E0B),
            bg: const Color(0xFFFFFBEB),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Active',
            value: '${profile.stats.activeJobs}',
            icon: Icons.bolt_rounded,
            color: const Color(0xFFDE7356),
            bg: const Color(0xFFFFF0EB),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

// ── 5. Reviews Section ───────────────────────────────────────────────────────

class _ReviewsSection extends ConsumerWidget {
  final WorkerProfileEntity profile;
  const _ReviewsSection({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(workerRecentReviewsProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────
          Row(
            children: [
              const Text(
                'Reviews',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const Spacer(),
              if (profile.totalRatings > 0)
                GestureDetector(
                  onTap: () => context.push('/worker/reviews'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDE7356).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'See all →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDE7356),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // ── Summary ─────────────────────────────────────────────────
          if (profile.totalRatings > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 4),
                Text(
                  '${profile.rating.toStringAsFixed(1)}  ·  ${profile.totalRatings} ${profile.totalRatings == 1 ? 'review' : 'reviews'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // ── Recent reviews ───────────────────────────────────────────
          reviewsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (reviews) => reviews.isEmpty
                ? _ReviewEmptyState(hasRatings: profile.totalRatings > 0)
                : Column(
                    children: reviews
                        .map((r) => _ReviewCard(review: r))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReviewEmptyState extends StatelessWidget {
  final bool hasRatings;
  const _ReviewEmptyState({required this.hasRatings});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.star_outline_rounded,
            color: Color(0xFF94A3B8),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No reviews yet',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              Text(
                'Reviews from clients will appear here',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final WorkerReviewEntity review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stars + category + date ──────────────────────────────────
          Row(
            children: [
              _StarRow(rating: review.rating),
              const Spacer(),
              Text(
                DateFormat('MMM d, yyyy').format(review.createdAt),
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),

          // ── Comment ──────────────────────────────────────────────────
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.comment!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 8),

          // ── Footer: client name + category ───────────────────────────
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDE7356).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  review.serviceCategory,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDE7356),
                  ),
                ),
              ),
              if (review.clientName != null &&
                  review.clientName!.isNotEmpty) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.person_outline_rounded,
                  size: 11,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    review.clientName!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
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
    );
  }
}

class _StarRow extends StatelessWidget {
  final int rating;
  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 14,
          color: i < rating
              ? const Color(0xFFF59E0B)
              : const Color(0xFFD1D5DB),
        );
      }),
    );
  }
}

// ── 6. Info Card ─────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final AvailabilityStatus status;
  final bool hasSkills;
  const _InfoCard({required this.status, required this.hasSkills});

  @override
  Widget build(BuildContext context) {
    final message = !hasSkills
        ? 'Add more skills to get more job opportunities'
        : status == AvailabilityStatus.offline
            ? 'Stay online to receive nearby work from clients'
            : 'Great! Clients near you can now find and book you';

    final icon = !hasSkills
        ? Icons.lightbulb_outline_rounded
        : status == AvailabilityStatus.offline
            ? Icons.info_outline_rounded
            : Icons.tips_and_updates_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF16A34A), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF15803D),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error Card ───────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Failed to load dashboard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDE7356),
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
