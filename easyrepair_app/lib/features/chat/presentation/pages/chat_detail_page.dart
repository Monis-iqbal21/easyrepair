import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/location/location_availability.dart';
import '../../../../core/location/location_recovery_snack.dart';
import '../../../../core/network/offline_banner.dart';
import '../../../../core/permissions/media_permission_helper.dart';
import '../../../../core/presentation/widgets/resource_unavailable_view.dart';
import '../../../../core/services/chat_socket_service.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/widgets/handygo_brand_lockup.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/notifications/presentation/providers/notification_providers.dart';
import '../../domain/entities/chat_entities.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_composer.dart';
import '../widgets/voice_playback_coordinator.dart';

class ChatDetailPage extends ConsumerStatefulWidget {
  final String conversationId;

  /// Where to land when back is pressed and there is genuinely nothing to pop
  /// — i.e. a notification or deep link opened this conversation directly, so
  /// no originating screen exists.
  ///
  /// This is a fallback, never a destination: when the conversation was pushed
  /// from another screen, back pops to that screen and this is not consulted.
  /// It was previously named `backRoute` and applied unconditionally, which is
  /// what sent every conversation back to the Chats tab.
  final String? fallbackRoute;

  const ChatDetailPage({
    super.key,
    required this.conversationId,
    this.fallbackRoute,
  });

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  static const _bottomThreshold = 80.0;
  static const _loadOlderThreshold = 120.0;

  late final ChatSocketService _socket;
  final _controller = TextEditingController();
  final _inputFocusNode = FocusNode();

  /// One player for the whole conversation, so voice notes can chain into
  /// each other and can never overlap.
  final _voicePlayback = VoicePlaybackCoordinator();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  bool _isSending = false;
  bool _isSendingAttachment = false;
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _recordingDuration = Duration.zero;
  final Stopwatch _recordingStopwatch = Stopwatch();
  Timer? _recordingTimer;
  String? _recordingPath;
  AudioRecorder? _recorder;
  StreamSubscription<Amplitude>? _amplitudeSub;
  final List<double> _amplitudeBars = [];
  bool _initialPositionPending = true;
  bool _isLoadingOlder = false;
  int _unseenIncomingCount = 0;
  bool _isEmojiPanelVisible = false;

