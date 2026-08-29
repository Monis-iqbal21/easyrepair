import 'package:flutter/material.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';

/// Small pill shown when a booking has `inspection == true` — kept visually
/// consistent with [StatusBadge]/[UrgencyBadge] (same pill shape/sizing).
class InspectionBadge extends StatelessWidget {
  final bool small;

  const InspectionBadge({super.key, this.small = false});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final fontSize = small ? 10.0 : 11.0;
    final hPad = small ? 7.0 : 9.0;
    final vPad = small ? 3.0 : 4.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_rounded,
            size: small ? 9.0 : 10.0,
            color: c.primary,
          ),
          const SizedBox(width: 3),
          Text(
            context.l10n.inspectionBadge,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: c.primary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
