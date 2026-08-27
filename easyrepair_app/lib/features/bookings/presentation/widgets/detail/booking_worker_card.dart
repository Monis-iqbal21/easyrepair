import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/l10n/l10n_extensions.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../domain/entities/booking_entity.dart';
import '../client_chat_action.dart';
import 'booking_detail_primitives.dart';

/// The hired Ustaad, with Call and Chat living inside the card rather than
/// repeated in a separate bottom action bar.
class BookingWorkerCard extends ConsumerStatefulWidget {
  final AssignedWorkerEntity worker;
  final String bookingId;
  final String heading;

  /// Chat is a client↔worker conversation, not a booking-status action, so it
  /// stays available after completion. Hidden only when the caller has no
  /// booking context to authorise it with.
  final bool showChat;

  const BookingWorkerCard({
    super.key,
    required this.worker,
    required this.bookingId,
    required this.heading,
    this.showChat = true,
  });

  @override
  ConsumerState<BookingWorkerCard> createState() => _BookingWorkerCardState();
}

class _BookingWorkerCardState extends ConsumerState<BookingWorkerCard> {
  bool _openingChat = false;

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openChat() async {
    if (_openingChat) return;
    setState(() => _openingChat = true);
    try {
      await openClientChatWithWorker(
        context,
        ref,
        widget.bookingId,
        widget.worker.id,
      );
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final worker = widget.worker;
    final phone = worker.phone;
    final canCall = phone != null && phone.trim().isNotEmpty;

    return BookingDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingSectionHeading(label: widget.heading),
          const SizedBox(height: 14),
          Row(
            children: [
              BookingWorkerAvatar(worker: worker, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (worker.rating != null) ...[
                      const SizedBox(height: 5),
                      BookingWorkerRating(rating: worker.rating!),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (canCall || widget.showChat) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (canCall)
                  Expanded(
                    child: _ContactAction(
                      icon: Icons.call_rounded,
                      label: context.l10n.bookingCallWorker,
                      onTap: () => _call(phone),
                    ),
                  ),
                if (canCall && widget.showChat) const SizedBox(width: 10),
                if (widget.showChat)
                  Expanded(
                    child: _ContactAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: context.l10n.bookingChatWithWorker,
                      loading: _openingChat,
                      onTap: _openChat,
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

/// Compact `Inspection completed by <name>` row, used when the Ustaad who
/// inspected is not the one doing the repair. Deliberately a single row, not
/// a second full worker card — the active repair Ustaad stays the primary
/// identity on the page.
class BookingInspectorRow extends StatelessWidget {
  final AssignedWorkerEntity inspector;
  final String label;

  const BookingInspectorRow({
    super.key,
    required this.inspector,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          BookingWorkerAvatar(worker: inspector, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  inspector.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
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

class BookingWorkerAvatar extends StatelessWidget {
  final AssignedWorkerEntity worker;
  final double size;

  const BookingWorkerAvatar({
    super.key,
    required this.worker,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final hasImage = worker.avatarUrl?.trim().isNotEmpty ?? false;
    final initials = Center(
      child: Text(
        worker.initials,
        style: TextStyle(
          color: colors.onPrimary,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              worker.avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => initials,
            )
          : initials,
    );
  }
}

/// Five stars filled to the worker's average, with the numeric value beside
/// them for anyone who wants the exact figure.
class BookingWorkerRating extends StatelessWidget {
  final double rating;

  const BookingWorkerRating({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Semantics(
      label: '${rating.toStringAsFixed(1)} / 5',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            Icon(
              rating >= i + 1
                  ? Icons.star_rounded
                  : rating > i
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
              size: 16,
              color: rating > i ? colors.warning : colors.border,
            ),
          const SizedBox(width: 6),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool loading;

  const _ContactAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: loading ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.border),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        icon: loading
            ? SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.primary,
                ),
              )
            : Icon(icon, size: 17),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