  /// Last software-keyboard height this conversation saw, reused as the emoji
  /// panel's height so swapping between the two does not resize the message
  /// list. Seeded with a sane default for the first open.
  double _lastKeyboardHeight = 280;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(chatSocketServiceProvider);
    _socket.joinConversation(widget.conversationId);
    // Reads the live list, so the note after a finished one is found against
    // the conversation as currently rendered — including after pagination
    // prepends an older page and shifts every index.
    _voicePlayback.bindMessages(
      () =>
          ref.read(chatMessagesProvider(widget.conversationId)).valueOrNull ??
          const <MessageEntity>[],
    );
    _controller.addListener(_onTextChanged);
    _inputFocusNode.addListener(_onInputFocusChanged);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Invalidate so the notifier re-fetches fresh messages every time this
      // screen is (re-)opened, instead of showing a stale cached list.
      ref.invalidate(chatMessagesProvider(widget.conversationId));
      _markLastSeen();
    });
  }

  void _onTextChanged() {
    // Rebuilds the input bar so the circular action button can switch
    // between mic and send icons as the field goes empty/non-empty.
    if (mounted) setState(() {});
  }

  // ── Emoji panel / keyboard ────────────────────────────────────────────────

  /// Tapping into the field asks for the keyboard, so the emoji panel steps
  /// aside — otherwise both would claim the space below the composer.
  void _onInputFocusChanged() {
    if (_inputFocusNode.hasFocus && _isEmojiPanelVisible) {
      setState(() => _isEmojiPanelVisible = false);
    }
  }

  /// The one control that swaps the two input surfaces: emoji opens the panel
  /// and drops the keyboard, the keyboard icon does the reverse.
  void _toggleEmojiPanel() {
    if (_isEmojiPanelVisible) {
      setState(() => _isEmojiPanelVisible = false);
      _inputFocusNode.requestFocus();
      return;
    }
    // Unfocus first: the keyboard has to be on its way out before the panel
    // claims the space, or the two briefly stack.
    _inputFocusNode.unfocus();
    setState(() => _isEmojiPanelVisible = true);
  }

  void _closeEmojiPanel() {
    if (!_isEmojiPanelVisible) return;
    setState(() => _isEmojiPanelVisible = false);
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _amplitudeSub?.cancel();
    _recorder?.dispose();
    _controller.removeListener(_onTextChanged);
    _inputFocusNode.removeListener(_onInputFocusChanged);
    _scrollController.removeListener(_onScroll);
    _controller.dispose();
    _inputFocusNode.dispose();
    _voicePlayback.dispose();
    _scrollController.dispose();
    _socket.leaveConversation(widget.conversationId);
    super.dispose();
  }

  // ── Seen ──────────────────────────────────────────────────────────────────

  void _markLastSeen() {
    if (!mounted) return;
    final messages = ref
        .read(chatMessagesProvider(widget.conversationId))
        .valueOrNull;
    if (messages == null || messages.isEmpty) return;
    final currentUserId = ref.read(authStateProvider).valueOrNull?.id ?? '';
    bool markedAny = false;
    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.senderUserId != currentUserId && msg.seenAt == null) {
        _socket.markSeen(widget.conversationId, msg.id);
        markedAny = true;
      }
    }
    if (markedAny) {
      // The conversations source refreshes on the persisted message_seen
      // receipt. Do not race the server write with an immediate GET here.
      ref.invalidate(unreadNotificationCountProvider);
    }
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return false;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= _bottomThreshold;
  }

  void _onScroll() {
    if (_unseenIncomingCount > 0 && _isNearBottom && mounted) {
      setState(() => _unseenIncomingCount = 0);
    }
    if (_initialPositionPending ||
        _isLoadingOlder ||
        !_scrollController.hasClients ||
        _scrollController.position.pixels > _loadOlderThreshold) {
      return;
    }
    unawaited(_loadOlderMessages());
  }

  void _scheduleInitialPosition() {
    if (!_initialPositionPending) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_initialPositionPending) return;
      if (!_scrollController.hasClients) {
        _scheduleInitialPosition();
        return;
      }
      final laidOutMax = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(laidOutMax);
      // A lazy list can discover taller rows only after jumping through them.
      // Verify on the following layout frame and repeat until max extent is
      // stable; this is lifecycle-driven and uses no timing guess.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_initialPositionPending) return;
        if (!_scrollController.hasClients) {
          _scheduleInitialPosition();
          return;
        }
        final position = _scrollController.position;
        final extentStable =
            (position.maxScrollExtent - laidOutMax).abs() < 0.5;
        final atAbsoluteBottom =
            position.maxScrollExtent - position.pixels < 0.5;
        if (extentStable && atAbsoluteBottom) {
          _initialPositionPending = false;
        } else {
          _scheduleInitialPosition();
        }
      });
    });
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingOlder || !_scrollController.hasClients) return;
    final notifier = ref.read(
      chatMessagesProvider(widget.conversationId).notifier,
    );
    if (!notifier.hasOlderMessages || notifier.isLoadingOlder) return;

    _isLoadingOlder = true;
    final oldPixels = _scrollController.position.pixels;
    final oldMaxExtent = _scrollController.position.maxScrollExtent;
    try {
      final inserted = await notifier.loadOlder();
      if (!mounted || inserted == 0) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final addedExtent =
            _scrollController.position.maxScrollExtent - oldMaxExtent;
        _scrollController.jumpTo(oldPixels + addedExtent);
      });
    } catch (error) {
      if (mounted) _showError(failureMessage(context.l10n, error));
    } finally {
      _isLoadingOlder = false;
    }
  }

  void _scrollToBottom({bool smooth = true}) {
    if (_unseenIncomingCount > 0 && mounted) {
      setState(() => _unseenIncomingCount = 0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (smooth) {
        unawaited(
          _scrollController
              .animateTo(
                target,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              )
              .then((_) {
                // Lazy slivers can refine maxScrollExtent while traversing
                // previously unbuilt rows. Correct on the next layout frame
                // so "latest" is absolute, without an arbitrary delay.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });
              }),
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _handleMessageStateChange(
    AsyncValue<List<MessageEntity>>? previous,
    AsyncValue<List<MessageEntity>> next,
  ) {
    final nextMessages = next.valueOrNull;
    if (nextMessages == null) return;

    if (_initialPositionPending) {
      if (nextMessages.isNotEmpty) _scheduleInitialPosition();
      WidgetsBinding.instance.addPostFrameCallback((_) => _markLastSeen());
      return;
    }

    final previousMessages = previous?.valueOrNull;
    if (previousMessages == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markLastSeen());
      return;
    }
    final previousIds = previousMessages.map((m) => m.id).toSet();
    final appended = nextMessages
        .where((message) => !previousIds.contains(message.id))
        .where(
          (message) =>
              previousMessages.isEmpty ||
              message.createdAt.compareTo(previousMessages.last.createdAt) >= 0,
        )
        .toList();
    if (appended.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markLastSeen());
      return;
    }

    final currentUserId = ref.read(authStateProvider).valueOrNull?.id ?? '';
    final incomingCount = appended
        .where((message) => message.senderUserId != currentUserId)
        .length;
    final wasNearBottom = _isNearBottom;
    final anchoredPixels = _scrollController.hasClients
        ? _scrollController.position.pixels
        : null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _markLastSeen();
      if (incomingCount == 0) return;
      if (wasNearBottom) {
        _scrollToBottom();
      } else {
        if (anchoredPixels != null && _scrollController.hasClients) {
          _scrollController.jumpTo(
            anchoredPixels
                .clamp(
                  _scrollController.position.minScrollExtent,
                  _scrollController.position.maxScrollExtent,
                )
                .toDouble(),
          );
        }
        setState(() => _unseenIncomingCount += incomingCount);
      }
    });
  }

  // ── Send text ─────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _controller.clear();
    setState(() => _isSending = true);

    try {
      await ref
          .read(sendMessageProvider.notifier)
          .send(widget.conversationId, text);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) _showError(failureMessage(context.l10n, e));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Attachment sheet ──────────────────────────────────────────────────────

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.semanticColors.surface.withValues(alpha: 0),
      builder: (_) => _AttachmentSheet(
        onGalleryImage: () {
          Navigator.pop(context);
          _pickFromGallery(false);
        },
        onGalleryVideo: () {
          Navigator.pop(context);
          _pickFromGallery(true);
        },
        // The camera button now captures a photo outright, so this sheet is
        // the only remaining way to reach camera *video* capture. It routes
        // to the same _captureFromCamera as before — no second media path.
        onCameraVideo: () {
          Navigator.pop(context);
          _captureFromCamera(true);
        },
        onLocation: () {
          Navigator.pop(context);
          _sendLocation();
        },
      ),
    );
  }

  // ── Gallery / camera ──────────────────────────────────────────────────────

  Future<void> _pickFromGallery(bool isVideo) async {
    // Re-entry guard: an attachment send already in flight must never let a
    // second picker flow start (accidental repeated taps on the trigger).
    if (_isSendingAttachment) return;
    if (isVideo) {
      final file = await runPickerWithRecovery(
        context,
        MediaPermissionKind.gallery,
        () => _picker.pickVideo(source: ImageSource.gallery),
      );
      if (file == null || !mounted) return;
      final mime = file.mimeType ?? _mimeFromPath(file.path);
      await _sendMediaFile(file.path, mime);
    } else {
      final files =
          await runPickerWithRecovery(
            context,
            MediaPermissionKind.gallery,
            () => _picker.pickMultiImage(),
          ) ??
          [];
      if (files.isEmpty || !mounted) return;
      setState(() => _isSendingAttachment = true);
      try {
        for (final file in files) {
          final mime = file.mimeType ?? _mimeFromPath(file.path);
          final result = await ref
              .read(chatRepositoryProvider)
              .sendMediaMessage(widget.conversationId, file.path, mime);
          result.fold(
            (failure) => _showError(failureMessage(context.l10n, failure)),
            (message) => ref
                .read(chatMessagesProvider(widget.conversationId).notifier)
                .append(message),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } finally {
        if (mounted) setState(() => _isSendingAttachment = false);
      }
    }
  }

  Future<void> _captureFromCamera(bool isVideo) async {
    final file = await runPickerWithRecovery(
      context,
      MediaPermissionKind.camera,
      () => isVideo
          ? _picker.pickVideo(source: ImageSource.camera)
          : _picker.pickImage(source: ImageSource.camera),
    );
    if (file == null || !mounted) return;
    final mime = file.mimeType ?? _mimeFromPath(file.path);
    await _sendMediaFile(file.path, mime);
  }

  Future<void> _sendMediaFile(String path, String mimeType) async {
    // Re-entry guard: an attachment send already in flight must never submit
    // the same picked file twice from an accidental repeated tap.
    if (_isSendingAttachment) return;
    setState(() => _isSendingAttachment = true);
    try {
      final result = await ref
          .read(chatRepositoryProvider)
          .sendMediaMessage(widget.conversationId, path, mimeType);
      result.fold(
        (failure) => _showError(failureMessage(context.l10n, failure)),
        (message) {
          ref
              .read(chatMessagesProvider(widget.conversationId).notifier)
              .append(message);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _isSendingAttachment = false);
    }
  }

  // ── Voice recording ───────────────────────────────────────────────────────

  Future<void> _startVoiceRecording() async {
    // Captured before the await — the permission prompt is an async gap.
    final micDenied = context.l10n.chatMicPermissionRequired;
    final status = await Permission.microphone.request();
    if (status.isPermanentlyDenied) {
      _showError(micDenied);
      openAppSettings();
      return;
    }
    if (!status.isGranted) {
      _showError(micDenied);
      return;
    }
    _recorder ??= AudioRecorder();

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder!.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordingPath!,
    );
    _recordingStopwatch
      ..reset()
      ..start();

    setState(() {
      _isRecording = true;
      _isPaused = false;
      _recordingDuration = Duration.zero;
      _amplitudeBars.clear();
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingDuration = _recordingStopwatch.elapsed);
      }
    });

    // Real amplitude stream from the recorder — drives the live waveform.
    // The package pauses/resumes this stream internally alongside pause()/resume().
    _amplitudeSub?.cancel();
    _amplitudeSub = _recorder!
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
          if (!mounted) return;
          final normalized = ((amp.current + 45) / 45).clamp(0.0, 1.0);
          setState(() {
            _amplitudeBars.add(normalized);
            if (_amplitudeBars.length > 100) {
              _amplitudeBars.removeAt(0);
            }
          });
        });
  }

  Future<void> _togglePauseResumeRecording() async {
    if (!_isRecording || _recorder == null) return;
    if (_isPaused) {
      await _recorder!.resume();
      _recordingStopwatch.start();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordingDuration = _recordingStopwatch.elapsed);
        }
      });
      setState(() => _isPaused = false);
    } else {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      await _recorder!.pause();
      _recordingStopwatch.stop();
      setState(() => _isPaused = true);
    }
  }

  Future<void> _stopVoiceRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    _recordingStopwatch.stop();
    final durationSeconds =
        _recordingStopwatch.elapsedMicroseconds /
        Duration.microsecondsPerSecond;
    final path = await _recorder?.stop();
    final filePath = path ?? _recordingPath;

    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordingDuration = Duration.zero;
      _amplitudeBars.clear();
    });

    if (filePath != null) {
      await _sendVoiceFile(filePath, durationSeconds);
    }
    _recordingStopwatch.reset();
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    // cancel() stops the recorder and deletes the underlying temp file.
    await _recorder?.cancel();
    _recordingStopwatch
      ..stop()
      ..reset();

    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordingDuration = Duration.zero;
      _amplitudeBars.clear();
    });
  }

  Future<void> _sendVoiceFile(String path, double durationSeconds) async {
    // Re-entry guard: an attachment send already in flight must never submit
    // the same recorded voice note twice from an accidental repeated tap.
    if (_isSendingAttachment) return;
    setState(() => _isSendingAttachment = true);
    try {
      final result = await ref
          .read(chatRepositoryProvider)
          .sendVoiceMessage(widget.conversationId, path, durationSeconds);
      result.fold(
        (failure) => _showError(failureMessage(context.l10n, failure)),
        (message) {
          ref
              .read(chatMessagesProvider(widget.conversationId).notifier)
              .append(message);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _isSendingAttachment = false);
    }
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _sendLocation() async {
    // Re-entry guard: an attachment send already in flight must never start
    // a second location resolve+send from an accidental repeated tap.
    if (_isSendingAttachment) return;
    final locationResult = await resolveCurrentLocation();
    if (!locationResult.isAvailable) {
      if (mounted) {
        showLocationRecoverySnack(
          context,
          locationResult.status,
          onRetry: _sendLocation,
        );
      }
      return;
    }

    setState(() => _isSendingAttachment = true);
    try {
      final position = locationResult.position!;
      final result = await ref
          .read(chatRepositoryProvider)
          .sendLocationMessage(
            widget.conversationId,
            position.latitude,
            position.longitude,
          );
      result.fold(
        (failure) => _showError(failureMessage(context.l10n, failure)),
        (message) {
          ref
              .read(chatMessagesProvider(widget.conversationId).notifier)
              .append(message);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _isSendingAttachment = false);
    }
  }

  // ── Message actions ───────────────────────────────────────────────────────

  void _showMessageActions(MessageEntity message, String currentUserId) {
    if (message.isDeleted) return;
    if (message.type == ChatMessageType.system) return;
    if (message.senderUserId != currentUserId) return;

    final sent = DateTime.tryParse(message.createdAt) ?? DateTime.now();
    final withinWindow =
        DateTime.now().difference(sent).inSeconds < 300; // 5 minutes

    if (!withinWindow) return;

    final canEdit = message.type == ChatMessageType.text;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.semanticColors.surface.withValues(alpha: 0),
      builder: (sheetContext) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: sheetContext.semanticColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sheetContext.semanticColors.border),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetContext.semanticColors.controlBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (canEdit)
                ListTile(
                  leading: Icon(
                    Icons.edit_outlined,
                    color: sheetContext.semanticColors.textPrimary,
                  ),
                  title: Text(context.l10n.chatEditMessage),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(message);
                  },
                ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: sheetContext.semanticColors.error,
                ),
                title: Text(
                  context.l10n.chatDeleteMessage,
                  style: TextStyle(color: sheetContext.semanticColors.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(message);
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(MessageEntity message) {
    final editController = TextEditingController(text: message.text ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        final c = dialogContext.semanticColors;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text(context.l10n.chatEditMessage),
          content: TextField(
            controller: editController,
            maxLines: 5,
            minLines: 1,
            autofocus: true,
            decoration: InputDecoration(
              hintText: context.l10n.chatEditHint,
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                context.l10n.commonCancel,
                style: TextStyle(color: c.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                final newText = editController.text.trim();
                if (newText.isEmpty || newText == message.text) {
                  Navigator.pop(dialogContext);
                  return;
                }
                Navigator.pop(dialogContext);
                await _doEdit(message, newText);
              },
              child: Text(
                context.l10n.commonSave,
                style: TextStyle(color: c.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    ).then((_) => editController.dispose());
  }

  Future<void> _doEdit(MessageEntity message, String newText) async {
    final result = await ref
        .read(chatRepositoryProvider)
        .editMessage(widget.conversationId, message.id, newText);
    result.fold(
      (failure) => _showError(failureMessage(context.l10n, failure)),
      (updated) {
        ref
            .read(chatMessagesProvider(widget.conversationId).notifier)
            .updateMessage(updated);
      },
    );
  }

  void _confirmDelete(MessageEntity message) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final c = dialogContext.semanticColors;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text(context.l10n.chatDeleteMessage),
          content: Text(context.l10n.chatDeleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                context.l10n.commonCancel,
                style: TextStyle(color: c.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                context.l10n.commonDelete,
                style: TextStyle(color: c.error, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    ).then((confirmed) async {
      if (confirmed != true) return;
      final result = await ref
          .read(chatRepositoryProvider)
          .deleteMessage(widget.conversationId, message.id);
      result.fold(
        (failure) => _showError(failureMessage(context.l10n, failure)),
        (deleted) {
          ref
              .read(chatMessagesProvider(widget.conversationId).notifier)
              .markDeleted(deleted.id, deleted.deletedAt!);
        },
      );
    });
  }

  // ── Call ──────────────────────────────────────────────────────────────────

  /// Opens the device dialer pre-filled with [phone] — never places the call
  /// automatically. Mirrors the same `tel:` + launchUrl pattern already used
  /// for Call Worker/Call Client on the booking pages and for Contact
  /// Support, so behavior stays consistent across the app.
  Future<void> _callParticipant(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        _showError(context.l10n.chatCouldNotOpenDialer);
      }
    } catch (e) {
      if (mounted) _showError(context.l10n.chatCouldNotOpenDialer);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.semanticColors.error,
      ),
    );
  }

  String _mimeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/avi';
      default:
        return 'application/octet-stream';
    }
  }

  bool _differentDay(String a, String b) {
    try {
      final da = DateTime.parse(a).toLocal();
      final db = DateTime.parse(b).toLocal();
      return da.year != db.year || da.month != db.month || da.day != db.day;
    } catch (_) {
      return false;
    }
  }

  ConversationEntity _emptyConversation() {
    return ConversationEntity(
      id: widget.conversationId,
      clientUserId: '',
      workerUserId: '',
      createdByUserId: '',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
      otherParticipant: const ConversationParticipantEntity(
        userId: '',
        firstName: '',
        lastName: '',
      ),
    );
  }

  void _showParticipantTray(
    BuildContext context,
    ConversationParticipantEntity participant,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.semanticColors.surface.withValues(alpha: 0),
      isScrollControlled: true,
      builder: (_) => _ParticipantTray(participant: participant),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;

    // Read, never written back through setState: this only needs to be right
    // by the *next* build, which is the build that opens the panel.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardInset > 100) _lastKeyboardHeight = keyboardInset;

    final messagesAsync = ref.watch(
      chatMessagesProvider(widget.conversationId),
    );
    final isShowingCachedData =
        ref.watch(chatMessagesIsOfflineProvider(widget.conversationId)) &&
        messagesAsync.hasValue;
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.id ?? '';

    ref.listen(
      chatMessagesProvider(widget.conversationId),
      _handleMessageStateChange,
    );

    final conversations = ref.watch(chatConversationsProvider).valueOrNull;
    final conversation = conversations?.firstWhere(
      (c) => c.id == widget.conversationId,
      orElse: _emptyConversation,
    );
    final participant = conversation?.otherParticipant;
    final isSupport = conversation?.isSupport ?? false;

    // A conversation is opened from many places — the Chats tab, the workers
    // list, an Ustaad's detail page, a booking, a job — so back must return to
    // whichever of those pushed it. That is exactly what popping does, so the
    // normal pop is left alone rather than being redirected anywhere.
    //
    // The one case with nothing to pop is a notification or deep link that
    // cold-starts the app straight into a conversation. Only there does
    // [fallbackRoute] apply, so the user lands on the conversation list
    // instead of the app closing.
    //
    // The Navigator is asked, not GoRouter. PopScope is a Navigator mechanism
    // and the Navigator is the one that knows the true stack — including pages
    // pushed imperatively with MaterialPageRoute, which GoRouter's match list
    // does not contain (the workers list and Ustaad map are pushed that way).
    // It also keeps this page usable without a GoRouter ancestor, since this
    // runs on every build.
    //
    // Popping through the Navigator still keeps GoRouter in step: its
    // onPopPageWithRouteMatch callback fires for any removal of one of its
    // pages and updates the match list.
    // An open emoji panel is the innermost thing back should close, so pop is
    // intercepted while it is up even when real history exists behind it.
    // Once it closes this reverts to the plain history check, leaving normal
    // back behaviour exactly as it was.
    final canPop = Navigator.canPop(context) && !_isEmojiPanelVisible;

    // The Support thread never shows a call icon — HandyGo Support has no
    // legitimate phone-call workflow today, and no support number is ever
    // invented here. A normal Client<->Worker conversation shows it only
    // once the other participant's registered phone number is known.
    final participantPhone = participant?.phone;
    final showCall =
        !isSupport && participantPhone != null && participantPhone.isNotEmpty;

    void handleBack() {
      if (canPop) {
        Navigator.pop(context);
      } else if (widget.fallbackRoute != null) {
        context.go(widget.fallbackRoute!);
      }
    }

    return PopScope(
      // True whenever real history exists and nothing on-screen wants back
      // first, so the Android system back button and the browser back button
      // are handled by the framework and are not intercepted at all.
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Back closes the emoji panel and stops there — it must not also
        // leave the conversation.
        if (_isEmojiPanelVisible) {
          _closeEmojiPanel();
          return;
        }
        handleBack();
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.surface,
          elevation: 0,
          surfaceTintColor: c.surface.withValues(alpha: 0),
          titleSpacing: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: c.textPrimary,
              size: 20,
            ),
            onPressed: handleBack,
          ),
          title: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // The support account is a system user with no profile, rating or
            // booking history — there is nothing to show in the tray.
            onTap:
                !isSupport &&
                    participant != null &&
                    participant.userId.isNotEmpty
                ? () => _showParticipantTray(context, participant)
                : null,
            child: Row(
              children: [
                _AppBarAvatar(
                  avatarUrl: participant?.avatarUrl,
                  initials: participant?.initials ?? '?',
                  isSupport: isSupport,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    participant?.fullName.isNotEmpty == true
                        ? participant!.fullName
                        : context.l10n.chatTitleFallback,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (showCall)
              IconButton(
                icon: Icon(Icons.call_rounded, color: c.primary, size: 22),
                tooltip: context.l10n.trackCall,
                onPressed: () => _callParticipant(participantPhone),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: c.border),
          ),
        ),
        body: Column(
          children: [
            if (isSupport) const _SupportBanner(),
            if (isShowingCachedData) const OfflineDataBanner(),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: messagesAsync.when(
                      loading: () => Center(
                        child: CircularProgressIndicator(color: c.primary),
                      ),
                      error: (err, _) => isResourceUnavailableFailure(err)
                          ? ResourceUnavailableView(
                              message:
                                  context.l10n.resourceConversationUnavailable,
                              actionLabel: context.l10n.goToChatsAction,
                              onAction: () => context.go(
                                ref
                                            .read(authStateProvider)
                                            .valueOrNull
                                            ?.isWorker ==
                                        true
                                    ? '/worker/chat'
                                    : '/client/chat',
                              ),
                            )
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: c.error,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      failureMessage(context.l10n, err),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: c.textSecondary),
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () => ref
                                          .read(
                                            chatMessagesProvider(
                                              widget.conversationId,
                                            ).notifier,
                                          )
                                          .refresh(),
                                      child: Text(
                                        context.l10n.commonRetry,
                                        style: TextStyle(color: c.primary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      data: (messages) {
                        if (messages.isEmpty) {
                          return Center(
                            child: Text(
                              context.l10n.chatNoMessagesYet,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isMe = message.senderUserId == currentUserId;

                            final showSeparator =
                                index == 0 ||
                                _differentDay(
                                  messages[index - 1].createdAt,
                                  message.createdAt,
                                );

                            return Column(
                              children: [
                                if (showSeparator)
                                  _DateSeparator(isoString: message.createdAt),
                                message.type == ChatMessageType.system
                                    ? _SystemMessageBubble(message: message)
                                    : _MessageBubble(
                                        message: message,
                                        isMe: isMe,
                                        voicePlayback: _voicePlayback,
                                        onLongPress: (msg) =>
                                            _showMessageActions(
                                              msg,
                                              currentUserId,
                                            ),
                                      ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (_unseenIncomingCount > 0)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 8,
                      child: Center(
                        child: _NewMessageIndicator(
                          count: _unseenIncomingCount,
                          onTap: _scrollToBottom,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Upload loading banner
            if (_isSendingAttachment)
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(top: BorderSide(color: c.border)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.primary,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      context.l10n.commonUploading,
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            // WhatsApp-style composer: [emoji | message | attach | camera]
            // plus a separate circular mic/send action.
            ChatComposer(
              controller: _controller,
              focusNode: _inputFocusNode,
              isSending: _isSending,
              isAttachmentBusy: _isSendingAttachment,
              isRecording: _isRecording,
              isPaused: _isPaused,
              recordingDuration: _recordingDuration,
              amplitudeBars: _amplitudeBars,
              isEmojiPanelVisible: _isEmojiPanelVisible,
              // While the panel is open it sits below the composer and takes
              // the system inset, so the composer must not add it as well.
              applyBottomSafeArea: !_isEmojiPanelVisible,
              onToggleEmojiPanel: _toggleEmojiPanel,
              onSendText: _send,
              onAttachmentTap: _showAttachmentSheet,
              // Straight to capture — the camera button is not a menu.
              onCameraTap: () => _captureFromCamera(false),
              onStartRecording: _startVoiceRecording,
              onCancelRecording: _cancelVoiceRecording,
              onSendRecording: _stopVoiceRecording,
              onTogglePauseResume: _togglePauseResumeRecording,
            ),
            if (_isEmojiPanelVisible)
              ChatEmojiPanel(
                controller: _controller,
                height: emojiPanelHeight(context, _lastKeyboardHeight),
                onBackspace: () {},
              ),
          ],
        ),
      ),
    );
  }
}

// ── Participant tray ───────────────────────────────────────────────────────────

class _ParticipantTray extends StatelessWidget {
  final ConversationParticipantEntity participant;

  const _ParticipantTray({required this.participant});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final c = context.semanticColors;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.controlBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomPadding),
            child: Column(
              children: [
                _TrayAvatar(participant: participant),
                const SizedBox(height: 14),
                Text(
                  participant.fullName.isNotEmpty
                      ? participant.fullName
                      : context.l10n.commonUser,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (participant.rating != null) ...[
                  const SizedBox(height: 10),
                  _RatingRow(rating: participant.rating!),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrayAvatar extends StatelessWidget {
  final ConversationParticipantEntity participant;
  const _TrayAvatar({required this.participant});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final url = participant.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 42,
        backgroundImage: NetworkImage(url),
        backgroundColor: c.surfaceSubtle,
      );
    }
    return CircleAvatar(
      radius: 42,
      backgroundColor: c.primary,
      child: Text(
        participant.initials.isNotEmpty ? participant.initials : '?',
        style: TextStyle(
          color: c.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 28,
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final double rating;
  const _RatingRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final filled = rating.floor();
    final hasHalf = (rating - filled) >= 0.25;
    final empty = 5 - filled - (hasHalf ? 1 : 0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < filled; i++)
          Icon(Icons.star_rounded, size: 20, color: c.warning),
        if (hasHalf) Icon(Icons.star_half_rounded, size: 20, color: c.warning),
        for (int i = 0; i < empty; i++)
          Icon(Icons.star_outline_rounded, size: 20, color: c.controlBorder),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        Text(' / 5', style: TextStyle(fontSize: 13, color: c.textSecondary)),
      ],
    );
  }
}

// ── AppBar avatar ─────────────────────────────────────────────────────────────

class _AppBarAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final bool isSupport;
  const _AppBarAvatar({
    this.avatarUrl,
    required this.initials,
    this.isSupport = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    if (isSupport) {
      // Same mark as the Chat List row and the About card — the launcher
      // tile it replaced was a baked-in orange bitmap.
      return const HandyGoBrandMark(size: 38);
    }
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: c.surfaceSubtle,
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: c.primary,
      child: Text(
        initials.isNotEmpty ? initials : '?',
        style: TextStyle(
          color: c.onPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ── Support banner ────────────────────────────────────────────────────────────

/// Static guidance shown at the top of the HandyGo Support thread.
///
/// Deliberately a widget and NOT a persisted SYSTEM message: nothing is written
/// to the database, so the conversation is genuinely empty until the user
/// writes, and the admin inbox never shows a fake incoming message.
class _SupportBanner extends StatelessWidget {
  const _SupportBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.softTeal,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.support_agent_rounded, size: 18, color: c.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.chatSupportBanner,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date separator ─────────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final String isoString;
  const _DateSeparator({required this.isoString});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: c.border)),
          const SizedBox(width: 10),
          Text(
            _formatDate(context, isoString),
            style: TextStyle(
              fontSize: 12,
              color: c.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: c.border)),
        ],
      ),
    );
  }

  String _formatDate(BuildContext context, String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(dt.year, dt.month, dt.day);
      final l10n = context.l10n;
      if (msgDay == today) return l10n.commonToday;
      if (today.difference(msgDay).inDays == 1) return l10n.commonYesterday;
      final months = [
        l10n.monthJan,
        l10n.monthFeb,
        l10n.monthMar,
        l10n.monthApr,
        l10n.monthMay,
        l10n.monthJun,
        l10n.monthJul,
        l10n.monthAug,
        l10n.monthSep,
        l10n.monthOct,
        l10n.monthNov,
        l10n.monthDec,
      ];
      return l10n.dateDayMonthYear(dt.day, months[dt.month - 1], dt.year);
    } catch (_) {
      return '';
    }
  }
}

// ── System message ─────────────────────────────────────────────────────────────

class _SystemMessageBubble extends StatelessWidget {
  final MessageEntity message;
  const _SystemMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.text ?? '',
          style: TextStyle(fontSize: 12, color: c.textSecondary),
        ),
      ),
    );
  }
}

// ── Message bubble (wrapper) ───────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;
  final VoicePlaybackCoordinator voicePlayback;
  final void Function(MessageEntity) onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.voicePlayback,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final timeStr = _fmt(message.createdAt);

    // Image/video/location content renders its own internal layout without inner padding
    final isMediaFull =
        !message.isDeleted &&
        (message.type == ChatMessageType.image ||
            message.type == ChatMessageType.video ||
            message.type == ChatMessageType.location);

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 16),
    );

    return GestureDetector(
      onLongPress: () => onLongPress(message),
      child: Align(
        alignment: isMe
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
              ),
              margin: EdgeInsetsDirectional.only(
                top: 4,
                bottom: 4,
                start: isMe ? 48 : 0,
                end: isMe ? 0 : 48,
              ),
              decoration: isMediaFull
                  ? null // media widgets provide their own decoration
                  : BoxDecoration(
                      color: isMe ? c.primary : c.surface,
                      borderRadius: borderRadius,
                      border: Border.all(color: isMe ? c.primary : c.border),
                      boxShadow: [
                        BoxShadow(
                          color: c.scrim.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
              child: isMediaFull
                  ? _buildContent(context, timeStr)
                  : ClipRRect(
                      borderRadius: borderRadius,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: _buildContent(context, timeStr),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, String timeStr) {
    if (message.isDeleted) {
      return _DeletedContent(
        messageId: message.id,
        isMe: isMe,
        isRead: message.seenAt != null,
        timeStr: timeStr,
      );
    }
    switch (message.type) {
      case ChatMessageType.image:
        return _ImageContent(message: message, isMe: isMe, timeStr: timeStr);
      case ChatMessageType.video:
        return _VideoContent(message: message, isMe: isMe, timeStr: timeStr);
      case ChatMessageType.voice:
        return _VoiceContent(
          message: message,
          isMe: isMe,
          timeStr: timeStr,
          playback: voicePlayback,
        );
      case ChatMessageType.location:
        return _LocationContent(message: message, isMe: isMe, timeStr: timeStr);
      default:
        return _TextContent(message: message, isMe: isMe, timeStr: timeStr);
    }
  }

  String _fmt(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }
}

// ── Message content widgets ────────────────────────────────────────────────────

class _MessageTimestamp extends StatelessWidget {
  final String messageId;
  final String timeStr;
  final bool isMe;
  final bool isRead;
  final Color color;
  final double fontSize;

  const _MessageTimestamp({
    required this.messageId,
    required this.timeStr,
    required this.isMe,
    required this.isRead,
    required this.color,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeStr,
          style: TextStyle(fontSize: fontSize, color: color),
        ),
        if (isMe) ...[
          const SizedBox(width: 3),
          Icon(
            isRead ? Icons.done_all_rounded : Icons.done_rounded,
            key: Key('message-state-$messageId'),
            size: fontSize + 4,
            color: color,
            semanticLabel: isRead ? context.l10n.chatSeen : null,
          ),
        ],
      ],
    );
  }
}

class _DeletedContent extends StatelessWidget {
  final String messageId;
  final bool isMe;
  final bool isRead;
  final String timeStr;
  const _DeletedContent({
    required this.messageId,
    required this.isMe,
    required this.isRead,
    required this.timeStr,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block_rounded,
              size: 14,
              color: isMe
                  ? c.onPrimary.withValues(alpha: 0.75)
                  : c.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              context.l10n.chatMessageDeleted,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: isMe
                    ? c.onPrimary.withValues(alpha: 0.82)
                    : c.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _MessageTimestamp(
          messageId: messageId,
          timeStr: timeStr,
          isMe: isMe,
          isRead: isRead,
          color: isMe ? c.onPrimary.withValues(alpha: 0.65) : c.textSecondary,
        ),
      ],
    );
  }
}

class _TextContent extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;
  final String timeStr;
  const _TextContent({
    required this.message,
    required this.isMe,
    required this.timeStr,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.text ?? '',
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: isMe ? c.onPrimary : c.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.editedAt != null)
              Text(
                '${context.l10n.chatEdited}  ',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: isMe
                      ? c.onPrimary.withValues(alpha: 0.68)
                      : c.textSecondary,
                ),
              ),
            _MessageTimestamp(
              messageId: message.id,
              timeStr: timeStr,
              isMe: isMe,
              isRead: message.seenAt != null,
              color: isMe
                  ? c.onPrimary.withValues(alpha: 0.75)
                  : c.textSecondary,
            ),
          ],
        ),
      ],
    );
  }
}

