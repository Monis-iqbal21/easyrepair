import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n_extensions.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../domain/entities/booking_entity.dart';
import '../media_attachment_widgets.dart';
import 'booking_detail_primitives.dart';

/// What the client attached when they posted the job — photos, video and the
/// voice note. Reuses the existing media components untouched, so viewing,
/// playback and their loading/error states behave exactly as before.
///
/// Renders nothing when there is nothing attached: a STANDARD catalog booking
/// usually has no media, and an empty "Attachments" card is pure clutter.
class BookingAttachmentsSection extends StatelessWidget {
  final List<BookingAttachmentEntity> attachments;

  const BookingAttachmentsSection({super.key, required this.attachments});

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final images = attachments
        .where((a) => a.type == AttachmentType.image)
        .toList();
    final videos = attachments
        .where((a) => a.type == AttachmentType.video)
        .toList();
    final audios = attachments
        .where((a) => a.type == AttachmentType.audio)
        .toList();

    return BookingDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingSectionHeading(
            label: l10n.bookingAttachments,
            icon: Icons.attach_file_rounded,
          ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 14),
            _GroupLabel(
              icon: Icons.image_outlined,
              label: l10n.bookingPhotosCount(images.length),
            ),
            const SizedBox(height: 10),
            BookingImageGrid(images: images),
          ],
          if (videos.isNotEmpty) ...[
            const SizedBox(height: 14),
            _GroupLabel(
              icon: Icons.videocam_outlined,
              label: l10n.bookingVideosCount(videos.length),
            ),
            const SizedBox(height: 8),
            for (final video in videos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: BookingVideoTile(attachment: video),
              ),
          ],
          if (audios.isNotEmpty) ...[
            const SizedBox(height: 14),
            _GroupLabel(
              icon: Icons.mic_none_rounded,
              label: l10n.bookingVoiceNote,
            ),
            const SizedBox(height: 8),
            for (final audio in audios)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: BookingAudioPlayerCard(attachment: audio),
              ),
          ],
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _GroupLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Row(
      children: [
        Icon(icon, size: 15, color: colors.textSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
