import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failures.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../../bookings/presentation/widgets/media_attachment_widgets.dart';
import '../../../bids/domain/entities/bid_entity.dart';
import '../../../bids/presentation/providers/bid_providers.dart';
import '../providers/worker_job_providers.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kGreen  = Color(0xFF0D7A5F);
const _kDark   = Color(0xFF1A1A1A);
const _kGray   = Color(0xFF6B7280);
const _kLight  = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);
const _kBg     = Color(0xFFF9FAFB);
const _kRed    = Color(0xFFEF4444);

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
        loading: () => const Center(child: CircularProgressIndicator(
          color: _kGreen,
        )),
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
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(Icons.arrow_back_rounded, color: _kDark, size: 20),
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
    final isPending = job.status == BookingStatus.pending;
    final canComplete = job.status.isWorkerActive;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusCard(job: job),
                const SizedBox(height: 16),

                // ── Client info ──────────────────────────────────────────
                if (job.clientName != null && job.clientName!.isNotEmpty) ...[
                  _Section(
                    title: 'Client',
                    child: _InfoRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Posted by',
                      value: job.clientName!,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

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
                      if (job.description != null && job.description!.isNotEmpty)
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
                if (job.estimatedPrice != null || job.finalPrice != null) ...[
                  _Section(
                    title: 'Pricing',
                    child: Column(
                      children: [
                        if (job.estimatedPrice != null)
                          _InfoRow(
                            icon: Icons.attach_money_rounded,
                            label: 'Estimated',
                            value: 'PKR ${job.estimatedPrice!.toStringAsFixed(0)}',
                          ),
                        if (job.finalPrice != null)
                          _InfoRow(
                            icon: Icons.payments_outlined,
                            label: 'Final Price',
                            value: 'PKR ${job.finalPrice!.toStringAsFixed(0)}',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

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
                  _ReviewSection(review: job.review!, clientName: job.clientName),
                  const SizedBox(height: 16),
                ],

                // ── Bid section (PENDING jobs only) ───────────────────────
                if (isPending) ...[
                  _BidSection(jobId: job.id),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),

        // ── Complete button (sticky bottom) ──────────────────────────────
        if (canComplete) _CompleteJobBar(jobId: job.id),
      ],
    );
  }

  String _fmtDateTime(DateTime dt) =>
      DateFormat('d MMM yyyy, h:mm a').format(dt);
}

// ── Bid section ───────────────────────────────────────────────────────────────

class _BidSection extends ConsumerWidget {
  final String jobId;
  const _BidSection({required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bidAsync = ref.watch(myBidProvider(jobId));

    return bidAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2)),
      ),
      error: (e, st) => const SizedBox.shrink(),
      data: (bid) => _BidCard(jobId: jobId, bid: bid),
    );
  }
}

class _BidCard extends ConsumerStatefulWidget {
  final String jobId;
  final BidEntity? bid;
  const _BidCard({required this.jobId, required this.bid});

  @override
  ConsumerState<_BidCard> createState() => _BidCardState();
}