class _ImageContent extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;
  final String timeStr;
  const _ImageContent({
    required this.message,
    required this.isMe,
    required this.timeStr,
  });

  static const double _w = 200;
  static const double _h = 150;
  static const _radius = BorderRadius.all(Radius.circular(14));

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return GestureDetector(
      onTap: () => _showFullScreen(context, message.mediaUrl!),
      child: Container(
        width: _w,
        height: _h,
        decoration: BoxDecoration(
          borderRadius: _radius,
          border: Border.all(color: c.border, width: 1),
        ),
        child: ClipRRect(
          borderRadius: _radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                message.mediaUrl!,
                width: _w,
                height: _h,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: c.surfaceSubtle,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                            : null,
                        color: c.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, e, s) => Container(
                  color: c.surfaceSubtle,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      size: 36,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ),
              // Time stamp overlaid bottom-right
              PositionedDirectional(
                end: 6,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: c.scrim.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _MessageTimestamp(
                    messageId: message.id,
                    timeStr: timeStr,
                    isMe: isMe,
                    isRead: message.seenAt != null,
                    color: c.onScrim,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreen(BuildContext context, String url) {
    final c = context.semanticColors;
    showDialog(
      context: context,
      barrierColor: c.scrim.withValues(alpha: 0.9),
      builder: (_) => Dialog(
        backgroundColor: c.scrim.withValues(alpha: 0),
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _VideoContent extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;
  final String timeStr;
  const _VideoContent({
    required this.message,
    required this.isMe,
    required this.timeStr,
  });

  static const double _w = 200;
  static const double _h = 150;
  static const _radius = BorderRadius.all(Radius.circular(14));

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final thumb = message.thumbnailUrl;
    return GestureDetector(
      onTap: () => _openPlayer(context),
      child: Container(
        width: _w,
        height: _h,
        decoration: BoxDecoration(
          borderRadius: _radius,
          border: Border.all(color: c.border, width: 1),
        ),
        child: ClipRRect(
          borderRadius: _radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail or dark placeholder
              if (thumb != null && thumb.isNotEmpty)
                Image.network(
                  thumb,
                  width: _w,
                  height: _h,
                  fit: BoxFit.cover,
                  errorBuilder: (context, e, s) => ColoredBox(color: c.scrim),
                )
              else
                ColoredBox(color: c.scrim),
              // Centered play button
              Center(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: c.scrim.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: c.onScrim,
                    size: 28,
                  ),
                ),
              ),
              // Time stamp overlaid bottom-right
              PositionedDirectional(
                end: 6,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: c.scrim.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _MessageTimestamp(
                    messageId: message.id,
                    timeStr: timeStr,
                    isMe: isMe,
                    isRead: message.seenAt != null,
                    color: c.onScrim,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context) {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: context.semanticColors.scrim,
      builder: (_) => _VideoPlayerDialog(url: url),
    );
  }
}

class _VideoPlayerDialog extends StatefulWidget {
  final String url;
  const _VideoPlayerDialog({required this.url});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() => _initialized = true);
        _controller.play();
      }
    });
    _controller.setLooping(false);
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Dialog(
      backgroundColor: c.scrim,
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close bar
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton(
                icon: Icon(Icons.close_rounded, color: c.onScrim),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Video
            _initialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: c.primary),
                    ),
                  ),
            const SizedBox(height: 8),
            // Progress bar
            if (_initialized)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: c.primary,
                    backgroundColor: c.onScrim.withValues(alpha: 0.24),
                    bufferedColor: c.onScrim.withValues(alpha: 0.38),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // Play/Pause button
            if (_initialized)
              IconButton(
                icon: Icon(
                  _controller.value.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  color: c.onScrim,
                  size: 44,
                ),
                onPressed: () {
                  if (_controller.value.isPlaying) {
                    _controller.pause();
                  } else {
                    // Replay if ended
                    if (_controller.value.position >=
                        _controller.value.duration) {
                      _controller.seekTo(Duration.zero);
                    }
                    _controller.play();
                  }
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// A voice note's bubble. It owns no player: play/pause goes to the shared
/// [VoicePlaybackCoordinator], and the progress shown is the coordinator's
/// only while this note is the active one.
class _VoiceContent extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;
  final String timeStr;
  final VoicePlaybackCoordinator playback;

  const _VoiceContent({
    required this.message,
    required this.isMe,
    required this.timeStr,
    required this.playback,
  });

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;

    // Scoped to this bubble: a note starting elsewhere in the conversation
    // rebuilds the voice bubbles and nothing else — in particular it never
    // touches the scroll position.
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final isActive = playback.isActive(message.id);
        final isPlaying = playback.isPlayingMessage(message.id);
        final position = isActive ? playback.position : Duration.zero;
        // Falls back to the duration the API recorded, so a note that has
        // never been opened still shows its length.
        final fallback = message.durationSeconds;
        final total = isActive && playback.duration > Duration.zero
            ? playback.duration
            : (fallback != null && fallback > 0
                  ? Duration(milliseconds: (fallback * 1000).round())
                  : Duration.zero);

        final totalSecs = total.inSeconds;
        final progress = totalSecs > 0
            ? (position.inSeconds / totalSecs).clamp(0.0, 1.0)
            : 0.0;
        final durationLabel = total > Duration.zero
            ? _fmtDuration(total)
            : '--:--';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  key: Key('voice-play-${message.id}'),
                  onTap: () => playback.toggle(message),
                  child: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded,
                    size: 36,
                    color: isMe ? c.onPrimary : c.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: isMe
                            ? c.onPrimary.withValues(alpha: 0.3)
                            : c.surfaceSubtle,
                        valueColor: AlwaysStoppedAnimation(
                          isMe ? c.onPrimary : c.primary,
                        ),
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            durationLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe
                                  ? c.onPrimary.withValues(alpha: 0.72)
                                  : c.textSecondary,
                            ),
                          ),
                          _MessageTimestamp(
                            messageId: message.id,
                            timeStr: timeStr,
                            isMe: isMe,
                            isRead: message.seenAt != null,
                            color: isMe
                                ? c.onPrimary.withValues(alpha: 0.72)
                                : c.textSecondary,
                            fontSize: 10,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LocationContent extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;
  final String timeStr;
  const _LocationContent({
    required this.message,
    required this.isMe,
    required this.timeStr,
  });

  static const double _w = 220;
  static const double _mapH = 130;
  static const _radius = BorderRadius.all(Radius.circular(14));

  Future<void> _openMaps(BuildContext context) async {
    final lat = message.latitude;
    final lng = message.longitude;
    if (lat == null || lng == null) return;

    final uri = Platform.isIOS
        ? Uri.parse('https://maps.apple.com/?q=$lat,$lng')
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
          );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatCouldNotOpenMaps)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final hasCoords = message.latitude != null && message.longitude != null;
    final googleMapsKey = const String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    final lat = message.latitude;
    final lng = message.longitude;
    final markerColor = c.primary
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2);

    final staticMapUrl = (googleMapsKey.isNotEmpty && hasCoords)
        ? 'https://maps.googleapis.com/maps/api/staticmap'
              '?center=$lat,$lng'
              '&zoom=15'
              '&size=440x260'
              '&markers=color:0x$markerColor%7C$lat,$lng'
              '&key=$googleMapsKey'
        : null;

    return GestureDetector(
      onTap: () => _openMaps(context),
      child: Container(
        width: _w,
        decoration: BoxDecoration(
          color: isMe ? c.softTeal : c.surface,
          borderRadius: _radius,
          border: Border.all(color: c.border, width: 1),
        ),
        child: ClipRRect(
          borderRadius: _radius,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map area
              SizedBox(
                width: _w,
                height: _mapH,
                child: staticMapUrl != null
                    ? Image.network(
                        staticMapUrl,
                        width: _w,
                        height: _mapH,
                        fit: BoxFit.cover,
                        errorBuilder: (context, e, s) =>
                            _MapPlaceholder(isMe: isMe),
                      )
                    : _MapPlaceholder(isMe: isMe),
              ),
              // Label strip — thin, no extra background
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 13,
                            color: c.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              context.l10n.chatSharedLocation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MessageTimestamp(
                      messageId: message.id,
                      timeStr: timeStr,
                      isMe: isMe,
                      isRead: message.seenAt != null,
                      color: c.textSecondary,
                      fontSize: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  final bool isMe;
  const _MapPlaceholder({required this.isMe});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      color: isMe ? c.primaryPressed : c.surfaceSubtle,
      child: Stack(
        children: [
          // Simple grid lines to suggest a map
          CustomPaint(
            size: const Size(double.infinity, double.infinity),
            painter: _MapGridPainter(
              lineColor: isMe ? c.onPrimary : c.controlBorder,
            ),
          ),
          // Pin icon centered
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 36,
                  color: isMe ? c.onPrimary : c.primary,
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: (isMe ? c.onPrimary : c.primary).withValues(
                      alpha: 0.5,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  final Color lineColor;
  const _MapGridPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_MapGridPainter old) => old.lineColor != lineColor;
}

class _NewMessageIndicator extends StatelessWidget {
  const _NewMessageIndicator({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Material(
      key: const Key('new-message-indicator'),
      color: colors.surface,
      elevation: 3,
      shadowColor: colors.scrim.withValues(alpha: 0.16),
      shape: StadiumBorder(side: BorderSide(color: colors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  context.l10n.chatNewMessages(count),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                Icons.arrow_downward_rounded,
                size: 16,
                color: colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Attachment sheet ───────────────────────────────────────────────────────────

class _AttachmentSheet extends StatelessWidget {
  final VoidCallback onGalleryImage;
  final VoidCallback onGalleryVideo;
  final VoidCallback onCameraVideo;
  final VoidCallback onLocation;

  const _AttachmentSheet({
    required this.onGalleryImage,
    required this.onGalleryVideo,
    required this.onCameraVideo,
    required this.onLocation,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final c = context.semanticColors;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.controlBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 12 + bottomPadding),
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              // Taller than wide: a two-word label wraps to two lines on a
              // 320px screen, and a square cell has nowhere to put the second.
              childAspectRatio: 0.72,
              children: [
                _AttachOption(
                  icon: Icons.image_rounded,
                  label: context.l10n.chatAttachPhoto,
                  color: c.primary,
                  onTap: onGalleryImage,
                ),
                _AttachOption(
                  icon: Icons.videocam_rounded,
                  label: context.l10n.chatAttachVideo,
                  color: c.urgent,
                  onTap: onGalleryVideo,
                ),
                _AttachOption(
                  key: const Key('attach-camera-video'),
                  icon: Icons.videocam_rounded,
                  label: context.l10n.chatRecordVideo,
                  color: c.urgent,
                  onTap: onCameraVideo,
                ),
                _AttachOption(
                  icon: Icons.location_on_rounded,
                  label: context.l10n.chatAttachLocation,
                  color: c.success,
                  onTap: onLocation,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
