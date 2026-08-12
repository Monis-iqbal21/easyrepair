import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_utils.dart';
import '../../../bids/domain/entities/bid_entity.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../../bids/domain/repositories/bid_repository.dart';
import '../../../bids/presentation/providers/bid_providers.dart';
import '../../domain/entities/new_job_entity.dart';
import '../providers/worker_job_providers.dart';
import '../widgets/onboarding_gate.dart';
import '../widgets/worker_chat_action.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../bookings/presentation/utils/status_labels.dart';
import '../../../bookings/presentation/utils/worker_labels.dart';
import '../../../../core/errors/failure_messages.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kGreen  = Color(0xFFDB6234);
const _kDark   = Color(0xFF1A1A1A);
const _kGray   = Color(0xFF6B7280);
const _kLight  = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);
const _kBg     = Color(0xFFF9FAFB);
const _kRed    = Color(0xFFEF4444);

// ── Provider: look up job from cached new-jobs list by id ────────────────────
final _newJobByIdProvider =
    Provider.family<NewJobEntity?, String>((ref, jobId) {
  final jobs = ref.watch(newJobsProvider).valueOrNull;
  if (jobs == null) return null;
  try {
    return jobs.firstWhere((j) => j.id == jobId);
  } catch (_) {
    return null;
  }
});

class WorkerBidPage extends ConsumerStatefulWidget {
  final String jobId;
  final String jobTitle;

