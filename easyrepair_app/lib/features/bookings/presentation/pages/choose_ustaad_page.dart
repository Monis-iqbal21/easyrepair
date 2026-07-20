import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/nearby_worker_entity.dart';
import '../providers/booking_providers.dart';
import '../widgets/client_chat_action.dart';

// ── Palette (matches post_job_page.dart / Handygo design system) ─────────────
const _kGreen = Color(0xFFDB6234);
const _kRed = Color(0xFFDC2626);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);
const _kBorder = Color(0xFFE2E8F0);
const _kSurface = Color(0xFFF9FAFB);

/// Worker-selection page for STANDARD and INSPECTION lane bookings (fixed
/// price/fee — no bidding). Shown right after a booking is confirmed for
/// those two lanes; the known-problem/BIDDING lane keeps using
/// WorkerDiscoveryMapPage instead.
class ChooseUstaadPage extends ConsumerStatefulWidget {
  final BookingEntity booking;

  const ChooseUstaadPage({super.key, required this.booking});

  @override
  ConsumerState<ChooseUstaadPage> createState() => _ChooseUstaadPageState();
}

class _ChooseUstaadPageState extends ConsumerState<ChooseUstaadPage> {
  bool _assigning = false;

  Future<void> _confirmAndSelectWorker(NearbyWorkerEntity worker) async {
    if (_assigning) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Hire this Ustaad?',
          style: TextStyle(fontWeight: FontWeight.w700, color: _kDark),
        ),
        content: Text(
          'Hire ${worker.fullName} for this job? You won\'t be able to '
          'choose another Ustaad while they are assigned.',
          style: const TextStyle(color: _kGray, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _kGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hire'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _selectWorker(worker);
  }

  Future<void> _selectWorker(NearbyWorkerEntity worker) async {
    if (_assigning) return;
    setState(() => _assigning = true);
    try {
      await ref
          .read(assignWorkerNotifierProvider.notifier)
          .assign(widget.booking.id, worker.id);
      // Booking is no longer eligible for worker selection — stop the
      // controlled STANDARD-lane recheck loop right away rather than
      // waiting for the page to dispose.
      if (widget.booking.lane == BookingLane.standard) {
        ref
            .read(
              standardNearbyWorkersNotifierProvider(widget.booking.id).notifier,
            )
            .stop();
      }
      if (!mounted) return;
      context.pushReplacement('/client/booking/${widget.booking.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _assigning = false);
      final isConflict = e is ConflictFailure;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isConflict
                ? e.message
                : 'Unable to assign this Ustaad. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _kRed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      if (isConflict) {
        // Worker became unavailable between list fetch and hire tap — refresh
        // so the now-busy worker drops out of the list (backend already
        // filters currentlyWorking=false, so a fresh fetch excludes them).
        await _refreshSearch();
      }
    }
  }

  Future<void> _refreshSearch() async {
    if (widget.booking.lane == BookingLane.standard) {
      await _refreshStandardSearch();
    } else {
      await ref
          .read(nearbyWorkersNotifierProvider(widget.booking.id).notifier)
          .refresh();
    }
  }

  Future<void> _chatWithWorker(NearbyWorkerEntity worker) async {
    await openClientChatForBooking(context, ref, widget.booking.id);
  }

  Future<void> _refreshStandardSearch() async {
    await ref
        .read(standardNearbyWorkersNotifierProvider(widget.booking.id).notifier)
        .refresh();
  }

  void _openProfileModal(NearbyWorkerEntity worker) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Center(
            child: Container(
              width: size.width * 0.9,
              height: size.height * 0.8,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: _WorkerProfileModalContent(
                worker: worker,
                onClose: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final bool isStandard = booking.lane == BookingLane.standard;
    // STANDARD lane uses the capped 5km->7km controlled-polling notifier;
    // INSPECTION keeps the existing wide-ladder notifier unchanged.
    final nearbyState = isStandard
        ? ref.watch(standardNearbyWorkersNotifierProvider(booking.id))
        : ref.watch(nearbyWorkersNotifierProvider(booking.id));
    final double? standardTotal = isStandard ? booking.standardServicesTotal : null;

    final String? priceLabel = isStandard
        ? (standardTotal != null
              ? 'Service Total ${formatPkr(standardTotal)}'
              : null)
        : (booking.inspectionFeeSnapshot != null
              ? 'Inspection fee ${formatPkr(booking.inspectionFeeSnapshot)}'
              : null);

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _kDark,
        title: const Text(
          'Choose Ustaad',
          style: TextStyle(fontWeight: FontWeight.w700, color: _kDark),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
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
                if (priceLabel != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _kGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      priceLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kGreen,
                      ),
                    ),
                  ),
                ],
                if (isStandard &&
                    standardTotal != null &&
                    booking.standardServiceItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in booking.standardServiceItems)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.quantity > 1
                                        ? '${item.nameSnapshot} x${item.quantity}'
                                        : item.nameSnapshot,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _kGray,
                                    ),
                                  ),
                                ),
                                Text(
                                  formatPkr(item.lineTotal),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _kDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Divider(height: 1, color: _kBorder),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _kDark,
                              ),
                            ),
                            Text(
                              formatPkr(standardTotal),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _kGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: _buildBody(nearbyState, isStandard)),
        ],
      ),
    );
  }

  Widget _buildBody(NearbyWorkersState state, bool isStandard) {
    // First load in flight, nothing to show yet at all — skeleton cards
    // instead of a spinner or (worse) a scary error-looking empty state.
    if (state.isExpanding && state.workers.isEmpty && !state.hasError) {
      return Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              'Finding verified Ustaads near you…',
              style: TextStyle(fontSize: 13.5, color: _kGray, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, _) => const _WorkerCardSkeleton(),
            ),
          ),
        ],
      );
    }

    if (state.hasError && state.workers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 32,
                color: Color(0xFFCBD5E1),
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load available Ustaads right now.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _kGray),
              ),
              const SizedBox(height: 16),
              _RefreshButton(onTap: _refreshSearch),
            ],
          ),
        ),
      );
    }

    if (state.workers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_search_rounded,
                size: 32,
                color: Color(0xFFCBD5E1),
              ),
              const SizedBox(height: 12),
              const Text(
                'No verified Ustaad available right now.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _kDark, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                isStandard
                    ? 'List har 45 seconds mein khud-ba-khud refresh hoti hai. '
                        'Aap bhi refresh kar sakte hain ya thora wait karein.'
                    : 'You can refresh or wait a little — checking available Ustaads…',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
              ),
              const SizedBox(height: 16),
              _RefreshButton(onTap: _refreshSearch),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: state.workers.length + (state.isExpanding ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= state.workers.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final worker = state.workers[index];
        return _WorkerCard(
          key: ValueKey(worker.id),
          worker: worker,
          busy: _assigning,
          onAvatarTap: () => _openProfileModal(worker),
          onSelect: () => _confirmAndSelectWorker(worker),
          onChat: () => _chatWithWorker(worker),
        );
      },
    );
  }
}

