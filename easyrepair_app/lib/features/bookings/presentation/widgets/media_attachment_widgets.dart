import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../domain/entities/booking_entity.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';

// ═════════════════════════════════════════════════════════════════════════════
// AUDIO PLAYER
// ═════════════════════════════════════════════════════════════════════════════

// Fixed waveform heights used by both the player and recorder waveforms.
const _kWaveHeights = [
  4.0,
  9.0,
  15.0,
  7.0,
  19.0,
  12.0,
  6.0,
  14.0,
  9.0,
  5.0,
  17.0,
  11.0,
  7.0,
  13.0,
  8.0,
  4.0,
  10.0,
  16.0,
  6.0,
  12.0,
];

/// WhatsApp-style voice note player. Accepts a network [url] for existing
/// attachments or a [localPath] for newly recorded files before upload.
class WhatsAppVoiceNotePlayer extends StatefulWidget {
  final String? url;
  final String? localPath;
  final VoidCallback? onDelete;

  /// Length the backend recorded for this note, in seconds.
  ///
  /// The player only learns a duration from `onDurationChanged`, which does
  /// not fire until the source is opened — so before the first tap the label
  /// read "0:00" on a note that was plainly not empty. When the API already
  /// knows the length, seed it here and the label is right on first paint.
  final double? durationSeconds;

  const WhatsAppVoiceNotePlayer({
    super.key,
    this.url,
    this.localPath,
    this.onDelete,
    this.durationSeconds,
  }) : assert(url != null || localPath != null);

  @override
  State<WhatsAppVoiceNotePlayer> createState() =>
      _WhatsAppVoiceNotePlayerState();
}

