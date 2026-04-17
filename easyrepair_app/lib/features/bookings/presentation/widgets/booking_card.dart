import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/booking_entity.dart';
import 'status_badge.dart';
import 'urgency_badge.dart';

class BookingCard extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback onTap;
  final VoidCallback? onCancel;
  final VoidCallback? onChat;
  final VoidCallback? onEdit;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onTap,
    this.onCancel,
    this.onChat,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent = booking.urgency == BookingUrgency.urgent;
    final isLive = booking.status.tab == BookingTab.live;
    final isAssigned = booking.status.tab == BookingTab.assigned;
    final isCancelled = booking.status.tab == BookingTab.cancelled;
    final isCompleted = booking.status.tab == BookingTab.completed;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isUrgent && isLive
                ? const Color(0xFFFED7AA)
                : const Color(0xFFE2E8F0),
            width: isUrgent && isLive ? 1.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Urgent accent strip ─────────────────────────────────────
            if (isUrgent && isLive)
              Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                  ),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(18)),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top row: icon + info + badges ───────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service icon
                      _ServiceIcon(
                        emoji: booking.serviceEmoji,
                        isUrgent: isUrgent,
                        isCancelled: isCancelled,
                      ),
                      const SizedBox(width: 12),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Service name
                            Text(
                              booking.serviceCategory,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: isCancelled
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF1A1A1A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            // Ref + Date row
                            Row(
                              children: [
                                Text(
                                  booking.referenceId,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFCBD5E1),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatDate(booking.createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Badges column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusBadge(status: booking.status),
                          const SizedBox(height: 4),
                          UrgencyBadge(urgency: booking.urgency, small: true),
                        ],
                      ),
                    ],
                  ),

                  // ── Issue title ─────────────────────────────────────
                  if (booking.title != null && booking.title!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      booking.title!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isCancelled
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF6B7280),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // ── Normal booking: slot info ───────────────────────
                  if (!isUrgent && booking.timeSlot != null) ...[
                    const SizedBox(height: 10),
                    _SlotInfo(
                      booking: booking,
                      isCancelled: isCancelled,
                    ),
                  ],

                  // ── Urgent: notification hint ───────────────────────
                  if (isUrgent && isLive) ...[
                    const SizedBox(height: 10),
                    _UrgentHint(),
                  ],

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),

                  // ── Bottom row: worker / searching + price ──────────
                  Row(
                    children: [
                      Expanded(
                        child: _WorkerSection(
                          booking: booking,
                          isLive: isLive,
                          isAssigned: isAssigned,
                        ),
                      ),
                      if (booking.estimatedPrice != null)
                        _PriceTag(
                          price: booking.estimatedPrice!,
                          isCancelled: isCancelled,
                          isCompleted: isCompleted,
                        ),
                    ],
                  ),

                  // ── Address ─────────────────────────────────────────
                  if (booking.address != null &&
                      booking.address!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: Color(0xFFCBD5E1),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            booking.address!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // ── Quick actions ───────────────────────────────────
                  if (_hasActions) ...[
                    const SizedBox(height: 12),
                    _QuickActions(
                      canCancel: booking.status == BookingStatus.pending &&
                          booking.assignedWorker == null,
                      hasWorker: booking.assignedWorker != null,
                      canEdit: booking.status == BookingStatus.pending &&
                          booking.assignedWorker == null,
                      onCancel: onCancel,
                      onChat: onChat,
                      onEdit: onEdit,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasActions {
    final canCancel = booking.status == BookingStatus.pending &&
        booking.assignedWorker == null;
    return (canCancel && onCancel != null) ||
        (booking.assignedWorker != null && onChat != null) ||
        (booking.status == BookingStatus.pending &&
            booking.assignedWorker == null &&
            onEdit != null);
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) {
      return 'Today, ${DateFormat('h:mm a').format(dt)}';
    }
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day - 1) {
      return 'Yesterday';
    }
    return DateFormat('MMM d, yyyy').format(dt);
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ServiceIcon extends StatelessWidget {
  final String emoji;
  final bool isUrgent;
  final bool isCancelled;

  const _ServiceIcon({
    required this.emoji,
    required this.isUrgent,
    required this.isCancelled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: isCancelled
            ? const Color(0xFFF9FAFB)
            : isUrgent
                ? const Color(0xFFFFF7ED)
                : const Color(0xFFFFF0EB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}

class _SlotInfo extends StatelessWidget {
  final BookingEntity booking;
  final bool isCancelled;

  const _SlotInfo({required this.booking, required this.isCancelled});

  @override
  Widget build(BuildContext context) {
    final slot = booking.timeSlot!;
    final slotEmoji = switch (slot) {
      TimeSlot.morning => '🌅',
      TimeSlot.afternoon => '☀️',
      TimeSlot.evening => '🌆',
      TimeSlot.night => '🌙',
    };

    final dateStr = booking.scheduledDate != null
        ? DateFormat('MMM d').format(booking.scheduledDate!)
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCancelled
            ? const Color(0xFFF9FAFB)
            : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(slotEmoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            [
              slot.label,
              if (dateStr != null) '· $dateStr',
            ].join(' '),
            style: TextStyle(
              fontSize: 11.5,
              color: isCancelled
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF15803D),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Goes live 1h before window',
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgentHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.bolt_rounded, size: 13, color: Color(0xFFEA580C)),
          SizedBox(width: 4),
          Text(
            'Workers are notified immediately',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFFEA580C),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerSection extends StatelessWidget {
  final BookingEntity booking;
  final bool isLive;
  final bool isAssigned;

  const _WorkerSection({
    required this.booking,
    required this.isLive,
    required this.isAssigned,
  });

  @override
  Widget build(BuildContext context) {
    final worker = booking.assignedWorker;

    if (worker != null) {
      return Row(
        children: [
          // Avatar
          _WorkerAvatar(worker: worker),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worker.fullName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (worker.rating != null)
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 11, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 2),
                      Text(
                        worker.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      );
    }

    // No worker yet
    if (isLive) {
      return Row(
        children: [
          // Pulsing searching indicator
          _SearchingDot(),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Searching for workers...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFDE7356),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (booking.availableWorkersCount != null &&
                    booking.availableWorkersCount! > 0)
                  Text(
                    '${booking.availableWorkersCount} workers available nearby',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF6B7280),
                    ),
                  )
                else
                  const Text(
                    'No worker yet',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

class _WorkerAvatar extends StatelessWidget {
  final AssignedWorkerEntity worker;
  const _WorkerAvatar({required this.worker});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFDE7356),
        shape: BoxShape.circle,
      ),
      child: worker.avatarUrl != null
          ? ClipOval(
              child: Image.network(
                worker.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _Initials(worker.initials),
              ),
            )
          : _Initials(worker.initials),
    );
  }
}

class _Initials extends StatelessWidget {
  final String initials;
  const _Initials(this.initials);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SearchingDot extends StatefulWidget {
  @override
  State<_SearchingDot> createState() => _SearchingDotState();
}

class _SearchingDotState extends State<_SearchingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0EB),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFD0B5), width: 1.5),
        ),
        child: const Center(
          child: Icon(
            Icons.search_rounded,
            size: 16,
            color: Color(0xFFDE7356),
          ),
        ),
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final double price;
  final bool isCancelled;
  final bool isCompleted;

  const _PriceTag({
    required this.price,
    required this.isCancelled,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'EGP ${price.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isCancelled
                ? const Color(0xFFCBD5E1)
                : isCompleted
                    ? const Color(0xFF15803D)
                    : const Color(0xFF1A1A1A),
            decoration: isCancelled ? TextDecoration.lineThrough : null,
          ),
        ),
        if (!isCancelled)
          const Text(
            'est.',
            style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
          ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  final bool canCancel;
  final bool hasWorker;
  final bool canEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onChat;
  final VoidCallback? onEdit;

  const _QuickActions({
    required this.canCancel,
    required this.hasWorker,
    required this.canEdit,
    this.onCancel,
    this.onChat,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (hasWorker && onChat != null) ...[
          Expanded(
            child: _ActionBtn(
              label: 'Chat',
              icon: Icons.chat_bubble_outline_rounded,
              color: const Color(0xFFDE7356),
              bgColor: const Color(0xFFFFF0EB),
              onTap: onChat!,
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (canEdit && onEdit != null) ...[
          Expanded(
            child: _ActionBtn(
              label: 'Edit',
              icon: Icons.edit_outlined,
              color: const Color(0xFF1A1A1A),
              bgColor: const Color(0xFFF1F5F9),
              onTap: onEdit!,
            ),
          ),
          if (canCancel && onCancel != null) const SizedBox(width: 8),
        ],
        if (canCancel && onCancel != null)
          Expanded(
            child: _ActionBtn(
              label: 'Cancel',
              icon: Icons.close_rounded,
              color: const Color(0xFFDC2626),
              bgColor: const Color(0xFFFFF1F2),
              onTap: onCancel!,
            ),
          ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
