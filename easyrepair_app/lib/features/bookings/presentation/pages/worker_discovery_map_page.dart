import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../bids/domain/entities/bid_entity.dart';
import '../../../bids/domain/repositories/bid_repository.dart';
import '../../../bids/presentation/providers/bid_providers.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../../chat/presentation/providers/chat_providers.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kGreen  = Color(0xFF0D7A5F);
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
                  snippet: widget.booking.address ?? widget.booking.city,
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
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _kDark),
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
            builder: (ctx, scrollCtrl) => _BidsSheet(
              booking: widget.booking,
              scrollController: scrollCtrl,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Draggable sheet ────────────────────────────────────────────────────────────

class _BidsSheet extends ConsumerWidget {
  final BookingEntity booking;
  final ScrollController scrollController;

  const _BidsSheet({required this.booking, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bidsAsync = ref.watch(bookingBidsProvider(booking.id));

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
                        'Worker Bids',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _SheetSubtitle(bidsAsync: bidsAsync),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: _kLight),
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(bookingBidsProvider(booking.id)),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: _kBorder),

          // Content
          Expanded(
            child: bidsAsync.when(
              loading: () => _LoadingState(),
              error: (err, _) => _ErrorState(
                message: err is Failure ? err.message : 'Could not load bids.',
                onRetry: () => ref.invalidate(bookingBidsProvider(booking.id)),
              ),
              data: (bids) {
                final pending = bids
                    .where((b) => b.bid.status == BidStatus.pending)
                    .toList()
                  ..sort((a, b) => a.bid.amount.compareTo(b.bid.amount));

                if (pending.isEmpty) return const _EmptyState();

                return ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: pending.length,
                  separatorBuilder: (context2, i2) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _BidOfferCard(
                    bidWorker: pending[i],
                    bookingId: booking.id,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sheet subtitle ────────────────────────────────────────────────────────────

class _SheetSubtitle extends StatelessWidget {
  final AsyncValue<List<BidWithWorkerEntity>> bidsAsync;
  const _SheetSubtitle({required this.bidsAsync});

  @override
  Widget build(BuildContext context) {
    final text = bidsAsync.when(
      loading: () => 'Loading bids...',
      error: (e, st) => 'Could not load bids',
      data: (bids) {
        final count = bids.where((b) => b.bid.status == BidStatus.pending).length;
        if (count == 0) return 'No bids yet';
        return '$count pending ${count == 1 ? 'bid' : 'bids'} · sorted by price';
      },
    );
    return Text(text, style: const TextStyle(fontSize: 12, color: _kLight));
  }
}

// ── Bid offer card ─────────────────────────────────────────────────────────────

class _BidOfferCard extends ConsumerWidget {
  final BidWithWorkerEntity bidWorker;
  final String bookingId;

  const _BidOfferCard({required this.bidWorker, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHiring = ref.watch(acceptBidProvider).isLoading;

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
          // ── Top row: avatar + info + bid amount ────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _BidAvatar(bidWorker: bidWorker),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bidWorker.fullName,
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
                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text(
                          bidWorker.ratingLabel,
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
              // Bid amount badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kGreen.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PKR ${bidWorker.bid.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kGreen,
                      ),
                    ),
                    const Text(
                      'bid',
                      style: TextStyle(fontSize: 10, color: _kGreen),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Distance ───────────────────────────────────────────────────────
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.near_me_rounded, size: 12, color: _kLight),
              const SizedBox(width: 4),
              Text(
                bidWorker.distanceLabel,
                style: const TextStyle(fontSize: 11.5, color: _kLight),
              ),
            ],
          ),

          // ── Skills ─────────────────────────────────────────────────────────
          if (bidWorker.skills.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              bidWorker.skills.take(3).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: _kLight),
            ),
          ],

          // ── Worker message ─────────────────────────────────────────────────
          if (bidWorker.bid.message != null &&
              bidWorker.bid.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: Text(
                bidWorker.bid.message!,
                style: const TextStyle(fontSize: 12.5, color: _kGray, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Action buttons ─────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _ChatButton(workerProfileId: bidWorker.workerProfileId),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: isHiring
                      ? null
                      : () => _confirmHire(context, ref),
                  icon: isHiring
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: Text(isHiring ? 'Hiring…' : 'Hire'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGreen,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
        ],
      ),
    );
  }

  Future<void> _confirmHire(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hire ${bidWorker.firstName}?',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _kDark,
          ),
        ),
        content: Text(
          'Accept ${bidWorker.fullName}\'s bid of PKR ${bidWorker.bid.amount.toStringAsFixed(0)}?',
          style: const TextStyle(fontSize: 13, color: _kGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: _kGray)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _kGreen),
            child: const Text('Hire'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      await ref.read(acceptBidProvider.notifier).accept(
            bidId: bidWorker.bid.id,
            bookingId: bookingId,
          );
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${bidWorker.firstName} has been hired!'),
            backgroundColor: _kGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is Failure ? e.message : 'Failed to hire worker.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _BidAvatar extends StatelessWidget {
  final BidWithWorkerEntity bidWorker;
  const _BidAvatar({required this.bidWorker});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
      child: bidWorker.avatarUrl != null
          ? ClipOval(
              child: Image.network(
                bidWorker.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _InitialsLabel(bidWorker.initials),
              ),
            )
          : _InitialsLabel(bidWorker.initials),
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

class _ChatButton extends ConsumerStatefulWidget {
  final String workerProfileId;
  const _ChatButton({required this.workerProfileId});

  @override
  ConsumerState<_ChatButton> createState() => _ChatButtonState();
}

class _ChatButtonState extends ConsumerState<_ChatButton> {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── States ────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
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
              height: 120,
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
                color: _kGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.gavel_rounded, size: 28, color: _kGreen),
            ),
            const SizedBox(height: 14),
            const Text(
              'No bids yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Workers who apply will appear here.\nCheck back shortly.',
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
                backgroundColor: _kGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