class _RefreshButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RefreshButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _kGreen,
        side: const BorderSide(color: _kGreen),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: const Text(
        'Refresh',
        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Shimmer-like pulsing placeholder card shown in place of a [_WorkerCard]
/// while the first nearby-workers fetch is in flight. Matches _WorkerCard's
/// size/shape (28px avatar, 18px rounded card) so the list doesn't jump when
/// real cards swap in.
class _WorkerCardSkeleton extends StatefulWidget {
  const _WorkerCardSkeleton();

  @override
  State<_WorkerCardSkeleton> createState() => _WorkerCardSkeletonState();
}

class _WorkerCardSkeletonState extends State<_WorkerCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bone({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.5, end: 1.0).animate(_controller),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(radius: 28, backgroundColor: Color(0xFFE5E7EB)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bone(width: 120, height: 14),
                  const SizedBox(height: 8),
                  _bone(width: 80, height: 11),
                  const SizedBox(height: 10),
                  _bone(width: double.infinity, height: 34),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  final NearbyWorkerEntity worker;
  final bool busy;
  final VoidCallback onAvatarTap;
  final VoidCallback onSelect;
  final VoidCallback onChat;

  const _WorkerCard({
    super.key,
    required this.worker,
    required this.busy,
    required this.onAvatarTap,
    required this.onSelect,
    required this.onChat,
  });

  Widget _statChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _kGray),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 11.5, color: _kGray)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onAvatarTap,
                child: _WorkerAvatar(worker: worker, radius: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            worker.fullName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _kDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _LevelBadge(label: worker.levelBadge),
                      ],
                    ),
                    if (worker.recommended) ...[
                      const SizedBox(height: 4),
                      const _RecommendedBadge(),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _statChip(
                          Icons.star_rounded,
                          worker.rating > 0
                              ? worker.rating.toStringAsFixed(1)
                              : 'New',
                        ),
                        _statChip(
                          Icons.task_alt_rounded,
                          '${worker.completedJobs} jobs',
                        ),
                        _statChip(
                          Icons.reviews_rounded,
                          '${worker.reviewsCount} reviews',
                        ),
                        _statChip(
                          Icons.cancel_outlined,
                          '${worker.cancellationRate}% cancel',
                        ),
                        _statChip(
                          Icons.location_on_rounded,
                          worker.distanceLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: busy ? null : onChat,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: _kGreen,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : onSelect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    disabledBackgroundColor: _kGreen.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Select',
                          style: TextStyle(fontWeight: FontWeight.w700),
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

class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.thumb_up_alt_rounded, size: 11, color: Color(0xFFEA580C)),
          SizedBox(width: 4),
          Text(
            'Recommended',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFEA580C),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final String label;

  const _LevelBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: _kGreen,
        ),
      ),
    );
  }
}

class _WorkerAvatar extends StatelessWidget {
  final NearbyWorkerEntity worker;
  final double radius;

  const _WorkerAvatar({required this.worker, required this.radius});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = worker.avatarUrl;
    final hasImage = avatarUrl != null && avatarUrl.isNotEmpty;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kGreen.withValues(alpha: 0.12),
        image: hasImage
            ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasImage
          ? null
          : Text(
              worker.initials,
              style: TextStyle(
                fontSize: radius * 0.55,
                fontWeight: FontWeight.w700,
                color: _kGreen,
              ),
            ),
    );
  }
}

class _WorkerProfileModalContent extends StatelessWidget {
  final NearbyWorkerEntity worker;
  final VoidCallback onClose;

  const _WorkerProfileModalContent({
    required this.worker,
    required this.onClose,
  });

  Widget _statBlock(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _kDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: _kGray)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: _kGray),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _WorkerAvatar(worker: worker, radius: 48),
                const SizedBox(height: 14),
                Text(
                  worker.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                _LevelBadge(label: worker.levelBadge),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    _statBlock(
                      worker.rating > 0 ? worker.rating.toStringAsFixed(1) : '—',
                      'Rating',
                    ),
                    _statBlock('${worker.completedJobs}', 'Jobs done'),
                    _statBlock('${worker.reviewsCount}', 'Reviews'),
                    _statBlock('${worker.cancellationRate}%', 'Cancel rate'),
                  ],
                ),
                if (worker.skills.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Skills',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: worker.skills
                        .map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _kSurface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _kBorder),
                            ),
                            child: Text(
                              s,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _kDark,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
