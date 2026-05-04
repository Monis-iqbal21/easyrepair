import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/services/chat_socket_service.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/chat_entities.dart';
import '../providers/chat_providers.dart';

class ChatDetailPage extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatDetailPage({super.key, required this.conversationId});

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
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  String? _recordingPath;
  AudioRecorder? _recorder;

  @override
  void initState() {
    super.initState();
    ChatSocketService.instance.joinConversation(widget.conversationId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Invalidate so the notifier re-fetches fresh messages every time this
      // screen is (re-)opened, instead of showing a stale cached list.
      ref.invalidate(chatMessagesProvider(widget.conversationId));
      _markLastSeen();
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recorder?.dispose();
    _controller.dispose();
    _scrollController.dispose();
    ChatSocketService.instance.leaveConversation(widget.conversationId);
    super.dispose();
  }

  // ── Seen ──────────────────────────────────────────────────────────────────

  void _markLastSeen() {
    if (!mounted) return;
    final messages =
        ref.read(chatMessagesProvider(widget.conversationId)).valueOrNull;
    if (messages == null || messages.isEmpty) return;
    final currentUserId = ref.read(authStateProvider).valueOrNull?.id ?? '';
    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.senderUserId != currentUserId && msg.seenAt == null) {
        ChatSocketService.instance.markSeen(widget.conversationId, msg.id);
        break;
      }
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
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Attachment sheet ──────────────────────────────────────────────────────

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttachmentSheet(
        onGalleryImage: () {
          Navigator.pop(context);
          _pickFromGallery(false);
        },
        onGalleryVideo: () {
          Navigator.pop(context);
          _pickFromGallery(true);
        },
        onVoiceNote: () {
          Navigator.pop(context);
          _startVoiceRecording();
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
      backgroundColor: Colors.transparent,
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
    if (isVideo) {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;
      final mime = file.mimeType ?? _mimeFromPath(file.path);
      await _sendMediaFile(file.path, mime);
    } else {
      final files = await _picker.pickMultiImage();
      if (files.isEmpty) return;
      setState(() => _isSendingAttachment = true);
      try {
        for (final file in files) {
          final mime = file.mimeType ?? _mimeFromPath(file.path);
          final result = await ref
              .read(chatRepositoryProvider)
              .sendMediaMessage(widget.conversationId, file.path, mime);
          result.fold(
            (failure) => _showError(failure.toString()),
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
    XFile? file;
    if (isVideo) {
      file = await _picker.pickVideo(source: ImageSource.camera);
    } else {
      file = await _picker.pickImage(source: ImageSource.camera);
    }
    if (file == null) return;
    final mime = file.mimeType ?? _mimeFromPath(file.path);
    await _sendMediaFile(file.path, mime);
  }

  Future<void> _sendMediaFile(String path, String mimeType) async {
    setState(() => _isSendingAttachment = true);
    try {
      final result = await ref
          .read(chatRepositoryProvider)
          .sendMediaMessage(widget.conversationId, path, mimeType);
      result.fold(
        (failure) => _showError(failure.toString()),
        (message) {
          ref
              .read(chatMessagesProvider(widget.conversationId).notifier)
              .append(message);
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        },
      );
    } finally {
      if (mounted) setState(() => _isSendingAttachment = false);
    }
  }

  // ── Voice recording ───────────────────────────────────────────────────────

  Future<void> _startVoiceRecording() async {
    final status = await Permission.microphone.request();
    if (status.isPermanentlyDenied) {
      _showError(
        'Microphone access is permanently denied. Enable it in Settings.',
      );
      openAppSettings();
      return;
    }
    if (!status.isGranted) {
      _showError('Microphone permission denied.');
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
      _recordingDuration = Duration.zero;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingDuration += const Duration(seconds: 1));
      }
    });
  }

  Future<void> _stopVoiceRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    final path = await _recorder?.stop();
    final filePath = path ?? _recordingPath;

    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });

    if (filePath != null) {
      await _sendVoiceFile(filePath);
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    await _recorder?.stop();

    if (_recordingPath != null) {
      try {
        final file = File(_recordingPath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });
  }

  Future<void> _sendVoiceFile(String path) async {
    setState(() => _isSendingAttachment = true);
    try {
      final result = await ref
          .read(chatRepositoryProvider)
          .sendVoiceMessage(widget.conversationId, path);
      result.fold(
        (failure) => _showError(failure.toString()),
        (message) {
          ref
              .read(chatMessagesProvider(widget.conversationId).notifier)
              .append(message);
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        },
      );
    } finally {
      if (mounted) setState(() => _isSendingAttachment = false);
    }
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _sendLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Location permission denied');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showError('Location permission permanently denied — enable in Settings');
      return;
    }

    setState(() => _isSendingAttachment = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final result = await ref
          .read(chatRepositoryProvider)
          .sendLocationMessage(
            widget.conversationId,
            position.latitude,
            position.longitude,
          );
      result.fold(
        (failure) => _showError(failure.toString()),
        (message) {
          ref
              .read(chatMessagesProvider(widget.conversationId).notifier)
              .append(message);
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        },
      );
    } catch (e) {
      _showError('Could not get location: $e');
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
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (canEdit)
                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFF1A1A1A),
                  ),
                  title: const Text('Edit message'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(message);
                  },
                ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444),
                ),
                title: const Text(
                  'Delete message',
                  style: TextStyle(color: Color(0xFFEF4444)),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: editController,
          maxLines: 5,
          minLines: 1,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Edit your message...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
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
            child: const Text('Save',
                style: TextStyle(
                    color: Color(0xFF1D9E75), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ).then((_) => editController.dispose());
  }

  Future<void> _doEdit(MessageEntity message, String newText) async {
    final result = await ref
        .read(chatRepositoryProvider)
        .editMessage(widget.conversationId, message.id, newText);
    result.fold(
      (failure) => _showError(failure.toString()),
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
      builder: (_) => AlertDialog(
        title: const Text('Delete message'),
        content:
            const Text('This message will be deleted for everyone in the chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      final result = await ref
          .read(chatRepositoryProvider)
          .deleteMessage(widget.conversationId, message.id);
      result.fold(
        (failure) => _showError(failure.toString()),
        (deleted) {
          ref
              .read(chatMessagesProvider(widget.conversationId).notifier)
              .markDeleted(deleted.id, deleted.deletedAt!);
        },
      );
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ParticipantTray(participant: participant),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final messagesAsync =
        ref.watch(chatMessagesProvider(widget.conversationId));
    final currentUserId =
        ref.watch(authStateProvider).valueOrNull?.id ?? '';

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

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1A1A1A), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: participant != null && participant.userId.isNotEmpty
              ? () => _showParticipantTray(context, participant)
              : null,
          child: Row(
            children: [
              _AppBarAvatar(
                avatarUrl: participant?.avatarUrl,
                initials: participant?.initials ?? '?',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  participant?.fullName.isNotEmpty == true
                      ? participant!.fullName
                      : 'Chat',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF1D9E75)),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Color(0xFFEF4444)),
                      const SizedBox(height: 12),
                      Text(err.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF6B7280))),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => ref
                            .read(chatMessagesProvider(widget.conversationId)
                                .notifier)
                            .refresh(),
                        child: const Text('Retry',
                            style: TextStyle(color: Color(0xFF1D9E75))),
                      ),
                    ],
                  ),
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Say hello!',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
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
                      horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderUserId == currentUserId;

                    final showSeparator = index == 0 ||
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
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(Color(0xFF1D9E75)),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('Uploading...',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF6B7280))),
                ],
              ),
            ),
          // Input or voice recording bar
          if (_isRecording)
            _VoiceRecordBar(
              duration: _recordingDuration,
              onStop: _stopVoiceRecording,
              onCancel: _cancelVoiceRecording,
            )
          else
            _InputBar(
              controller: _controller,
              isSending: _isSending,
              isAttachmentBusy: _isSendingAttachment,
              onSend: _send,
              onAttachmentTap: _showAttachmentSheet,
              onCameraTap: _showCameraSheet,
            ),
        ],
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
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                color: const Color(0xFFE2E8F0),
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
                      : 'User',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
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
    final url = participant.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 42,
        backgroundImage: NetworkImage(url),
        backgroundColor: const Color(0xFFE2E8F0),
      );
    }
    return CircleAvatar(
      radius: 42,
      backgroundColor: const Color(0xFF1D9E75),
      child: Text(
        participant.initials.isNotEmpty ? participant.initials : '?',
        style: const TextStyle(
          color: Colors.white,
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
    final filled = rating.floor();
    final hasHalf = (rating - filled) >= 0.25;
    final empty = 5 - filled - (hasHalf ? 1 : 0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < filled; i++)
          const Icon(Icons.star_rounded, size: 20, color: Color(0xFFF59E0B)),
        if (hasHalf)
          const Icon(Icons.star_half_rounded,
              size: 20, color: Color(0xFFF59E0B)),
        for (int i = 0; i < empty; i++)
          const Icon(Icons.star_outline_rounded,
              size: 20, color: Color(0xFFD1D5DB)),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const Text(' / 5',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
      ],
    );
  }
}

