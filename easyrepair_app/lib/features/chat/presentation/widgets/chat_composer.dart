import 'dart:math' as math;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';

/// Keys the composer's controls expose so widget tests can drive them without
/// depending on icon choices or layout order.
class ChatComposerKeys {
  const ChatComposerKeys._();

  static const composer = Key('chat-composer');
  static const textField = Key('composer-text-field');
  static const emojiButton = Key('composer-emoji-button');
  static const attachButton = Key('composer-attach-button');
  static const cameraButton = Key('composer-camera-button');

  /// The single circular action on the right: mic when the field is empty,
  /// send once it holds text. Never both — see [ChatComposer].
  static const actionButton = Key('composer-action-button');

  static const emojiPanel = Key('chat-emoji-panel');
}

/// The WhatsApp-shaped bottom composer: one rounded surface holding
/// `[emoji | message | attach | camera]`, with a separate circular mic/send
/// action beside it.
///
/// This widget renders and dispatches only. Every behaviour it triggers —
/// sending, attaching, capturing, recording — stays with the page that owns
/// the conversation, so there is exactly one send path, one upload path and
/// one recorder.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.isAttachmentBusy,
    required this.isRecording,
    required this.isPaused,
    required this.recordingDuration,
    required this.amplitudeBars,
    required this.isEmojiPanelVisible,
    required this.applyBottomSafeArea,
    required this.onToggleEmojiPanel,
    required this.onSendText,
    required this.onAttachmentTap,
    required this.onCameraTap,
    required this.onStartRecording,
    required this.onCancelRecording,
    required this.onSendRecording,
    required this.onTogglePauseResume,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final bool isAttachmentBusy;
  final bool isRecording;
  final bool isPaused;
  final Duration recordingDuration;
  final List<double> amplitudeBars;

  /// True while the emoji panel is open below the composer — the left button
  /// then offers the keyboard back instead of the emoji sheet.
  final bool isEmojiPanelVisible;

  /// False when the emoji panel sits underneath and carries the system inset
  /// itself, so the padding is never applied twice.
  final bool applyBottomSafeArea;

  final VoidCallback onToggleEmojiPanel;
  final VoidCallback onSendText;
  final VoidCallback onAttachmentTap;
  final VoidCallback onCameraTap;
  final VoidCallback onStartRecording;
  final VoidCallback onCancelRecording;
  final VoidCallback onSendRecording;
  final VoidCallback onTogglePauseResume;

  /// Lines the field grows to before it starts scrolling its own content.
  /// Past this the composer stops growing, so a long draft can never push the
  /// conversation off the screen.
  static const _maxLines = 5;

  /// Non-whitespace text is what flips mic into send — a field holding only
  /// spaces has nothing to send, so it still offers the mic.
  bool get _hasText => controller.text.trim().isNotEmpty;

  void _onActionTap() {
    if (isRecording) {
      onSendRecording();
      return;
    }
    if (_hasText) {
      onSendText();
      return;
    }
    onStartRecording();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final bottomPadding = applyBottomSafeArea
        ? MediaQuery.paddingOf(context).bottom
        : 0.0;

    return Container(
      key: ChatComposerKeys.composer,
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomPadding),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: isRecording
                ? _RecordingBar(
                    duration: recordingDuration,
                    isPaused: isPaused,
                    amplitudeBars: amplitudeBars,
                    onCancel: onCancelRecording,
                  )
                : _InputSurface(
                    controller: controller,
                    focusNode: focusNode,
                    isEmojiPanelVisible: isEmojiPanelVisible,
                    isAttachmentBusy: isAttachmentBusy,
                    maxLines: _maxLines,
                    onToggleEmojiPanel: onToggleEmojiPanel,
                    onAttachmentTap: onAttachmentTap,
                    onCameraTap: onCameraTap,
                    onSubmitted: onSendText,
                  ),
          ),
          const SizedBox(width: 6),
          if (isRecording) ...[
            _CircleAction(
              icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              iconColor: c.primary,
              background: c.background,
              border: c.controlBorder,
              onTap: onTogglePauseResume,
            ),
            const SizedBox(width: 6),
          ],
          _ActionButton(
            isSending: isSending,
            // Recording resolves with send; otherwise the icon follows the
            // field. Mic and send are the same button and never coexist.
            isSend: isRecording || _hasText,
            onTap: isSending ? null : _onActionTap,
          ),
        ],
      ),
    );
  }
}