class _WhatsAppVoiceNotePlayerState extends State<WhatsAppVoiceNotePlayer> {
  final _player = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _duration = _seededDuration(widget.durationSeconds);
    _player.onDurationChanged.listen((d) {
      // The decoded length wins once it is known, but a zero reading — which
      // some sources emit before the header is parsed — must not wipe out the
      // duration the API already gave us.
      if (mounted && d > Duration.zero) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() {
        _isPlaying = s == PlayerState.playing;
        if (s != PlayerState.playing) _isLoading = false;
      });
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _isPlaying = false;
        });
      }
    });
  }

  @override
  void didUpdateWidget(WhatsAppVoiceNotePlayer old) {
    super.didUpdateWidget(old);
    // Only re-seed while nothing has been decoded yet; a live duration read
    // from the source outranks the recorded one.
    if (widget.durationSeconds != old.durationSeconds &&
        _duration == Duration.zero) {
      setState(() => _duration = _seededDuration(widget.durationSeconds));
    }
  }

  static Duration _seededDuration(double? seconds) =>
      (seconds != null && seconds > 0)
      ? Duration(milliseconds: (seconds * 1000).round())
      : Duration.zero;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isLoading || _hasError) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      setState(() => _isLoading = true);
      try {
        if (widget.localPath != null) {
          await _player.play(DeviceFileSource(widget.localPath!));
        } else {
          await _player.play(UrlSource(widget.url!));
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
      }
    }
  }

  Future<void> _seekTo(double frac) async {
    if (_duration == Duration.zero) return;
    final ms = (frac.clamp(0.0, 1.0) * _duration.inMilliseconds).round();
    await _player.seek(Duration(milliseconds: ms));
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final timeLabel = _duration > Duration.zero
        ? (_isPlaying ? _fmt(_position) : _fmt(_duration))
        : '0:00';

    const barCount = 28;
    final filledCount = (progress * barCount).round();
    final c = context.semanticColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          // ── Delete icon (shown when onDelete is provided) ─────────────
          if (widget.onDelete != null) ...[
            GestureDetector(
              onTap: widget.onDelete,
              child: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // ── Play / Pause ─────────────────────────────────────────────────
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.softTeal,
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.primary,
                      ),
                    )
                  : Icon(
                      _hasError
                          ? Icons.error_outline_rounded
                          : _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: c.primary,
                      size: 22,
                    ),
            ),
          ),
          const SizedBox(width: 10),

          // ── Waveform bars — tap to seek ──────────────────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (_, bc) {
                const spacing = 2.0;
                final barW =
                    (bc.maxWidth - (barCount - 1) * spacing) / barCount;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _seekTo(d.localPosition.dx / bc.maxWidth),
                  child: SizedBox(
                    height: 24,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(barCount, (i) {
                        final h = _kWaveHeights[i % _kWaveHeights.length];
                        final filled = i < filledCount;
                        final isHead = filledCount > 0 && i == filledCount;
                        return Container(
                          width: barW,
                          height: isHead ? (h + 4).clamp(0.0, 22.0) : h,
                          margin: i < barCount - 1
                              ? const EdgeInsetsDirectional.only(end: spacing)
                              : null,
                          decoration: BoxDecoration(
                            color: filled ? c.primary : c.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),

          // ── Duration ─────────────────────────────────────────────────────
          Text(
            timeLabel,
            style: TextStyle(
              fontSize: 11,
              color: c.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin wrapper kept for backward compatibility with booking/job detail pages.
class BookingAudioPlayerCard extends StatelessWidget {
  final BookingAttachmentEntity attachment;
  const BookingAudioPlayerCard({super.key, required this.attachment});

  @override
  Widget build(BuildContext context) => WhatsAppVoiceNotePlayer(
    url: attachment.url,
    durationSeconds: attachment.durationSeconds,
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// IMAGE GRID
// ═════════════════════════════════════════════════════════════════════════════

/// 2-column grid of tappable image thumbnails.
/// Tap opens a full-screen interactive viewer with a ✕ close button.
class BookingImageGrid extends StatelessWidget {
  final List<BookingAttachmentEntity> images;
  const BookingImageGrid({super.key, required this.images});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bc) {
        const cols = 2;
        const spacing = 8.0;
        final tileW = (bc.maxWidth - spacing) / cols;
        final tileH = tileW * 0.72; // ~4:3

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: images
              .map((img) => _ImageTile(url: img.url, w: tileW, h: tileH))
              .toList(),
        );
      },
    );
  }
}

/// Opens the shared full-screen image viewer (aspect-fit, pinch zoom/pan,
/// ✕ close button, Android back dismissal) for any image URL — reused by
/// pages that render images outside the [BookingImageGrid] layout, e.g. the
/// inspection report's photo strip.
Future<void> showFullScreenImage(BuildContext context, String url) {
  return showDialog<void>(
    context: context,
    barrierColor: context.semanticColors.scrim,
    builder: (_) => _FullImageDialog(url: url),
  );
}

class _ImageTile extends StatelessWidget {
  final String url;
  final double w;
  final double h;
  const _ImageTile({required this.url, required this.w, required this.h});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return GestureDetector(
      onTap: () => showFullScreenImage(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: w,
          height: h,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: w,
              height: h,
              color: c.surfaceSubtle,
              child: Icon(Icons.broken_image_outlined, color: c.textSecondary),
            ),
            loadingBuilder: (_, child, prog) => prog == null
                ? child
                : Container(
                    width: w,
                    height: h,
                    color: c.surfaceSubtle,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.primary,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// Full-screen image viewer with ✕ button.
class _FullImageDialog extends StatelessWidget {
  final String url;
  const _FullImageDialog({required this.url});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Scaffold(
      backgroundColor: c.scrim,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  Icons.broken_image_outlined,
                  color: c.onScrimMuted,
                  size: 48,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.scrimSurface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: c.onScrim, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// VIDEO TILE
// ═════════════════════════════════════════════════════════════════════════════

/// A dark tile showing the video file name with a play icon.
/// Tap opens a full-screen video player dialog.
class BookingVideoTile extends StatelessWidget {
  final BookingAttachmentEntity attachment;
  const BookingVideoTile({super.key, required this.attachment});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        barrierColor: c.scrim,
        builder: (_) => _VideoPlayerDialog(url: attachment.url),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          // A video poster reads as a dark tile in either theme, so this is
          // scrim chrome rather than a page surface.
          color: c.scrim,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.scrimSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: c.onScrimMuted,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.fileName ?? context.l10n.chatAttachVideo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.onScrim,
                    ),
                  ),
                  Text(
                    context.l10n.mediaTapToPlay,
                    style: TextStyle(fontSize: 11, color: c.onScrimMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.onScrimMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Full-screen video player ──────────────────────────────────────────────────

class _VideoPlayerDialog extends StatefulWidget {
  final String url;
  const _VideoPlayerDialog({required this.url});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late final VideoPlayerController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) {
            if (!mounted) return;
            setState(() => _initialized = true);
            _ctrl.play();
          })
          .catchError((_) {
            if (mounted) setState(() => _initialized = false);
          });
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Scaffold(
      backgroundColor: c.scrim,
      body: Stack(
        children: [
          // ── Video area ─────────────────────────────────────────────────
          Center(
            child: _initialized
                ? GestureDetector(
                    onTap: () =>
                        _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play(),
                    child: AspectRatio(
                      aspectRatio: _ctrl.value.aspectRatio,
                      child: VideoPlayer(_ctrl),
                    ),
                  )
                : CircularProgressIndicator(color: c.onScrim),
          ),

          // ── Bottom controls ────────────────────────────────────────────
          if (_initialized)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _VideoControls(ctrl: _ctrl),
            ),

          // ── Close button ───────────────────────────────────────────────
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.scrimSurface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: c.onScrim, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoControls extends StatelessWidget {
  final VideoPlayerController ctrl;
  const _VideoControls({required this.ctrl});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final pos = ctrl.value.position;
    final total = ctrl.value.duration;
    final progress = total.inMilliseconds > 0
        ? (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      color: c.scrim,
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ctrl.value.isPlaying ? ctrl.pause() : ctrl.play(),
            child: Icon(
              ctrl.value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: c.onScrim,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                // Scrim chrome, not brand: the backdrop is fixed black in
                // both themes, so a theme-varying accent would drop out of
                // contrast in one of them.
                activeTrackColor: c.onScrim,
                inactiveTrackColor: c.scrimSurface,
                thumbColor: c.onScrim,
              ),
              child: Slider(
                value: progress,
                onChanged: total == Duration.zero
                    ? null
                    : (v) {
                        final ms = (v * total.inMilliseconds).round();
                        ctrl.seekTo(Duration(milliseconds: ms));
                      },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_fmt(pos)} / ${_fmt(total)}',
            style: TextStyle(fontSize: 11, color: c.onScrimMuted),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ATTACHMENTS SECTION
// ═════════════════════════════════════════════════════════════════════════════

/// The customer-provided job context — problem photos, videos and voice notes
/// — rendered as one card, grouped by media type.
///
/// Lives here rather than inside a page so every surface that needs to show
/// what the client attached to a job renders it identically: the Ustaad's job
/// detail screen, and the bid screen they reach before ever being hired.
/// Renders nothing at all when there is nothing attached.
class BookingAttachmentsSection extends StatelessWidget {
  final List<BookingAttachmentEntity> attachments;

  const BookingAttachmentsSection({super.key, required this.attachments});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    if (attachments.isEmpty) return const SizedBox.shrink();

    final images = attachments
        .where((a) => a.type == AttachmentType.image)
        .toList();
    final videos = attachments
        .where((a) => a.type == AttachmentType.video)
        .toList();
    final audios = attachments
        .where((a) => a.type == AttachmentType.audio)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.bookingAttachments,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (images.isNotEmpty) ...[
            Text(
              context.l10n.inspectionPhotos,
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
            const SizedBox(height: 10),
            BookingImageGrid(images: images),
          ],
          if (videos.isNotEmpty) ...[
            if (images.isNotEmpty) const SizedBox(height: 14),
            Text(
              context.l10n.workerAttachmentsVideos,
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
            const SizedBox(height: 8),
            ...videos.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: BookingVideoTile(attachment: v),
              ),
            ),
          ],
          if (audios.isNotEmpty) ...[
            if (images.isNotEmpty || videos.isNotEmpty)
              const SizedBox(height: 14),
            Text(
              context.l10n.workerAttachmentsVoiceNotes,
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
            const SizedBox(height: 8),
            ...audios.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: BookingAudioPlayerCard(attachment: a),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
