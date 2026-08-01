import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../domain/entities/booking_entity.dart';
import '../utils/status_labels.dart';

class StatusBadge extends StatelessWidget {
  final BookingStatus status;
  final bool small;

  const StatusBadge({super.key, required this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    final config = _config(status);
    final fontSize = small ? 10.0 : 11.0;
    final hPad = small ? 7.0 : 9.0;
    final vPad = small ? 3.0 : 4.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: config.dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            bookingStatusLabel(context.l10n, status),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: config.text,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _config(BookingStatus status) {
    return switch (status.tab) {
      BookingTab.live => const _BadgeConfig(
          bg: Color(0xFFFFF0EB),
          text: Color(0xFFCC4A0D),
          dot: Color(0xFFDB6234),
        ),
      BookingTab.assigned => const _BadgeConfig(
          bg: Color(0xFFF1F5F9),
          text: Color(0xFF374151),
          dot: Color(0xFF6B7280),
        ),
      BookingTab.completed => const _BadgeConfig(
          bg: Color(0xFFF1F5F9),
          text: Color(0xFF374151),
          dot: Color(0xFF6B7280),
        ),
      BookingTab.cancelled => const _BadgeConfig(
          bg: Color(0xFFFFF1F2),
          text: Color(0xFFBE123C),
          dot: Color(0xFFE11D48),
        ),
      BookingTab.all => const _BadgeConfig(
          bg: Color(0xFFF1F5F9),
          text: Color(0xFF6B7280),
          dot: Color(0xFF94A3B8),
        ),
    };
  }
}

class _BadgeConfig {
  final Color bg;
  final Color text;
  final Color dot;
  const _BadgeConfig({required this.bg, required this.text, required this.dot});
}