class _BidCardState extends ConsumerState<_BidCard> {
  final _amountCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.bid != null) {
      _amountCtrl.text = widget.bid!.amount.toStringAsFixed(0);
      _messageCtrl.text = widget.bid!.message ?? '';
    }
  }

  @override
  void didUpdateWidget(_BidCard old) {
    super.didUpdateWidget(old);
    // Sync fields when bid changes after submit/edit.
    if (widget.bid != null && old.bid?.id != widget.bid?.id) {
      _amountCtrl.text = widget.bid!.amount.toStringAsFixed(0);
      _messageCtrl.text = widget.bid!.message ?? '';
      _isEditing = false;
    }
  }

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

    try {
      await ref.read(submitBidProvider.notifier).submit(
            bookingId: widget.jobId,
            amount: amount,
            message: _messageCtrl.text.trim().isEmpty
                ? null
                : _messageCtrl.text.trim(),
          );
      _showSnack('Bid submitted successfully!');
    } catch (e) {
      _showSnack(e is Failure ? e.message : 'Failed to submit bid.', error: true);
    }
  }

  Future<void> _edit() async {
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

    try {
      await ref.read(editBidProvider.notifier).edit(
            bidId: widget.bid!.id,
            bookingId: widget.jobId,
            amount: amount,
            message: _messageCtrl.text.trim().isEmpty
                ? null
                : _messageCtrl.text.trim(),
          );
      setState(() => _isEditing = false);
      _showSnack('Bid updated successfully!');
    } catch (e) {
      _showSnack(e is Failure ? e.message : 'Failed to update bid.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bid = widget.bid;
    final isSubmitting = ref.watch(submitBidProvider).isLoading;
    final isEditing = ref.watch(editBidProvider).isLoading;
    final isBusy = isSubmitting || isEditing;

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.gavel_rounded, size: 16, color: _kGreen),
              ),
              const SizedBox(width: 10),
              const Text(
                'Your Bid',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kDark,
                ),
              ),
              if (bid != null) ...[
                const Spacer(),
                _BidStatusChip(status: bid.status),
              ],
            ],
          ),

          // ── Existing bid display (not editing) ────────────────────────
          if (bid != null && !_isEditing) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bid Amount',
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
                    ],
                  ),
                ),
                if (bid.editCount >= 1)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Icon(Icons.lock_outline_rounded, size: 15, color: _kLight),
                      SizedBox(height: 2),
                      Text(
                        'Edit used',
                        style: TextStyle(fontSize: 11, color: _kLight),
                      ),
                    ],
                  ),
              ],
            ),
            if (bid.message != null && bid.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Message',
                style: TextStyle(fontSize: 11, color: _kLight),
              ),
              const SizedBox(height: 2),
              Text(
                bid.message!,
                style: const TextStyle(fontSize: 13, color: _kGray, height: 1.4),
              ),
            ],
            if (bid.canEdit) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _isEditing = true),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Edit Bid'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kGreen,
                    side: const BorderSide(color: _kGreen),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF856404)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'You have already used your one allowed edit. No further changes are permitted.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF856404), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          // ── Form (submit new or edit existing) ────────────────────────
          if (bid == null || _isEditing) ...[
            const SizedBox(height: 14),
            _FormField(
              label: 'Bid Amount (PKR) *',
              child: TextField(
                controller: _amountCtrl,
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
                controller: _messageCtrl,
                maxLines: 3,
                maxLength: 300,
                decoration: _inputDec(hint: 'Describe your approach or any relevant details...'),
                style: const TextStyle(fontSize: 14, color: _kDark),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_isEditing) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isBusy
                          ? null
                          : () => setState(() {
                                _amountCtrl.text =
                                    bid!.amount.toStringAsFixed(0);
                                _messageCtrl.text = bid.message ?? '';
                                _isEditing = false;
                              }),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kGray,
                        side: const BorderSide(color: _kBorder),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: _isEditing ? 2 : 1,
                  child: ElevatedButton(
                    onPressed: isBusy ? null : (bid == null ? _submit : _edit),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kGreen,
                      disabledBackgroundColor: _kGreen.withValues(alpha: 0.5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            bid == null ? 'Submit Bid' : 'Save Changes',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ],
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

class _BidStatusChip extends StatelessWidget {
  final BidStatus status;
  const _BidStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      BidStatus.accepted => (const Color(0xFFDCFCE7), const Color(0xFF15803D), 'Accepted'),
      BidStatus.rejected => (const Color(0xFFFEF2F2), _kRed, 'Rejected'),
      BidStatus.pending  => (const Color(0xFFFFF7ED), const Color(0xFFD97706), 'Pending'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
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
              color: _kGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(job.serviceEmoji, style: const TextStyle(fontSize: 24)),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
        (const Color(0xFFFEF2F2), _kRed),
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
                Text(label, style: const TextStyle(fontSize: 11, color: _kLight)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: _kDark,
                    height: 1.4,
                  ),
                  maxLines: multiline ? null : 2,
                  overflow: multiline ? null : TextOverflow.ellipsis,
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
    final images = attachments.where((a) => a.type == AttachmentType.image).toList();
    final videos = attachments.where((a) => a.type == AttachmentType.video).toList();
    final audios = attachments.where((a) => a.type == AttachmentType.audio).toList();

    return _Section(
      title: 'Attachments',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty) ...[
            const Text('Photos', style: TextStyle(fontSize: 12, color: _kLight)),
            const SizedBox(height: 10),
            BookingImageGrid(images: images),
          ],
          if (videos.isNotEmpty) ...[
            if (images.isNotEmpty) const SizedBox(height: 14),
            const Text('Videos', style: TextStyle(fontSize: 12, color: _kLight)),
            const SizedBox(height: 8),
            ...videos.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BookingVideoTile(attachment: v),
                )),
          ],
          if (audios.isNotEmpty) ...[
            if (images.isNotEmpty || videos.isNotEmpty) const SizedBox(height: 14),
            const Text('Voice Notes', style: TextStyle(fontSize: 12, color: _kLight)),
            const SizedBox(height: 8),
            ...audios.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BookingAudioPlayerCard(attachment: a),
                )),
          ],
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
                      Container(width: 1, height: 28, color: _kBorder),
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
                            style: const TextStyle(fontSize: 11.5, color: _kGray),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          DateFormat('d MMM, h:mm a').format(entry.createdAt),
                          style: const TextStyle(fontSize: 11, color: _kLight),
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
                            ...List.generate(5, (i) {
                              final r = review!.rating;
                              return Icon(
                                i < r
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 12,
                                color: i < r
                                    ? const Color(0xFFF59E0B)
                                    : _kBorder,
                              );
                            }),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle_outline_rounded, size: 18),
          label: Text(isLoading ? 'Completing...' : 'Mark as Completed'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
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
            child: const Text('Cancel', style: TextStyle(color: _kLight)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          Row(
            children: [
              ...List.generate(5, (i) => Icon(
                i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
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
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF374151), height: 1.5),
            ),
          ],
          if (clientName != null && clientName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 13, color: _kLight),
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
            const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: _kGray, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
