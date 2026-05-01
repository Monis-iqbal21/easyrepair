import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failures.dart';
import '../../../bids/domain/entities/bid_entity.dart';
import '../../../bids/domain/repositories/bid_repository.dart';
import '../../../bids/presentation/providers/bid_providers.dart';
import '../providers/worker_job_providers.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kGreen  = Color(0xFF1D9E75);
const _kDark   = Color(0xFF1A1A1A);
const _kGray   = Color(0xFF6B7280);
const _kLight  = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);
const _kBg     = Color(0xFFF9FAFB);
const _kRed    = Color(0xFFEF4444);

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
  final _messageCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _messageCtrl.dispose();
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
    final amtStr = _amountCtrl.text.trim();
    if (amtStr.isEmpty) {
      _showSnack('Please enter a bid amount.', error: true);
      return;
    }
    final amount = double.tryParse(amtStr);
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid amount greater than 0.', error: true);
      return;
    }

    debugPrint('[WorkerBidPage] submitting bid jobId=${widget.jobId} amount=$amount');
    try {
      await ref.read(submitBidProvider.notifier).submit(
            bookingId: widget.jobId,
            amount: amount,
            message: _messageCtrl.text.trim().isEmpty
                ? null
                : _messageCtrl.text.trim(),
          );
      _showSnack('Bid submitted!');
      // Refresh own-bid, live feed, and new-jobs list (bid count changes).
      ref.invalidate(myBidProvider(widget.jobId));
      ref.invalidate(jobBidsFeedProvider(widget.jobId));
      ref.invalidate(newJobsProvider);
    } catch (e) {
      _showSnack(e is Failure ? e.message : 'Failed to submit bid.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myBidAsync   = ref.watch(myBidProvider(widget.jobId));
    final feedAsync    = ref.watch(jobBidsFeedProvider(widget.jobId));
    final isSubmitting = ref.watch(submitBidProvider).isLoading;

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
        title: const Text(
          'Place a Bid',
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
          // ── Job title ────────────────────────────────────────────────────
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
                    widget.jobTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kDark,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

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
            messageCtrl: _messageCtrl,
            isSubmitting: isSubmitting,
            existingBid: myBidAsync.valueOrNull,
            onSubmit: _submit,
          ),

          const SizedBox(height: 24),

          // ── Live bids feed ────────────────────────────────────────────────
          Row(
            children: [
              const Text(
                'Live Bids',
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
              message: e is Failure ? e.message : 'Could not load bids',
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
      BidStatus.accepted => 'Accepted',
      BidStatus.rejected => 'Rejected',
      _                  => 'Pending',
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
                const Text(
                  'Your Current Bid',
                  style: TextStyle(fontSize: 11, color: _kLight),
                ),
                const SizedBox(height: 2),
                Text(
                  'PKR ${bid.amount.toStringAsFixed(0)}',
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

class _BidForm extends StatelessWidget {
  final TextEditingController amountCtrl;
  final TextEditingController messageCtrl;
  final bool isSubmitting;
  final BidEntity? existingBid;
  final VoidCallback onSubmit;

  const _BidForm({
    required this.amountCtrl,
    required this.messageCtrl,
    required this.isSubmitting,
    required this.existingBid,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final hasExisting = existingBid != null;
    final label = hasExisting ? 'Update Bid' : 'Submit Bid';

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
            hasExisting ? 'Update Your Bid' : 'Place Your Bid',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kDark,
            ),
          ),
          if (hasExisting) ...[
            const SizedBox(height: 4),
            const Text(
              'You can update your bid after a 1-minute cooldown.',
              style: TextStyle(fontSize: 11.5, color: _kLight),
            ),
          ],
          const SizedBox(height: 14),
          _FormField(
            label: 'Bid Amount (PKR) *',
            child: TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration: _inputDec(hint: 'e.g. 2500'),
              style: const TextStyle(fontSize: 15, color: _kDark),
            ),
          ),
          const SizedBox(height: 12),
          _FormField(
            label: 'Message (optional)',
            child: TextField(
              controller: messageCtrl,
              maxLines: 3,
              maxLength: 300,
              decoration: _inputDec(hint: 'Describe your approach or relevant details...'),
              style: const TextStyle(fontSize: 14, color: _kDark),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                disabledBackgroundColor: _kGreen.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      label,
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
                      'PKR ${bid.amount.toStringAsFixed(0)}',
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
                          : 'New',
                      style: const TextStyle(fontSize: 11, color: _kGray),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${worker.completedJobs} job${worker.completedJobs == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 11, color: _kLight),
                    ),
                    const Spacer(),
                    Text(
                      _relativeTime(bid.updatedAt),
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

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
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
      child: const Center(
        child: Text(
          'Be the first to bid on this job',
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
            child: const Text(
              'Retry',
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
