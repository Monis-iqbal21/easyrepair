import 'package:flutter/material.dart';

/// Small pill shown when a booking has `inspection == true` — kept visually
/// consistent with [StatusBadge]/[UrgencyBadge] (same pill shape/sizing).
class InspectionBadge extends StatelessWidget {
  final bool small;

  const InspectionBadge({super.key, this.small = false});

  @override
  Widget build(BuildContext context) {
    final fontSize = small ? 10.0 : 11.0;
    final hPad = small ? 7.0 : 9.0;
    final vPad = small ? 3.0 : 4.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD0B5), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_rounded,
            size: small ? 9.0 : 10.0,
            color: const Color(0xFFDB6234),
          ),
          const SizedBox(width: 3),
          Text(
            'Inspection',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFDB6234),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
