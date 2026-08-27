import 'package:flutter/material.dart';

import '../../domain/entities/booking_entity.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';

/// Urgent / Normal pill.
///
/// `urgent` is the palette's attention accent and deliberately not `error` —
/// an urgent job is not a failed one.
class UrgencyBadge extends StatelessWidget {
  final BookingUrgency urgency;
  final bool small;

  const UrgencyBadge({super.key, required this.urgency, this.small = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final isUrgent = urgency == BookingUrgency.urgent;
    final foreground = isUrgent ? colors.urgent : colors.textSecondary;
    final background = isUrgent ? colors.urgentSoft : colors.surfaceSubtle;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUrgent ? Icons.bolt_rounded : Icons.event_available_rounded,
            size: small ? 12 : 14,
            color: foreground,
          ),
          const SizedBox(width: 4),
          Text(
            isUrgent ? context.l10n.postJobUrgent : context.l10n.postJobNormal,
            style: TextStyle(
              fontSize: small ? 11 : 12.5,
              fontWeight: FontWeight.w700,
              color: foreground,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
