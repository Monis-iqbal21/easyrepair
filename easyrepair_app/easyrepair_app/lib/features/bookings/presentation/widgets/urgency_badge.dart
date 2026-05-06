import 'package:flutter/material.dart';

import '../../domain/entities/booking_entity.dart';

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
        color: isUrgent ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUrgent
              ? const Color(0xFFFED7AA)
              : const Color(0xFFBBF7D0),
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
            isUrgent ? 'Urgent' : 'Normal',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: isUrgent
                  ? const Color(0xFFC2410C)
                  : const Color(0xFF15803D),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