// ── AppBar avatar ─────────────────────────────────────────────────────────────

class _AppBarAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  const _AppBarAvatar({this.avatarUrl, required this.initials});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: const Color(0xFFE2E8F0),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFF1D9E75),
      child: Text(
        initials.isNotEmpty ? initials : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
          const SizedBox(width: 10),
          Text(
            _formatDate(isoString),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
        ],
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(dt.year, dt.month, dt.day);
      if (msgDay == today) return 'Today';
      if (today.difference(msgDay).inDays == 1) return 'Yesterday';
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
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
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.text ?? '',
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
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
    final timeStr = _fmt(message.createdAt);

    // Image/video content expands without inner padding
    final isMediaFull = !message.isDeleted &&
        (message.type == ChatMessageType.image ||
            message.type == ChatMessageType.video);

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 16),
    );

    return GestureDetector(
      onLongPress: () => onLongPress(message),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(
                top: 4,
                bottom: showSeen ? 2 : 4,
                left: isMe ? 64 : 0,
                right: isMe ? 0 : 64,
              ),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF1D9E75) : Colors.white,
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: borderRadius,
                child: isMediaFull
                    ? _buildContent(context, timeStr)
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: _buildContent(context, timeStr),
                      ),
              ),
            ),
            if (showSeen)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, right: 4),
                child: Text(
                  'Seen',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8).withValues(alpha: 0.85),
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
                  ? Colors.white.withValues(alpha: 0.7)
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 4),
            Text(
              'This message was deleted',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.8)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          timeStr,
          style: TextStyle(
            fontSize: 11,
            color: isMe
                ? Colors.white.withValues(alpha: 0.6)
                : const Color(0xFF94A3B8),
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
  const _TextContent(
      {required this.message, required this.isMe, required this.timeStr});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.text ?? '',
          style: TextStyle(
            fontSize: 14,
            color: isMe ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.editedAt != null)
              Text(
                'edited  ',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.65)
                      : const Color(0xFF94A3B8),
                ),
              ),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 11,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.75)
                    : const Color(0xFF94A3B8),
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
  const _ImageContent(
      {required this.message, required this.isMe, required this.timeStr});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240, minWidth: 120),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _showFullScreen(context, message.mediaUrl!),
            child: Image.network(
              message.mediaUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return SizedBox(
                  height: 160,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                      color: const Color(0xFF1D9E75),
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => SizedBox(
                height: 120,
                child: Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    size: 36,
                    color: isMe
                        ? Colors.white54
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 11,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.75)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreen(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
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
  const _VideoContent(
      {required this.message, required this.isMe, required this.timeStr});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240, minWidth: 120),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _openPlayer(context),
            child: Container(
              height: 160,
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle_fill_rounded,
                      size: 52,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap to play',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 11,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.75)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPlayer(BuildContext context) {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black,
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
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close bar
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Video
            _initialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1D9E75),
                      ),
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
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFF1D9E75),
                    backgroundColor: Colors.white24,
                    bufferedColor: Colors.white38,
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
                  color: Colors.white,
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
    final isPlaying = _playerState == PlayerState.playing;
    final totalSecs = _total.inSeconds;
    final posSecs = _position.inSeconds;
    final progress = totalSecs > 0 ? (posSecs / totalSecs).clamp(0.0, 1.0) : 0.0;
    final durationLabel = _total > Duration.zero ? _fmtDuration(_total) : '--:--';

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
                color: widget.isMe ? Colors.white : const Color(0xFF1D9E75),
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
                        ? Colors.white.withValues(alpha: 0.3)
                        : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation(
                      widget.isMe ? Colors.white : const Color(0xFF1D9E75),
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
                              ? Colors.white.withValues(alpha: 0.7)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      Text(
                        widget.timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isMe
                              ? Colors.white.withValues(alpha: 0.7)
                              : const Color(0xFF94A3B8),
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
  const _LocationContent(
      {required this.message, required this.isMe, required this.timeStr});

  Future<void> _openMaps(BuildContext context) async {
    final lat = message.latitude;
    final lng = message.longitude;
    if (lat == null || lng == null) return;

    final uri = Platform.isIOS
        ? Uri.parse('https://maps.apple.com/?q=$lat,$lng')
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = message.latitude?.toStringAsFixed(5) ?? '—';
    final lng = message.longitude?.toStringAsFixed(5) ?? '—';

    return GestureDetector(
      onTap: () => _openMaps(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: isMe ? Colors.white : const Color(0xFF1D9E75),
                ),
                const SizedBox(width: 4),
                Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isMe ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$lat, $lng',
              style: TextStyle(
                fontSize: 12,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.75)
                    : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Tap to open in Maps',
              style: TextStyle(
                fontSize: 11,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.55)
                    : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 11,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.75)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final bool isAttachmentBusy;
  final VoidCallback onSend;
  final VoidCallback onAttachmentTap;
  final VoidCallback onCameraTap;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.isAttachmentBusy,
    required this.onSend,
    required this.onAttachmentTap,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(8, 10, 8, 10 + bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Attachment (+) button
          _IconBtn(
            icon: Icons.add_rounded,
            color: isAttachmentBusy
                ? const Color(0xFF94A3B8)
                : const Color(0xFF6B7280),
            onTap: isAttachmentBusy ? null : onAttachmentTap,
          ),
          const SizedBox(width: 4),
          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                maxLines: 5,
                minLines: 1,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A1A1A),
                ),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle:
                      TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Camera button
          _IconBtn(
            icon: Icons.camera_alt_rounded,
            color: isAttachmentBusy
                ? const Color(0xFF94A3B8)
                : const Color(0xFF6B7280),
            onTap: isAttachmentBusy ? null : onCameraTap,
          ),
          const SizedBox(width: 4),
          // Send button
          GestureDetector(
            onTap: isSending ? null : onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSending
                    ? const Color(0xFF1D9E75).withValues(alpha: 0.5)
                    : const Color(0xFF1D9E75),
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
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

// ── Voice record bar ──────────────────────────────────────────────────────────

class _VoiceRecordBar extends StatelessWidget {
  final Duration duration;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  const _VoiceRecordBar({
    required this.duration,
    required this.onStop,
    required this.onCancel,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Pulsing red dot
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Recording  ${_fmt(duration)}',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // Cancel
          TextButton(
            onPressed: onCancel,
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
          ),
          const SizedBox(width: 4),
          // Stop & send
          GestureDetector(
            onTap: onStop,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1D9E75),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Send',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Attachment sheet ───────────────────────────────────────────────────────────

class _AttachmentSheet extends StatelessWidget {
  final VoidCallback onGalleryImage;
  final VoidCallback onGalleryVideo;
  final VoidCallback onVoiceNote;
  final VoidCallback onLocation;

  const _AttachmentSheet({
    required this.onGalleryImage,
    required this.onGalleryVideo,
    required this.onVoiceNote,
    required this.onLocation,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                color: const Color(0xFFE2E8F0),
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
                  label: 'Photo',
                  color: const Color(0xFF3B82F6),
                  onTap: onGalleryImage,
                ),
                _AttachOption(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  color: const Color(0xFF8B5CF6),
                  onTap: onGalleryVideo,
                ),
                _AttachOption(
                  icon: Icons.mic_rounded,
                  label: 'Voice',
                  color: const Color(0xFF10B981),
                  onTap: onVoiceNote,
                ),
                _AttachOption(
                  icon: Icons.location_on_rounded,
                  label: 'Location',
                  color: const Color(0xFF1D9E75),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                color: const Color(0xFFE2E8F0),
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
                  label: 'Take Photo',
                  color: const Color(0xFF1A1A1A),
                  onTap: onPhoto,
                ),
                _AttachOption(
                  icon: Icons.videocam_rounded,
                  label: 'Record Video',
                  color: const Color(0xFF8B5CF6),
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
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
