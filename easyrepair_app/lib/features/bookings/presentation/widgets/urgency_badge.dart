import 'package:flutter/material.dart';

import '../../domain/entities/booking_entity.dart';
import '../../../../core/l10n/l10n_extensions.dart';

class UrgencyBadge extends StatelessWidget {
  final BookingUrgency urgency;
  final bool small;

  const UrgencyBadge({super.key, required this.urgency, this.small = false});

  @override
  Widget build(BuildContext context) {
    final isUrgent = urgency == BookingUrgency.urgent;
    final fontSize = small ? 10.0 : 11.0;
    final hPad = small ? 7.0 : 9.0;
    final vPad = small ? 3.0 : 4.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: isUrgent ? const Color(0xFFFFF1F2) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUrgent
              ? const Color(0xFFFECACA)
              : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isUrgent ? '⚡' : '🗓',
            style: TextStyle(fontSize: small ? 9.0 : 10.0),
          ),
          const SizedBox(width: 3),
          Text(
            isUrgent ? context.l10n.postJobUrgent : context.l10n.postJobNormal,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: isUrgent
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF6B7280),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