  const WorkerBidPage({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  @override
  ConsumerState<WorkerBidPage> createState() => _WorkerBidPageState();
}

class _WorkerBidPageState extends ConsumerState<WorkerBidPage> {
  final _amountCtrl  = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _kRed : _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _submit() async {
    // Re-entry guard: a second tap that raced past the disabled button
    // (isSubmitting only updates on the next rebuild) must never fire a
    // duplicate bid submission.
    if (ref.read(submitBidProvider).isLoading) return;
    if (!ensureApprovedOrWarn(context, ref)) return;
    // Resolved before the await below so no message crosses an async gap.
    final l10n = context.l10n;
    final amtStr = _amountCtrl.text.trim();
    if (amtStr.isEmpty) {
      _showSnack(l10n.bidAmountRequired, error: true);
      return;
    }
    final amount = double.tryParse(amtStr);
    if (amount == null || amount < 100) {
      _showSnack(l10n.bidAmountRange, error: true);
      return;
    }
    if (amount > 500000) {
      _showSnack(l10n.bidAmountRange, error: true);
      return;
    }

    debugPrint('[WorkerBidPage] submitting bid jobId=${widget.jobId} amount=$amount');
    try {
      await ref.read(submitBidProvider.notifier).submit(
            bookingId: widget.jobId,
            amount: amount,
          );
      _showSnack(l10n.bidSubmitted);
      // Refresh own-bid, live feed, and new-jobs list (bid count changes).
      ref.invalidate(myBidProvider(widget.jobId));
      ref.invalidate(jobBidsFeedProvider(widget.jobId));
      ref.invalidate(newJobsProvider);
    } catch (e) {
      _showSnack(failureMessage(l10n, e, fallback: l10n.bidSubmitFailed), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myBidAsync   = ref.watch(myBidProvider(widget.jobId));
    final feedAsync    = ref.watch(jobBidsFeedProvider(widget.jobId));
    final isSubmitting = ref.watch(submitBidProvider).isLoading;
    final job          = ref.watch(_newJobByIdProvider(widget.jobId));

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => context.canPop() ? context.pop() : context.go('/worker/home'),
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
        title: Text(
          context.l10n.bidPlaceABid,
          style: TextStyle(
            color: _kDark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Job title + status ───────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.work_outline_rounded, size: 18, color: _kGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.jobTitle.isNotEmpty
                        ? widget.jobTitle
                        : context.l10n.workerBidJobFallbackTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kDark,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (job != null) ...[
                  const SizedBox(width: 8),
                  _StatusBadge(
                    label: newJobStatusLabel(
                      context.l10n,
                      job.status,
                      hasAssignedWorker: job.hasAssignedWorker,
                    ),
                    // Derived from the raw status, never from the label —
                    // matching translated text would drop the "live" styling
                    // in every language but English.
                    isLive: job.status == BookingStatus.pending &&
                        !job.hasAssignedWorker,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Chat with client (available before submitting a bid) ─────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  openWorkerChatForBooking(context, ref, widget.jobId),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: Text(context.l10n.bidChatWithClient),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kGreen,
                side: const BorderSide(color: _kGreen),
                padding: const EdgeInsets.symmetric(vertical: 12),
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

          const SizedBox(height: 12),

          // ── Job location map preview ──────────────────────────────────────
          if (job != null)
            _JobLocationCard(job: job),

          if (job != null) const SizedBox(height: 12),

          // ── My current bid (if any) ───────────────────────────────────────
          myBidAsync.when(
            loading: () => const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2)),
            ),
            error: (e, s) => const SizedBox.shrink(),
            data: (bid) => bid != null ? _CurrentBidCard(bid: bid) : const SizedBox.shrink(),
          ),

          if (myBidAsync.value != null) const SizedBox(height: 16),

          // ── Bid form ──────────────────────────────────────────────────────
          _BidForm(
            amountCtrl: _amountCtrl,
            isSubmitting: isSubmitting,
            existingBid: myBidAsync.valueOrNull,
            onSubmit: _submit,
          ),

          const SizedBox(height: 24),

          // ── Live bids feed ────────────────────────────────────────────────
          Row(
            children: [
              Text(
                context.l10n.bidLiveBids,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kDark,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => ref.invalidate(jobBidsFeedProvider(widget.jobId)),
                child: const Icon(Icons.refresh_rounded, size: 16, color: _kLight),
              ),
            ],
          ),
          const SizedBox(height: 10),

          feedAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
              ),
            ),
            error: (e, _) => _FeedError(
              message: failureMessage(context.l10n, e, fallback: context.l10n.discoveryBidsLoadFailedShort),
              onRetry: () => ref.invalidate(jobBidsFeedProvider(widget.jobId)),
            ),
            data: (bids) => bids.isEmpty
                ? const _FeedEmpty()
                : Column(
                    children: bids
                        .map((b) => _BidFeedTile(bidWithWorker: b))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool isLive;
  const _StatusBadge({required this.label, required this.isLive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isLive
            ? _kGreen.withValues(alpha: 0.12)
            : _kLight.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsetsDirectional.only(end: 4),
              decoration: const BoxDecoration(
                color: _kGreen,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isLive ? _kGreen : _kGray,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Job location card (map preview + address) ─────────────────────────────────

class _JobLocationCard extends StatelessWidget {
  final NewJobEntity job;
  const _JobLocationCard({required this.job});

  @override
  Widget build(BuildContext context) {
    // Privacy: the backend never sends exact address/lat/lng for a job the
    // worker hasn't been hired for yet (see WorkersService._toJobDto /
    // BidsService.getNewJobsForWorker) — latitude/longitude default to 0 and
    // addressLine to '' when absent, so this naturally degrades to the
    // approximate area + distance view below without a map or exact pin.
    final hasCoords = job.latitude != 0 || job.longitude != 0;
    final position  = LatLng(job.latitude, job.longitude);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map (only when coordinates are valid — i.e. never before hire)
          if (hasCoords)
            SizedBox(
              height: 190,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: position,
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('job'),
                    position: position,
                  ),
                },
                // Disable interactions so it doesn't fight the scroll view
                zoomGesturesEnabled: false,
                scrollGesturesEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                liteModeEnabled: true,
              ),
            ),

          // Approximate area + distance row (pre-hire) / address row (hired)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_rounded, size: 16, color: _kGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.addressLine?.isNotEmpty == true
                            ? '${job.addressLine}, ${job.city}'
                            : (job.city.isNotEmpty ? job.city : context.l10n.bidAreaNotAvailable),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: _kGray,
                          height: 1.4,
                        ),
                      ),
                      if (!hasCoords && job.distanceKm != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          workerDistanceLabel(context.l10n, job.distanceKm).isNotEmpty
                              ? workerDistanceLabel(context.l10n, job.distanceKm)
                              : '',
                          style: const TextStyle(fontSize: 11.5, color: _kLight),
                        ),
                      ],
                      if (!hasCoords) ...[
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.bidExactAddressAfterAccept,
                          style: TextStyle(fontSize: 11, color: _kLight, height: 1.3),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Current bid summary card ──────────────────────────────────────────────────

class _CurrentBidCard extends StatelessWidget {
  final BidEntity bid;
  const _CurrentBidCard({required this.bid});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (bid.status) {
      BidStatus.accepted => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      BidStatus.rejected => (const Color(0xFFFEF2F2), _kRed),
      _                  => (const Color(0xFFFFF7ED), const Color(0xFFD97706)),
    };

    final statusLabel = switch (bid.status) {
      BidStatus.accepted => context.l10n.bidStatusAccepted,
      BidStatus.rejected => context.l10n.bidStatusRejected,
      _                  => context.l10n.bidStatusPending,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.bidYourCurrentBid,
                  style: TextStyle(fontSize: 11, color: _kLight),
                ),
                const SizedBox(height: 2),
                Text(
                  formatPkr(bid.amount),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _kGreen,
                  ),
                ),
                if (bid.message != null && bid.message!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    bid.message!,
                    style: const TextStyle(fontSize: 12, color: _kGray),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
            child: Text(
              statusLabel,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bid form ──────────────────────────────────────────────────────────────────

class _BidForm extends StatefulWidget {
  final TextEditingController amountCtrl;
  final bool isSubmitting;
  final BidEntity? existingBid;
  final VoidCallback onSubmit;

  const _BidForm({
    required this.amountCtrl,
    required this.isSubmitting,
    required this.existingBid,
    required this.onSubmit,
  });

  @override
  State<_BidForm> createState() => _BidFormState();
}

class _BidFormState extends State<_BidForm> {
  Timer? _ticker;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.existingBid?.cooldownRemainingSeconds ?? 0;
    _startTicker();
  }

  @override
  void didUpdateWidget(covariant _BidForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A fresh bid lookup (e.g. after resubmitting) carries a new
    // server-authoritative remaining value — resync and restart the local
    // tick-down from it rather than trusting the device clock on its own.
    final fresh = widget.existingBid?.cooldownRemainingSeconds ?? 0;
    if (fresh != (oldWidget.existingBid?.cooldownRemainingSeconds ?? 0)) {
      _remaining = fresh;
      _startTicker();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    if (_remaining <= 0) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining = _remaining > 0 ? _remaining - 1 : 0);
      if (_remaining <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasExisting = widget.existingBid != null;
    final onCooldown = hasExisting && _remaining > 0;
    final label = hasExisting ? context.l10n.bidUpdate : context.l10n.bidSubmit;

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
            hasExisting ? context.l10n.bidUpdateYourBid : context.l10n.bidPlaceYourBid,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kDark,
            ),
          ),
          if (hasExisting) ...[
            const SizedBox(height: 4),
            Text(
              onCooldown
                  ? context.l10n.bidCanUpdateIn('$_remaining')
                  : context.l10n.bidCanUpdateNow,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: onCooldown ? FontWeight.w600 : FontWeight.normal,
                color: onCooldown ? const Color(0xFFB45309) : _kLight,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _FormField(
            label: context.l10n.bidAmountLabel,
            child: TextField(
              controller: widget.amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration: _inputDec(hint: context.l10n.bidAmountHint),
              style: const TextStyle(fontSize: 15, color: _kDark),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed:
                  (widget.isSubmitting || onCooldown) ? null : widget.onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                disabledBackgroundColor: _kGreen.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: widget.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      onCooldown ? context.l10n.bidLabelWithCountdown(label, '$_remaining') : label,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec({required String hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kLight, fontSize: 13),
        filled: true,
        fillColor: _kBg,
        counterText: '',
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
          borderSide: const BorderSide(color: _kGreen, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: _kGray, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ── Live bid feed tile ────────────────────────────────────────────────────────

class _BidFeedTile extends StatelessWidget {
  final BidWithWorkerEntity bidWithWorker;
  const _BidFeedTile({required this.bidWithWorker});

  @override
  Widget build(BuildContext context) {
    final bid    = bidWithWorker.bid;
    final worker = bidWithWorker;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: _kGreen.withValues(alpha: 0.12),
            backgroundImage: worker.avatarUrl != null
                ? NetworkImage(worker.avatarUrl!)
                : null,
            child: worker.avatarUrl == null
                ? Text(
                    worker.initials,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kGreen,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        worker.fullName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatPkr(bid.amount),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 2),
                    Text(
                      worker.rating > 0
                          ? worker.rating.toStringAsFixed(1)
                          : context.l10n.chooseNewBadge,
                      style: const TextStyle(fontSize: 11, color: _kGray),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.bidJobCount(worker.completedJobs),
                      style: const TextStyle(fontSize: 11, color: _kLight),
                    ),
                    const Spacer(),
                    Text(
                      _relativeTime(context, bid.updatedAt),
                      style: const TextStyle(fontSize: 10.5, color: _kLight),
                    ),
                  ],
                ),
                if (bid.message != null && bid.message!.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    bid.message!,
                    style: const TextStyle(fontSize: 12, color: _kGray, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(BuildContext context, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return context.l10n.timeJustNow;
    if (diff.inMinutes < 60) return context.l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24)   return context.l10n.timeHoursAgo(diff.inHours);
    return DateFormat('MMM d').format(dt);
  }
}

// ── Feed empty / error states ─────────────────────────────────────────────────

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Center(
        child: Text(
          context.l10n.bidBeFirstToBid,
          style: TextStyle(fontSize: 13, color: _kLight),
        ),
      ),
    );
  }
}

class _FeedError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _FeedError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: _kGray),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              context.l10n.commonRetry,
              style: TextStyle(
                fontSize: 12,
                color: _kGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
