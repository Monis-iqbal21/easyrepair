import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/chat_entities.dart';

/// The audio operations the coordinator needs, behind an interface so tests
/// can drive playback deterministically instead of waiting on a real device.
abstract class VoiceAudioPlayer {
  Stream<Duration> get onPositionChanged;
  Stream<Duration> get onDurationChanged;

  /// Fires when the current source reaches its end — the signal the auto-play
  /// chain advances on.
  Stream<void> get onPlayerComplete;

  Future<void> play(String url);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> release();
}

/// The real player, backed by `audioplayers`.
class AudioPlayersVoicePlayer implements VoiceAudioPlayer {
  AudioPlayersVoicePlayer([AudioPlayer? player])
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;

  @override
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;

  @override
  Stream<void> get onPlayerComplete => _player.onPlayerComplete;

  @override
  Future<void> play(String url) => _player.play(UrlSource(url));

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> release() => _player.dispose();
}

/// True when [message] is a voice note this conversation can actually play.
///
/// A deleted note, or one whose upload left no URL behind, is not playable —
/// the chain stops at it rather than trying and failing.
bool isPlayableVoiceMessage(MessageEntity message) =>
    message.type == ChatMessageType.voice &&
    !message.isDeleted &&
    (message.mediaUrl?.isNotEmpty ?? false);

/// Plays the conversation's voice notes through a single player, and walks
/// forward through consecutive voice notes once one finishes.
///
/// One player, one active message: starting anything stops whatever was
/// playing, so two notes can never sound at once. Every voice bubble reads its
/// state from here rather than owning a player of its own.
///
/// The chain only ever advances by *one* position in the rendered message
/// list. A text, image or unplayable note in the next slot ends it — the chain
/// never skips ahead looking for more audio.
class VoicePlaybackCoordinator extends ChangeNotifier {
  VoicePlaybackCoordinator({VoiceAudioPlayer? player})
    : _player = player ?? AudioPlayersVoicePlayer() {
    _completeSub = _player.onPlayerComplete.listen((_) => _handleComplete());
    _positionSub = _player.onPositionChanged.listen((p) {
      _position = p;
      notifyListeners();
    });
    _durationSub = _player.onDurationChanged.listen((d) {
      _duration = d;
      notifyListeners();
    });
  }

  final VoiceAudioPlayer _player;
  late final StreamSubscription<void> _completeSub;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration> _durationSub;

  /// Supplies the conversation exactly as it is currently rendered, so "the
  /// next message" is read off the live list. Pagination prepends older pages
  /// and shifts every index, which is why nothing here caches one.
  List<MessageEntity> Function()? _messagesSource;

  String? _activeMessageId;
  bool _isPlaying = false;
  bool _chainActive = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _disposed = false;

  /// The note currently loaded — playing or paused. Null when nothing is.
  String? get activeMessageId => _activeMessageId;

  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;

  /// True while an auto-play chain is running, i.e. a completed note will hand
  /// over to the next one. Cleared by any manual interruption.
  @visibleForTesting
  bool get isChainActive => _chainActive;

  bool isActive(String messageId) => _activeMessageId == messageId;

  bool isPlayingMessage(String messageId) =>
      _isPlaying && _activeMessageId == messageId;

  void bindMessages(List<MessageEntity> Function() source) {
    _messagesSource = source;
  }

  /// The play/pause control on a voice bubble.
  ///
  /// Playing a note the user was not already on starts a *new* chain — the
  /// previous one is abandoned, not resumed.
  Future<void> toggle(MessageEntity message) async {
    if (!isPlayableVoiceMessage(message)) return;

    if (isPlayingMessage(message.id)) {
      await _pause();
      return;
    }
    if (isActive(message.id)) {
      await _resume();
      return;
    }
    await _start(message);
  }

  Future<void> _start(MessageEntity message) async {
    // A manual start is always the head of a fresh chain.
    _chainActive = true;
    await _play(message);
  }

  Future<void> _play(MessageEntity message) async {
    _activeMessageId = message.id;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isPlaying = true;
    _notify();
    try {
      // stop() first so the single player is never asked to hold two sources.
      await _player.stop();
      await _player.play(message.mediaUrl!);
    } catch (_) {
      // A note that will not load ends the chain rather than skipping past it.
      _reset();
    }
  }

  Future<void> _pause() async {
    // A manual pause takes the user off the chain: resuming later plays this
    // note to its end and stops there.
    _chainActive = false;
    _isPlaying = false;
    _notify();
    try {
      await _player.pause();
    } catch (_) {
      _reset();
    }
  }

  Future<void> _resume() async {
    _isPlaying = true;
    _notify();
    try {
      await _player.resume();
    } catch (_) {
      _reset();
    }
  }

  /// Stops playback outright and abandons any chain — for a manual stop, or
  /// for leaving the conversation.
  Future<void> stop() async {
    _chainActive = false;
    _reset();
    try {
      await _player.stop();
    } catch (_) {
      // Already gone; the state above is what matters.
    }
  }

  void _handleComplete() {
    final finished = _activeMessageId;
    _isPlaying = false;
    _position = _duration;
    _notify();

    if (finished == null || !_chainActive) {
      _chainActive = false;
      return;
    }

    final next = _nextMessageAfter(finished);
    if (next == null || !isPlayableVoiceMessage(next)) {
      // Either the conversation ends here, or the next message is not a
      // playable voice note. Both stop the chain where it stands.
      _chainActive = false;
      _notify();
      return;
    }
    unawaited(_play(next));
  }

  /// The message immediately after [messageId] — one step, no searching.
  MessageEntity? _nextMessageAfter(String messageId) {
    final messages = _messagesSource?.call();
    if (messages == null) return null;
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index < 0 || index + 1 >= messages.length) return null;
    return messages[index + 1];
  }

  void _reset() {
    _activeMessageId = null;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _completeSub.cancel();
    _positionSub.cancel();
    _durationSub.cancel();
    _player.release();
    super.dispose();
  }
}
