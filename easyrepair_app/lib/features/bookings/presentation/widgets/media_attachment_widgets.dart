import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../domain/entities/booking_entity.dart';

// ── Palette (matches booking-detail pages) ────────────────────────────────────
const _kAccent  = Color(0xFFDE7356);
const _kDark    = Color(0xFF1A1A1A);
const _kGray    = Color(0xFF6B7280);
const _kLight   = Color(0xFF94A3B8);

// ═════════════════════════════════════════════════════════════════════════════
// AUDIO PLAYER
// ═════════════════════════════════════════════════════════════════════════════

/// A self-contained audio player card.
/// Manages its own [AudioPlayer] instance and disposes it on widget removal.
class BookingAudioPlayerCard extends StatefulWidget {
  final BookingAttachmentEntity attachment;
  const BookingAudioPlayerCard({super.key, required this.attachment});

  @override
  State<BookingAudioPlayerCard> createState() => _BookingAudioPlayerCardState();
}

class _BookingAudioPlayerCardState extends State<BookingAudioPlayerCard> {
  final _player = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasError = false;

  late final StreamSubscription<Duration> _durationSub;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<PlayerState> _stateSub;
  late final StreamSubscription<void> _completeSub;

  @override
  void initState() {
    super.initState();
    _durationSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _positionSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() {
        _isPlaying = s == PlayerState.playing;
        if (s != PlayerState.playing) _isLoading = false;
      });
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _durationSub.cancel();
    _positionSub.cancel();
    _stateSub.cancel();
    _completeSub.cancel();
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
        await _player.play(UrlSource(widget.attachment.url));
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

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // ── Play / Pause button ──────────────────────────────────────
              GestureDetector(
                onTap: _toggle,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _hasError
                        ? const Color(0xFFDC2626)
                        : _kAccent,
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _hasError
                              ? Icons.error_outline_rounded
                              : _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // ── Decorative waveform bars ─────────────────────────────────
              // Bars left of the playhead show as accent; right as faded.
              Expanded(
                child: LayoutBuilder(builder: (_, bc) {
                  const barCount = 28;
                  const spacing = 2.0;
                  final barW =
                      (bc.maxWidth - (barCount - 1) * spacing) / barCount;
                  final filledCount = (progress * barCount).round();
                  const heights = [
                    5.0, 9.0, 13.0, 7.0, 16.0, 10.0, 6.0,
                    12.0, 8.0, 14.0, 9.0, 5.0, 11.0, 7.0,
                  ];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(barCount, (i) {
                      final h = heights[i % heights.length];
                      return Container(
                        width: barW,
                        height: h,
                        margin: i < barCount - 1
                            ? const EdgeInsets.only(right: spacing)
                            : null,
                        decoration: BoxDecoration(
                          color: i < filledCount
                              ? _kAccent
                              : _kAccent.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  );
                }),
              ),
              const SizedBox(width: 10),

              // ── Time label ───────────────────────────────────────────────
              Text(
                _duration > Duration.zero
                    ? '${_fmt(_position)} / ${_fmt(_duration)}'
                    : '--:--',
                style: const TextStyle(
                  fontSize: 11,
                  color: _kGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // ── Seek slider ──────────────────────────────────────────────────
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: _kAccent,
              inactiveTrackColor: _kAccent.withValues(alpha: 0.18),
              thumbColor: _kAccent,
              overlayColor: _kAccent.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: progress,
              onChanged: (_duration == Duration.zero || _isLoading)
                  ? null
                  : (v) {
                      final ms =
                          (v * _duration.inMilliseconds).round();
                      _player.seek(Duration(milliseconds: ms));
                    },
            ),
          ),

          if (_hasError)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'Could not load audio.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
        ],
      ),
    );
  }
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
    return LayoutBuilder(builder: (context, bc) {
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
    });
  }
}

class _ImageTile extends StatelessWidget {
  final String url;
  final double w;
  final double h;
  const _ImageTile({required this.url, required this.w, required this.h});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (_) => _FullImageDialog(url: url),
      ),
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
              color: const Color(0xFFF1F5F9),
              child: const Icon(Icons.broken_image_outlined, color: _kLight),
            ),
            loadingBuilder: (_, child, prog) => prog == null
                ? child
                : Container(
                    width: w,
                    height: h,
                    color: const Color(0xFFF1F5F9),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kAccent,
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white38,
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
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
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
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (_) => _VideoPlayerDialog(url: attachment.url),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white70,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.fileName ?? 'Video',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Tap to play',
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
              size: 18,
            ),
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
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _ctrl.play();
      }).catchError((_) {
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Video area ─────────────────────────────────────────────────
          Center(
            child: _initialized
                ? GestureDetector(
                    onTap: () => _ctrl.value.isPlaying
                        ? _ctrl.pause()
                        : _ctrl.play(),
                    child: AspectRatio(
                      aspectRatio: _ctrl.value.aspectRatio,
                      child: VideoPlayer(_ctrl),
                    ),
                  )
                : const CircularProgressIndicator(color: _kAccent),
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
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
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
    final pos = ctrl.value.position;
    final total = ctrl.value.duration;
    final progress = total.inMilliseconds > 0
        ? (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      color: Colors.black54,
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () =>
                ctrl.value.isPlaying ? ctrl.pause() : ctrl.play(),
            child: Icon(
              ctrl.value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: _kAccent,
                inactiveTrackColor: Colors.white24,
                thumbColor: _kAccent,
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
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
