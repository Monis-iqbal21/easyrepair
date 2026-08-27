import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../domain/entities/booking_entity.dart';
import '../utils/status_labels.dart';

class StatusBadge extends StatelessWidget {
  final BookingStatus status;
  final bool small;
  final bool detailedClientWording;
  final bool waitingForQuote;

  const StatusBadge({
    super.key,
    required this.status,
    this.small = false,
    this.detailedClientWording = false,
    this.waitingForQuote = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _config(context);
    final fontSize = small ? 10.0 : 11.0;
    final hPad = small ? 7.0 : 9.0;
    final vPad = small ? 3.0 : 4.0;
    final label = detailedClientWording
        ? bookingCardStatusLabel(
            context.l10n,
            status,
            waitingForQuote: waitingForQuote,
            romanUrdu: Localizations.localeOf(context).scriptCode == 'Latn',
          )
        : bookingStatusLabel(context.l10n, status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: config.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: config.foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: config.foreground,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _config(BuildContext context) {
    final colors = context.semanticColors;
    if (waitingForQuote) {
      return _BadgeConfig(colors.warningSurface, colors.warning);
    }
    return switch (status) {
      BookingStatus.pending => _BadgeConfig(colors.softTeal, colors.primary),
      BookingStatus.accepted ||
      BookingStatus.enRoute ||
      BookingStatus.arrived ||
      BookingStatus.inProgress => _BadgeConfig(
        colors.warningSurface,
        colors.warning,
      ),
      BookingStatus.completed ||
      BookingStatus.awaitingConfirmation ||
      BookingStatus.settled => _BadgeConfig(colors.successSoft, colors.success),
      BookingStatus.rejected ||
      BookingStatus.cancelled => _BadgeConfig(colors.errorSoft, colors.error),
      BookingStatus.expired => _BadgeConfig(
        colors.surfaceSubtle,
        colors.textSecondary,
      ),
    };
  }
}

class _BadgeConfig {
  final Color background;
  final Color foreground;

  const _BadgeConfig(this.background, this.foreground);
}
