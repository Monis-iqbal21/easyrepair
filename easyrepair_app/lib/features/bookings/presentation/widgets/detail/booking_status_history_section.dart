import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/l10n/l10n_extensions.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../domain/entities/booking_entity.dart';
import '../../utils/status_labels.dart';
import 'booking_detail_primitives.dart';

/// Backend-recorded status history for the Client Booking Detail page.
class BookingStatusHistorySection extends StatelessWidget {
  final List<BookingStatusHistoryEntry> history;

  const BookingStatusHistorySection({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return BookingDetailCard(
      key: const Key('client-status-history-section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingSectionHeading(
            label: context.l10n.workerStatusHistory,
            icon: Icons.history_rounded,
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < history.length; index++)
            _StatusHistoryRow(
              entry: history[index],
              isLast: index == history.length - 1,
              colors: colors,
            ),
        ],
      ),
    );
  }
}

class _StatusHistoryRow extends StatelessWidget {
  final BookingStatusHistoryEntry entry;
  final bool isLast;
  final AppSemanticColors colors;

  const _StatusHistoryRow({
    required this.entry,
    required this.isLast,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
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
                color: isLast ? colors.primary : colors.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast) Container(width: 1, height: 28, color: colors.border),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workerJobStatusLabel(context.l10n, entry.status),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isLast ? colors.primary : colors.textPrimary,
                  ),
                ),
                if (entry.note?.trim().isNotEmpty ?? false)
                  Text(
                    entry.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.textSecondary,
                    ),
                  ),
                Text(
                  DateFormat('d MMM, h:mm a').format(entry.createdAt),
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
