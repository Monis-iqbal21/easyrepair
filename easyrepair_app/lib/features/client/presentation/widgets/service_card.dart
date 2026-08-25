import 'package:flutter/material.dart';

import '../../../../core/presentation/responsive_utils.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';

/// Only these categories are launch-approved for booking. Any other category
/// (by name) renders as a locked "Coming Soon" tile wherever [ServiceCard] is
/// used — home page and the booking-form category picker alike — without
/// touching the backend or deleting/deactivating anything in the DB.
const Set<String> kLaunchActiveServiceCategories = {
  'AC Technician',
  'Electrician',
  'Plumber',
  'Carpenter',
  'Appliances Repair',
};

class ServiceCard extends StatelessWidget {
  final String title;
  final String emoji;
  final Color backgroundColor;
  final Color emojiBackgroundColor;
  final VoidCallback? onTap;
  final bool isSelected;
  final String? imagePath;

  /// When true the card always renders as an image-tile (homepage style):
  /// image/placeholder rectangle on top, title below, no Book Now button.
  /// When false (booking form selector) it uses the emoji+Book Now layout.
  final bool useImageStyle;

  /// When true, renders a dimmed "Coming Soon" tile and disables tapping
  /// regardless of [onTap].
  final bool locked;

  const ServiceCard({
    super.key,
    required this.title,
    required this.emoji,
    required this.backgroundColor,
    required this.emojiBackgroundColor,
    this.onTap,
    this.isSelected = false,
    this.imagePath,
    this.useImageStyle = false,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final effectiveOnTap = locked ? null : onTap;

    // Homepage / image-tile style: always use _ImageTile (with emoji fallback).
    if (useImageStyle || imagePath != null) {
      return GestureDetector(
        onTap: effectiveOnTap,
        child: _ImageTile(
          imagePath: imagePath,
          emoji: emoji,
          title: title,
          backgroundColor: backgroundColor,
          emojiBackgroundColor: emojiBackgroundColor,
          locked: locked,
        ),
      );
    }

    // Booking form selector style: emoji + Book Now / Selected badge.
    return GestureDetector(
      onTap: effectiveOnTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: colors.primary, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: isSelected ? 0.12 : 0.07),
              blurRadius: isSelected ? 14 : 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _EmojiLayout(
          emoji: emoji,
          title: title,
          emojiBackgroundColor: emojiBackgroundColor,
          isSelected: isSelected,
          locked: locked,
        ),
      ),
    );
  }
}

// ── Image tile card ────────────────────────────────────────────────────────────
// Used on homepage. If imagePath is null shows a colored placeholder with emoji.
// No Book Now, no price, no overflow.

class _ImageTile extends StatelessWidget {
  final String? imagePath;
  final String emoji;
  final String title;
  final Color backgroundColor;
  final Color emojiBackgroundColor;
  final bool locked;

  const _ImageTile({
    required this.imagePath,
    required this.emoji,
    required this.title,
    required this.backgroundColor,
    required this.emojiBackgroundColor,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final w = MediaQuery.sizeOf(context).width;
    final titleSize = rFont(w, 13, min: 11, max: 15);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 1 / 0.55,
            child: Stack(
              fit: StackFit.expand,
              children: [
                imagePath != null
                    ? Image.asset(
                        imagePath!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(),
                      )
                    : _placeholder(),
                if (locked) ...[
                  Container(color: colors.textPrimary.withValues(alpha: 0.45)),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        context.l10n.serviceComingSoon,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            color: locked ? colors.textSecondary : colors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 36)),
    );
  }
}

// ── Emoji-based card layout (booking form service selector only) ───────────────

class _EmojiLayout extends StatelessWidget {
  final String emoji;
  final String title;
  final Color emojiBackgroundColor;
  final bool isSelected;
  final bool locked;

  const _EmojiLayout({
    required this.emoji,
    required this.title,
    required this.emojiBackgroundColor,
    required this.isSelected,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: emojiBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: locked ? colors.textSecondary : colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: locked ? colors.textSecondary : colors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              locked ? context.l10n.serviceComingSoon : (isSelected ? context.l10n.serviceSelectedTick : context.l10n.serviceBookNow),
              style: TextStyle(
                fontSize: 11,
                color: colors.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