/// The rounded `[emoji | field | attach | camera]` surface.
class _InputSurface extends StatelessWidget {
  const _InputSurface({
    required this.controller,
    required this.focusNode,
    required this.isEmojiPanelVisible,
    required this.isAttachmentBusy,
    required this.maxLines,
    required this.onToggleEmojiPanel,
    required this.onAttachmentTap,
    required this.onCameraTap,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isEmojiPanelVisible;
  final bool isAttachmentBusy;
  final int maxLines;
  final VoidCallback onToggleEmojiPanel;
  final VoidCallback onAttachmentTap;
  final VoidCallback onCameraTap;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final busyColor = isAttachmentBusy ? c.disabled : c.textSecondary;

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.controlBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _IconBtn(
            key: ChatComposerKeys.emojiButton,
            icon: isEmojiPanelVisible
                ? Icons.keyboard_rounded
                : Icons.emoji_emotions_outlined,
            color: c.textSecondary,
            onTap: onToggleEmojiPanel,
          ),
          Expanded(
            child: Padding(
              // The row aligns to the bottom so the buttons stay put as the
              // field grows; this keeps a single-line draft optically centred
              // against the 48px minimum.
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: TextField(
                key: ChatComposerKeys.textField,
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.send,
                keyboardType: TextInputType.multiline,
                onSubmitted: (_) => onSubmitted(),
                minLines: 1,
                maxLines: maxLines,
                style: TextStyle(fontSize: 14, color: c.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: context.l10n.chatComposerHint,
                  hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          _IconBtn(
            key: ChatComposerKeys.attachButton,
            icon: Icons.attach_file_rounded,
            color: busyColor,
            onTap: isAttachmentBusy ? null : onAttachmentTap,
          ),
          _IconBtn(
            key: ChatComposerKeys.cameraButton,
            icon: Icons.camera_alt_rounded,
            color: busyColor,
            onTap: isAttachmentBusy ? null : onCameraTap,
          ),
        ],
      ),
    );
  }
}

/// The single circular action: mic, send, or a spinner while a send is in
/// flight.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.isSending,
    required this.isSend,
    required this.onTap,
  });

  final bool isSending;
  final bool isSend;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return GestureDetector(
      key: ChatComposerKeys.actionButton,
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSending ? c.primaryPressed : c.primary,
          shape: BoxShape.circle,
        ),
        child: isSending
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.onPrimary,
                ),
              )
            : Icon(
                isSend ? Icons.send_rounded : Icons.mic_rounded,
                color: c.onPrimary,
                size: 21,
              ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.border,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: border),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    super.key,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 46,
        child: Icon(icon, size: 23, color: color),
      ),
    );
  }
}

// ── Emoji panel ───────────────────────────────────────────────────────────────

/// The emoji keyboard that takes the software keyboard's place below the
/// composer.
///
/// Insertion is delegated to [EmojiPicker] via [controller]: it splices the
/// glyph in at the current selection and leaves the caret after it, so
/// existing text is never replaced.
class ChatEmojiPanel extends StatelessWidget {
  const ChatEmojiPanel({
    super.key,
    required this.controller,
    required this.height,
    required this.onBackspace,
  });

  final TextEditingController controller;
  final double height;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      key: ChatComposerKeys.emojiPanel,
      height: height + bottomPadding,
      padding: EdgeInsets.only(bottom: bottomPadding),
      color: c.surface,
      child: MediaQuery.withClampedTextScaling(
        // Emoji are glyphs on a fixed grid, not prose. Letting them follow a
        // 2.0 text scale overflows the cells without making anything more
        // readable, so the panel is clamped while the rest of chat scales.
        maxScaleFactor: 1.3,
        child: EmojiPicker(
          textEditingController: controller,
          onBackspacePressed: onBackspace,
          config: Config(
            height: height,
            // Skips a per-glyph platform-channel round trip on Android that
            // this app does not need — and that no widget test can answer.
            checkPlatformCompatibility: false,
            emojiViewConfig: EmojiViewConfig(
              backgroundColor: c.surface,
              emojiSizeMax: 26,
              columns: 8,
              gridPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
            ),
            categoryViewConfig: CategoryViewConfig(
              // Recents are still a tab, but the panel opens on smileys so a
              // first-time user never meets an empty grid.
              initCategory: Category.SMILEYS,
              backgroundColor: c.surface,
              dividerColor: c.border,
              indicatorColor: c.primary,
              iconColor: c.textSecondary,
              iconColorSelected: c.primary,
              backspaceColor: c.primary,
            ),
            skinToneConfig: SkinToneConfig(dialogBackgroundColor: c.surface),
            bottomActionBarConfig: BottomActionBarConfig(
              backgroundColor: c.surfaceSubtle,
              buttonColor: c.primary,
              buttonIconColor: c.onPrimary,
            ),
            searchViewConfig: SearchViewConfig(
              backgroundColor: c.surface,
              buttonIconColor: c.textSecondary,
              hintTextStyle: TextStyle(fontSize: 14, color: c.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Height for the emoji panel, preferring the keyboard height the user last
/// saw so swapping between the two does not make the conversation jump.
double emojiPanelHeight(BuildContext context, double lastKeyboardHeight) {
  final screenHeight = MediaQuery.sizeOf(context).height;
  return math.min(
    math.max(lastKeyboardHeight, 240.0),
    math.max(screenHeight * 0.45, 200.0),
  );
}

// ── Recording bar (replaces the input surface while recording) ────────────────

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    required this.duration,
    required this.isPaused,
    required this.amplitudeBars,
    required this.onCancel,
  });

  final Duration duration;
  final bool isPaused;
  final List<double> amplitudeBars;
  final VoidCallback onCancel;

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.controlBorder),
      ),
      child: Row(
        children: [
          isPaused ? const SizedBox(width: 9, height: 9) : const _BlinkingDot(),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              _fmt(duration),
              style: TextStyle(
                fontSize: 13,
                color: c.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRect(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: _Waveform(bars: amplitudeBars),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onCancel,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.delete_outline_rounded,
                color: c.error,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.bars});

  final List<double> bars;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final v in bars)
          Container(
            width: 2.5,
            height: 4 + (v.clamp(0.0, 1.0) * 22),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.25).animate(_controller),
      child: SizedBox(
        width: 9,
        height: 9,
        child: DecoratedBox(
          decoration: BoxDecoration(color: c.error, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
