import 'package:flutter/material.dart';
import '../theme/app_semantic_colors.dart';

/// The numeric pill. Sized from its own text and capped at "9+", so a busy
/// inbox can never widen the tab it sits on.
class NavigationCountBadge extends StatelessWidget {
  final int count;
  const NavigationCountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      constraints: const BoxConstraints(minWidth: 17),
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // `urgent` is the attention accent, the same one the Home notification
        // bell already uses for its count. The `surface` ring keeps the pill
        // legible where it overlaps the icon beneath it.
        color: c.urgent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.surface, width: 1.5),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: TextStyle(
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w700,
          color: c.onPrimary,
        ),
      ),
    );
  }
}
