import 'package:flutter/material.dart';

import '../../../../core/presentation/responsive_utils.dart';

class ServiceCard extends StatelessWidget {
  final String title;
  final String emoji;
  final Color backgroundColor;
  final Color emojiBackgroundColor;
  final VoidCallback? onTap;
  final bool isSelected;
  final String? imagePath;

  const ServiceCard({
    super.key,
    required this.title,
    required this.emoji,
    required this.backgroundColor,
    required this.emojiBackgroundColor,
    this.onTap,
    this.isSelected = false,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: imagePath != null ? Colors.white : backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: const Color(0xFF1D9E75), width: 2)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1D9E75).withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        // When an image is provided the card uses a different layout:
        // image fills the top portion and the label sits below.
        child: imagePath != null
            ? _ImageLayout(
                imagePath: imagePath!,
                title: title,
                backgroundColor: backgroundColor,
                isSelected: isSelected,
              )
            : _EmojiLayout(
                emoji: emoji,
                title: title,
                emojiBackgroundColor: emojiBackgroundColor,
                isSelected: isSelected,
              ),
      ),
    );
  }
}

// ── Image-based card layout ───────────────────────────────────────────────────

class _ImageLayout extends StatelessWidget {
  final String imagePath;
  final String title;
  final Color backgroundColor;
  final bool isSelected;

  const _ImageLayout({
    required this.imagePath,
    required this.title,
    required this.backgroundColor,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Base width ~170 = typical card width in a 2-column grid on 390px screen.
        final titleSize = rFont(w, 15, min: 13, max: 17, baseWidth: 170);
        final subtitleSize = rFont(w, 12, min: 11, max: 13, baseWidth: 170);

        // mainAxisSize.max (default) is required so Expanded can fill
        // the bounded height provided by the GridView cell.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Expanded absorbs whatever height remains after text — this
            // makes overflow structurally impossible regardless of font
            // metrics or text-scale factor.
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: SizedBox.expand(
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      color: backgroundColor,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isSelected ? 'Selected ✓' : 'Book now →',
                    style: TextStyle(
                      fontSize: subtitleSize,
                      color: const Color(0xFF1D9E75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Emoji-based card layout (fallback / used by post_job_page) ────────────────

class _EmojiLayout extends StatelessWidget {
  final String emoji;
  final String title;
  final Color emojiBackgroundColor;
  final bool isSelected;

  const _EmojiLayout({
    required this.emoji,
    required this.title,
    required this.emojiBackgroundColor,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
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
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isSelected ? 'Selected ✓' : 'Book now →',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1D9E75),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
