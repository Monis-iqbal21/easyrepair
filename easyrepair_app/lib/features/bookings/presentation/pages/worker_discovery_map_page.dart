import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/nearby_worker_entity.dart';
import '../providers/booking_providers.dart';
import '../../../../features/chat/presentation/providers/chat_providers.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBrand  = Color(0xFFDE7356);
const _kDark   = Color(0xFF1A1A1A);
const _kGray   = Color(0xFF6B7280);
const _kLight  = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);

// ── Page ─────────────────────────────────────────────────────────────────────

class WorkerDiscoveryMapPage extends ConsumerStatefulWidget {
  final BookingEntity booking;
  const WorkerDiscoveryMapPage({super.key, required this.booking});

  @override
  ConsumerState<WorkerDiscoveryMapPage> createState() =>
      _WorkerDiscoveryMapPageState();
}

class _WorkerDiscoveryMapPageState
    extends ConsumerState<WorkerDiscoveryMapPage> {
  GoogleMapController? _mapCtrl;

  @override
  void dispose() {
    _mapCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobLat = widget.booking.latitude;
    final jobLng = widget.booking.longitude;
    final jobPos = LatLng(jobLat, jobLng);

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen map ────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(target: jobPos, zoom: 13.5),
            onMapCreated: (c) => _mapCtrl = c,
            markers: {
              Marker(
                markerId: const MarkerId('job'),
                position: jobPos,
                infoWindow: InfoWindow(
                  title: 'Job Location',
                  snippet: widget.booking.address ??
                      widget.booking.city,
                ),
              ),
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ── Back button ────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: _kDark),
                  ),
                ),
              ),
            ),
          ),

          // ── Draggable bottom sheet ─────────────────────────────────────────
          DraggableScrollableSheet(
            initialChildSize: 0.22,
            minChildSize: 0.22,
            maxChildSize: 1.0,
            snap: true,
            snapSizes: const [0.22, 0.55, 1.0],
            builder: (ctx, scrollCtrl) => _WorkerSheet(
              bookingId: widget.booking.id,
              scrollController: scrollCtrl,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Draggable sheet container ─────────────────────────────────────────────────

class _WorkerSheet extends ConsumerWidget {
  final String bookingId;
  final ScrollController scrollController;

  const _WorkerSheet({
    required this.bookingId,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nearbyWorkersNotifierProvider(bookingId));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available Workers',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _SheetSubtitle(state: state),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      size: 18, color: _kLight),
                  tooltip: 'Refresh',
                  onPressed: () =>
                      ref.invalidate(nearbyWorkersNotifierProvider(bookingId)),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: _kBorder),

          // Content
          Expanded(
            child: _SheetBody(
              state: state,
              bookingId: bookingId,
              scrollController: scrollController,
              onRetry: () =>
                  ref.invalidate(nearbyWorkersNotifierProvider(bookingId)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sheet subtitle ────────────────────────────────────────────────────────────

class _SheetSubtitle extends StatelessWidget {
  final NearbyWorkersState state;
  const _SheetSubtitle({required this.state});

  @override
  Widget build(BuildContext context) {
    final String text;
    if (state.hasError && state.workers.isEmpty) {
      text = 'Could not load workers';
    } else if (state.workers.isEmpty && state.isExpanding) {
      text = 'Searching nearby workers...';
    } else if (state.workers.isNotEmpty && state.isExpanding) {
      text = '${state.workers.length} found · expanding search...';
    } else if (state.workers.isEmpty) {
      text = 'No workers found within 20 km';
    } else {
      final r = state.searchedRadiusKm.toStringAsFixed(0);
      text = '${state.workers.length} available · within $r km';
    }
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: _kLight),
    );
  }
}

// ── Sheet body ────────────────────────────────────────────────────────────────

class _SheetBody extends StatelessWidget {
  final NearbyWorkersState state;
  final String bookingId;
  final ScrollController scrollController;
  final VoidCallback onRetry;

  const _SheetBody({
    required this.state,
    required this.bookingId,
    required this.scrollController,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (state.hasError && state.workers.isEmpty) {
      return _ErrorState(
        message: state.error is Failure
            ? (state.error as Failure).message
            : 'Could not load workers.',
        onRetry: onRetry,
      );
    }
    if (state.workers.isEmpty && state.isExpanding) {
      return const _LoadingState();
    }
    if (state.workers.isEmpty) {
      return const _EmptyState();
    }

    final itemCount = state.workers.length + (state.isExpanding ? 1 : 0);

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        if (i == state.workers.length) {
          return const _SearchingMoreBanner();
        }
        return _WorkerOfferCard(
          worker: state.workers[i],
          bookingId: bookingId,
        );
      },
    );
  }
}

// ── Worker offer card ─────────────────────────────────────────────────────────

class _WorkerOfferCard extends ConsumerWidget {
  final NearbyWorkerEntity worker;
  final String bookingId;

  const _WorkerOfferCard({
    required this.worker,
    required this.bookingId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAssigning = ref.watch(assignWorkerNotifierProvider).isLoading;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          // ── Top row: avatar + info + distance ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _DiscoveryAvatar(worker: worker),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.fullName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 13, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text(
                          worker.ratingLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _kGray,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Distance badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.near_me_rounded,
                        size: 10, color: _kBrand),
                    const SizedBox(width: 3),
                    Text(
                      worker.distanceLabel,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: _kBrand,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Skills ─────────────────────────────────────────────────────────
          if (worker.skills.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              worker.skills.take(3).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: _kLight),
            ),
          ],

          const SizedBox(height: 12),

          // ── Action buttons ─────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _DiscoveryChatButton(workerProfileId: worker.id),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed:
                      isAssigning ? null : () => _confirmHire(context, ref),
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
                          size: 16,
                        ),
                  label: Text(isAssigning ? 'Hiring…' : 'Hire'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kBrand,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmHire(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hire ${worker.firstName}?',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _kDark,
          ),
        ),
        content: Text(
          'Assign ${worker.fullName} to this job?',
          style: const TextStyle(fontSize: 13, color: _kGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: _kGray)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _kBrand),
            child: const Text('Hire'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      await ref
          .read(assignWorkerNotifierProvider.notifier)
          .assign(bookingId, worker.id);
      if (context.mounted) {
        Navigator.of(context).pop(); // close the map page
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${worker.firstName} has been assigned to your job.'),
            backgroundColor: _kBrand,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(e is Failure ? e.message : 'Failed to hire worker.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _DiscoveryAvatar extends StatelessWidget {
  final NearbyWorkerEntity worker;
  const _DiscoveryAvatar({required this.worker});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        color: _kBrand,
        shape: BoxShape.circle,
      ),
      child: worker.avatarUrl != null
          ? ClipOval(
              child: Image.network(
                worker.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _InitialsLabel(worker.initials),
              ),
            )
          : _InitialsLabel(worker.initials),
    );
  }
}

class _InitialsLabel extends StatelessWidget {
  final String initials;
  const _InitialsLabel(this.initials);

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

// ── Chat button ───────────────────────────────────────────────────────────────

class _DiscoveryChatButton extends ConsumerStatefulWidget {
  final String workerProfileId;
  const _DiscoveryChatButton({required this.workerProfileId});

  @override
  ConsumerState<_DiscoveryChatButton> createState() =>
      _DiscoveryChatButtonState();
}

class _DiscoveryChatButtonState
    extends ConsumerState<_DiscoveryChatButton> {
  bool _loading = false;

  Future<void> _openChat() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final conversation = await ref
          .read(getOrCreateConversationProvider.notifier)
          .getOrCreate(widget.workerProfileId);
      if (mounted) {
        context.push('/client/chat/${conversation.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : _openChat,
      icon: _loading
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(_kGray),
              ),
            )
          : const Icon(Icons.chat_bubble_outline_rounded, size: 15),
      label: const Text('Chat'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _kGray,
        side: const BorderSide(color: _kBorder),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Supplementary states ──────────────────────────────────────────────────────

class _SearchingMoreBanner extends StatelessWidget {
  const _SearchingMoreBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        children: List.generate(
          2,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 110,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0EB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person_search_rounded,
                  size: 28, color: _kBrand),
            ),
            const SizedBox(height: 14),
            const Text(
              'No workers found nearby',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'We searched up to 20 km.\nTry again in a few minutes as more workers come online.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _kLight, height: 1.5),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: _kGray),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: _kBrand,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
