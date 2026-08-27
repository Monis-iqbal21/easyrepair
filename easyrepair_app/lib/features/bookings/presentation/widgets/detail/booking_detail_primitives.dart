import 'package:flutter/material.dart';

import '../../../../../core/theme/app_semantic_colors.dart';

/// Shared building blocks for the Client Booking Detail page.
///
/// Every colour here comes from [AppSemanticColors], so the page reads
/// correctly in light and dark without a single widget branching on
/// brightness. Cards are `surface` + radius 16 + a 1px `border` hairline and
/// carry no shadow — depth inside a screen is expressed with the surface
/// hierarchy, never with elevation.

/// The one card shell every Booking Detail section sits in.
class BookingDetailCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Uses `surfaceSubtle` instead of `surface` — for a section that should
  /// recede behind the cards around it (e.g. a passive state banner).
  final bool subtle;

  const BookingDetailCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: subtle ? colors.surfaceSubtle : colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

/// Section title inside a [BookingDetailCard].
class BookingSectionHeading extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? trailing;

  const BookingSectionHeading({
    super.key,
    required this.label,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: colors.textSecondary),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
              letterSpacing: 0.1,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Label-above-value row. Wraps rather than overflows on narrow screens, and
/// never drops below the 12.5px floor these users can read outdoors.
class BookingDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const BookingDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: colors.textSecondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A money line: caption on the left, amount on the right. The amount shrinks
/// to fit rather than pushing the row into an overflow at 320px.
class BookingAmountRow extends StatelessWidget {
  final String label;
  final String amount;
  final bool emphasised;

  const BookingAmountRow({
    super.key,
    required this.label,
    required this.amount,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: emphasised ? 14.5 : 13.5,
              height: 1.3,
              color: emphasised ? colors.textPrimary : colors.textSecondary,
              fontWeight: emphasised ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              amount,
              maxLines: 1,
              style: TextStyle(
                fontSize: emphasised ? 17 : 14,
                color: colors.textPrimary,
                fontWeight: emphasised ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Semantic weight of an inline banner. Each tone maps onto palette tokens so
/// no banner ever hardcodes a colour.
enum BookingBannerTone { info, positive, attention, critical }

/// Compact one- or two-line strip used for passive state messages (report
/// status, worker cancelled, expired, inspection progress).
class BookingStateBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final BookingBannerTone tone;
  final Widget? action;

  const BookingStateBanner({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.tone = BookingBannerTone.info,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final (foreground, background) = switch (tone) {
      BookingBannerTone.info => (colors.primary, colors.softTeal),
      BookingBannerTone.positive => (colors.success, colors.successSoft),
      BookingBannerTone.attention => (colors.warning, colors.warningSurface),
      BookingBannerTone.critical => (colors.error, colors.errorSoft),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                        height: 1.3,
                      ),
                    ),
                    if (body != null && body!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        body!,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

/// Filled 52px primary action. Falls back to a spinner while [loading].
class BookingPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  /// Renders on `error` instead of `primary` — for destructive actions.
  final bool destructive;

  const BookingPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: destructive ? colors.error : colors.primary,
          foregroundColor: colors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        icon: loading
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.onPrimary,
                ),
              )
            : Icon(icon ?? Icons.arrow_forward_rounded, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Outlined 52px secondary action.
class BookingSecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool destructive;

  const BookingSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final foreground = destructive ? colors.error : colors.primary;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          side: BorderSide(color: destructive ? colors.error : colors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        icon: loading
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : Icon(icon ?? Icons.arrow_forward_rounded, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
