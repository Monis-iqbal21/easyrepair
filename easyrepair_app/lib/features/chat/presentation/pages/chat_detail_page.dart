import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
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
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/notifications/presentation/providers/notification_providers.dart';
import '../../domain/entities/chat_entities.dart';
import '../providers/chat_providers.dart';
import 'chat_list_page.dart' show kSupportAvatarAsset;

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
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  bool _isSending = false;
  bool _isSendingAttachment = false;
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  String? _recordingPath;
  AudioRecorder? _recorder;
  StreamSubscription<Amplitude>? _amplitudeSub;
  final List<double> _amplitudeBars = [];

  @override
  void initState() {
    super.initState();
    ChatSocketService.instance.joinConversation(widget.conversationId);
    _controller.addListener(_onTextChanged);
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

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _amplitudeSub?.cancel();
    _recorder?.dispose();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    ChatSocketService.instance.leaveConversation(widget.conversationId);
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
        ChatSocketService.instance.markSeen(widget.conversationId, msg.id);
        markedAny = true;
        break;
      }
    }
    if (markedAny) {
      // Clear chat unread counts and any related notification badges.
      ref.invalidate(chatConversationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
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
        onLocation: () {
          Navigator.pop(context);
          _sendLocation();
        },
      ),
    );
  }

  void _showCameraSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.semanticColors.surface.withValues(alpha: 0),
      builder: (_) => _CameraSheet(
        onPhoto: () {
          Navigator.pop(context);
          _captureFromCamera(false);
        },
        onVideo: () {
          Navigator.pop(context);
          _captureFromCamera(true);
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

    setState(() {
      _isRecording = true;
      _isPaused = false;
      _recordingDuration = Duration.zero;
      _amplitudeBars.clear();
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingDuration += const Duration(seconds: 1));
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
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordingDuration += const Duration(seconds: 1));
        }
      });
      setState(() => _isPaused = false);
    } else {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      await _recorder!.pause();
      setState(() => _isPaused = true);
    }
  }

  Future<void> _stopVoiceRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    final path = await _recorder?.stop();
    final filePath = path ?? _recordingPath;

    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordingDuration = Duration.zero;
      _amplitudeBars.clear();
    });

    if (filePath != null) {
      await _sendVoiceFile(filePath);
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    // cancel() stops the recorder and deletes the underlying temp file.
    await _recorder?.cancel();

    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordingDuration = Duration.zero;
      _amplitudeBars.clear();
    });
  }

  Future<void> _sendVoiceFile(String path) async {
    // Re-entry guard: an attachment send already in flight must never submit
    // the same recorded voice note twice from an accidental repeated tap.
    if (_isSendingAttachment) return;
    setState(() => _isSendingAttachment = true);
    try {
      final result = await ref
          .read(chatRepositoryProvider)
          .sendVoiceMessage(widget.conversationId, path);
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
    final messagesAsync = ref.watch(
      chatMessagesProvider(widget.conversationId),
    );
    final isShowingCachedData =
        ref.watch(chatMessagesIsOfflineProvider(widget.conversationId)) &&
        messagesAsync.hasValue;
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.id ?? '';

    ref.listen(chatMessagesProvider(widget.conversationId), (_, next) {
      if (next.hasValue) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _markLastSeen());
      }
    });

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
    final canPop = Navigator.canPop(context);

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
      // True whenever real history exists, so the Android system back button
      // and the browser back button are handled by the framework and are not
      // intercepted at all.
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) handleBack();
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
              child: messagesAsync.when(
                loading: () =>
                    Center(child: CircularProgressIndicator(color: c.primary)),
                error: (err, _) => isResourceUnavailableFailure(err)
                    ? ResourceUnavailableView(
                        message: context.l10n.resourceConversationUnavailable,
                        actionLabel: context.l10n.goToChatsAction,
                        onAction: () => context.go(
                          ref.read(authStateProvider).valueOrNull?.isWorker ==
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
                        style: TextStyle(color: c.textSecondary, fontSize: 14),
                      ),
                    );
                  }

                  int lastSeenSentIndex = -1;
                  for (int i = messages.length - 1; i >= 0; i--) {
                    if (messages[i].senderUserId == currentUserId &&
                        messages[i].seenAt != null) {
                      lastSeenSentIndex = i;
                      break;
                    }
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
                                  showSeen: isMe && index == lastSeenSentIndex,
                                  onLongPress: (msg) =>
                                      _showMessageActions(msg, currentUserId),
                                ),
                        ],
                      );
                    },
                  );
                },
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
            // WhatsApp-style input bar: text field <-> recording bar, mic <-> send.
            _ChatInputBar(
              controller: _controller,
              isSending: _isSending,
              isAttachmentBusy: _isSendingAttachment,
              isRecording: _isRecording,
              isPaused: _isPaused,
              recordingDuration: _recordingDuration,
              amplitudeBars: _amplitudeBars,
              onSendText: _send,
              onAttachmentTap: _showAttachmentSheet,
              onCameraTap: _showCameraSheet,
              onStartRecording: _startVoiceRecording,
              onCancelRecording: _cancelVoiceRecording,
              onSendRecording: _stopVoiceRecording,
              onTogglePauseResume: _togglePauseResumeRecording,
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
      return Container(
        width: 38,
        height: 38,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c.surface,
          shape: BoxShape.circle,
          border: Border.all(color: c.border),
        ),
        child: ClipOval(
          child: Image.asset(kSupportAvatarAsset, fit: BoxFit.contain),
        ),
      );
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
  final bool showSeen;
  final void Function(MessageEntity) onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.onLongPress,
    this.showSeen = false,
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
                bottom: showSeen ? 2 : 4,
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
            if (showSeen)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, right: 4),
                child: Text(
                  context.l10n.chatSeen,
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, String timeStr) {
    if (message.isDeleted) {
      return _DeletedContent(isMe: isMe, timeStr: timeStr);
    }
    switch (message.type) {
      case ChatMessageType.image:
        return _ImageContent(message: message, isMe: isMe, timeStr: timeStr);
      case ChatMessageType.video:
        return _VideoContent(message: message, isMe: isMe, timeStr: timeStr);
      case ChatMessageType.voice:
        return _VoiceContent(message: message, isMe: isMe, timeStr: timeStr);
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

class _DeletedContent extends StatelessWidget {
  final bool isMe;
  final String timeStr;
  const _DeletedContent({required this.isMe, required this.timeStr});

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
        Text(
          timeStr,
          style: TextStyle(
            fontSize: 11,
            color: isMe ? c.onPrimary.withValues(alpha: 0.65) : c.textSecondary,
          ),
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
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 11,
                color: isMe
                    ? c.onPrimary.withValues(alpha: 0.75)
                    : c.textSecondary,
              ),
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
                  child: Text(
                    timeStr,
                    style: TextStyle(fontSize: 10, color: c.onScrim),
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
                  child: Text(
                    timeStr,
                    style: TextStyle(fontSize: 10, color: c.onScrim),
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

class _VoiceContent extends StatefulWidget {
  final MessageEntity message;
  final bool isMe;
  final String timeStr;

  const _VoiceContent({
    required this.message,
    required this.isMe,
    required this.timeStr,
  });

  @override
  State<_VoiceContent> createState() => _VoiceContentState();
}

class _VoiceContentState extends State<_VoiceContent> {
  final _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  late StreamSubscription<PlayerState> _stateSub;
  late StreamSubscription<Duration> _positionSub;
  late StreamSubscription<Duration> _durationSub;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });
    _positionSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durationSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _total = d);
    });
  }

  @override
  void dispose() {
    _stateSub.cancel();
    _positionSub.cancel();
    _durationSub.cancel();
    _player.dispose();
    super.dispose();
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final isPlaying = _playerState == PlayerState.playing;
    final totalSecs = _total.inSeconds;
    final posSecs = _position.inSeconds;
    final progress = totalSecs > 0
        ? (posSecs / totalSecs).clamp(0.0, 1.0)
        : 0.0;
    final durationLabel = _total > Duration.zero
        ? _fmtDuration(_total)
        : '--:--';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 180),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () async {
                if (isPlaying) {
                  await _player.pause();
                } else if (_playerState == PlayerState.paused) {
                  await _player.resume();
                } else {
                  await _player.play(UrlSource(widget.message.mediaUrl!));
                }
              },
              child: Icon(
                isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                size: 36,
                color: widget.isMe ? c.onPrimary : c.primary,
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
                    backgroundColor: widget.isMe
                        ? c.onPrimary.withValues(alpha: 0.3)
                        : c.surfaceSubtle,
                    valueColor: AlwaysStoppedAnimation(
                      widget.isMe ? c.onPrimary : c.primary,
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
                          color: widget.isMe
                              ? c.onPrimary.withValues(alpha: 0.72)
                              : c.textSecondary,
                        ),
                      ),
                      Text(
                        widget.timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isMe
                              ? c.onPrimary.withValues(alpha: 0.72)
                              : c.textSecondary,
                        ),
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
                    Text(
                      timeStr,
                      style: TextStyle(fontSize: 10, color: c.textSecondary),
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

// ── Chat input bar (WhatsApp-style: text/mic <-> recording/send) ──────────────

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final bool isAttachmentBusy;
  final bool isRecording;
  final bool isPaused;
  final Duration recordingDuration;
  final List<double> amplitudeBars;
  final VoidCallback onSendText;
  final VoidCallback onAttachmentTap;
  final VoidCallback onCameraTap;
  final VoidCallback onStartRecording;
  final VoidCallback onCancelRecording;
  final VoidCallback onSendRecording;
  final VoidCallback onTogglePauseResume;

  const _ChatInputBar({
    required this.controller,
    required this.isSending,
    required this.isAttachmentBusy,
    required this.isRecording,
    required this.isPaused,
    required this.recordingDuration,
    required this.amplitudeBars,
    required this.onSendText,
    required this.onAttachmentTap,
    required this.onCameraTap,
    required this.onStartRecording,
    required this.onCancelRecording,
    required this.onSendRecording,
    required this.onTogglePauseResume,
  });

  void _onActionTap() {
    if (isRecording) {
      onSendRecording();
      return;
    }
    if (controller.text.trim().isNotEmpty) {
      onSendText();
      return;
    }
    onStartRecording();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final hasText = controller.text.trim().isNotEmpty;
    final c = context.semanticColors;

    return Container(
      padding: EdgeInsets.fromLTRB(8, 10, 8, 10 + bottomPadding),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          if (!isRecording) ...[
            // Attachment (+) button
            _IconBtn(
              icon: Icons.add_rounded,
              color: isAttachmentBusy ? c.disabled : c.textSecondary,
              onTap: isAttachmentBusy ? null : onAttachmentTap,
            ),
            const SizedBox(width: 4),
          ],
          // Text field <-> recording bar
          Expanded(
            child: isRecording
                ? _RecordingBar(
                    duration: recordingDuration,
                    isPaused: isPaused,
                    amplitudeBars: amplitudeBars,
                    onCancel: onCancelRecording,
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: c.controlBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => onSendText(),
                            maxLines: 5,
                            minLines: 1,
                            style: TextStyle(
                              fontSize: 14,
                              color: c.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: context.l10n.chatComposerHint,
                              hintStyle: TextStyle(
                                color: c.textSecondary,
                                fontSize: 14,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        // Camera button
                        _IconBtn(
                          icon: Icons.camera_alt_rounded,
                          color: isAttachmentBusy
                              ? c.disabled
                              : c.textSecondary,
                          onTap: isAttachmentBusy ? null : onCameraTap,
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: 4),
          // Pause/resume button — only while recording
          if (isRecording) ...[
            GestureDetector(
              onTap: onTogglePauseResume,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.controlBorder),
                ),
                child: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: c.primary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          // Mic / Send circular action button
          GestureDetector(
            onTap: isSending ? null : _onActionTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSending ? c.primary.withValues(alpha: 0.5) : c.primary,
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.onPrimary,
                      ),
                    )
                  : Icon(
                      isRecording || hasText
                          ? Icons.send_rounded
                          : Icons.mic_rounded,
                      color: c.onPrimary,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _IconBtn({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 24, color: color),
      ),
    );
  }
}

// ── Recording bar (replaces the text field while recording) ───────────────────

class _RecordingBar extends StatelessWidget {
  final Duration duration;
  final bool isPaused;
  final List<double> amplitudeBars;
  final VoidCallback onCancel;

  const _RecordingBar({
    required this.duration,
    required this.isPaused,
    required this.amplitudeBars,
    required this.onCancel,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      height: 46,
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
                fontFeatures: [FontFeature.tabularFigures()],
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
  final List<double> bars;
  const _Waveform({required this.bars});

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

// ── Attachment sheet ───────────────────────────────────────────────────────────

class _AttachmentSheet extends StatelessWidget {
  final VoidCallback onGalleryImage;
  final VoidCallback onGalleryVideo;
  final VoidCallback onLocation;

  const _AttachmentSheet({
    required this.onGalleryImage,
    required this.onGalleryVideo,
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

class _CameraSheet extends StatelessWidget {
  final VoidCallback onPhoto;
  final VoidCallback onVideo;

  const _CameraSheet({required this.onPhoto, required this.onVideo});

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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachOption(
                  icon: Icons.camera_alt_rounded,
                  label: context.l10n.chatTakePhoto,
                  color: c.primary,
                  onTap: onPhoto,
                ),
                _AttachOption(
                  icon: Icons.videocam_rounded,
                  label: context.l10n.chatRecordVideo,
                  color: c.urgent,
                  onTap: onVideo,
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: c.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
