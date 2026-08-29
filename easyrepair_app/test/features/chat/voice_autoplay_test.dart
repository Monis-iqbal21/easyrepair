import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:handygo_app/core/data/cached_result.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:handygo_app/features/chat/domain/entities/chat_entities.dart';
import 'package:handygo_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:handygo_app/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:handygo_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:handygo_app/features/chat/presentation/widgets/voice_playback_coordinator.dart';

import '../../support/l10n_test_app.dart';

/// Consecutive voice notes chain: finishing one starts the next, and only the
/// next. A text message between two notes ends the chain, and any manual
/// interruption abandons it. One player throughout, so two notes can never
/// sound at once.

const _conversationId = 'conversation-1';

class _ClientAuthNotifier extends AuthStateNotifier {
  @override
  Future<UserEntity?> build() async => const UserEntity(
    id: 'me',
    phone: '+923000000000',
    role: 'CLIENT',
    firstName: 'Sara',
    lastName: 'Khan',
  );
}

/// Records every call and lets a test decide exactly when a note "finishes",
/// so the chain is exercised without waiting on real audio.
class _FakeVoicePlayer implements VoiceAudioPlayer {
  final _complete = StreamController<void>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();

  final List<String> played = [];
  final List<String> calls = [];

  /// URLs that throw on play, standing in for a note that will not load.
  final Set<String> failingUrls = {};

  /// How many sources the player is holding at once — the guard against two
  /// notes sounding together.
  int concurrentSources = 0;
  int maxConcurrentSources = 0;

  @override
  Stream<void> get onPlayerComplete => _complete.stream;

  @override
  Stream<Duration> get onPositionChanged => _position.stream;

  @override
  Stream<Duration> get onDurationChanged => _duration.stream;

  @override
  Future<void> play(String url) async {
    calls.add('play:$url');
    if (failingUrls.contains(url)) {
      throw Exception('cannot load $url');
    }
    played.add(url);
    concurrentSources++;
    maxConcurrentSources = concurrentSources > maxConcurrentSources
        ? concurrentSources
        : maxConcurrentSources;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    concurrentSources = 0;
  }

  @override
  Future<void> release() async {
    calls.add('release');
    concurrentSources = 0;
    _complete.close();
    _position.close();
    _duration.close();
  }

  /// The current note reaches its end.
  void finish() {
    concurrentSources = 0;
    _complete.add(null);
  }

  void emitDuration(Duration d) => _duration.add(d);
}

MessageEntity _voice(String id, {String? url = 'https://cdn.invalid/v.m4a'}) =>
    MessageEntity(
      id: id,
      conversationId: _conversationId,
      senderUserId: 'other',
      senderRole: 'WORKER',
      type: ChatMessageType.voice,
      mediaUrl: url,
      durationSeconds: 5,
      createdAt: '2026-08-20T10:00:00.000Z',
      updatedAt: '2026-08-20T10:00:00.000Z',
    );

MessageEntity _deletedVoice(String id) => MessageEntity(
  id: id,
  conversationId: _conversationId,
  senderUserId: 'other',
  senderRole: 'WORKER',
  type: ChatMessageType.voice,
  mediaUrl: 'https://cdn.invalid/gone.m4a',
  deletedAt: '2026-08-20T10:01:00.000Z',
  createdAt: '2026-08-20T10:00:00.000Z',
  updatedAt: '2026-08-20T10:00:00.000Z',
);

MessageEntity _text(String id) => MessageEntity(
  id: id,
  conversationId: _conversationId,
  senderUserId: 'other',
  senderRole: 'WORKER',
  type: ChatMessageType.text,
  text: 'A written reply',
  createdAt: '2026-08-20T10:00:00.000Z',
  updatedAt: '2026-08-20T10:00:00.000Z',
);

String _url(String id) => 'https://cdn.invalid/$id.m4a';

/// Builds a coordinator over a fixed conversation, the way the page does.
(VoicePlaybackCoordinator, _FakeVoicePlayer) _coordinator(
  List<MessageEntity> messages,
) {
  final player = _FakeVoicePlayer();
  final coordinator = VoicePlaybackCoordinator(player: player);
  coordinator.bindMessages(() => messages);
  addTearDown(coordinator.dispose);
  return (coordinator, player);
}

void main() {
  group('isPlayableVoiceMessage', () {
    test('a text message is never playable', () {
      expect(isPlayableVoiceMessage(_text('t1')), isFalse);
    });

    test('a deleted voice note is not playable', () {
      expect(isPlayableVoiceMessage(_deletedVoice('v1')), isFalse);
    });

    test('a voice note with no media URL is not playable', () {
      expect(isPlayableVoiceMessage(_voice('v1', url: null)), isFalse);
      expect(isPlayableVoiceMessage(_voice('v1', url: '')), isFalse);
    });

    test('an ordinary voice note is playable', () {
      expect(isPlayableVoiceMessage(_voice('v1')), isTrue);
    });
  });

  group('chaining', () {
    test('finishing voice 1 starts voice 2', () async {
      final messages = [
        _voice('v1', url: _url('v1')),
        _voice('v2', url: _url('v2')),
      ];
      final (coordinator, player) = _coordinator(messages);

      await coordinator.toggle(messages[0]);
      expect(player.played, [_url('v1')]);
      expect(coordinator.activeMessageId, 'v1');

      player.finish();
      await Future<void>.delayed(Duration.zero);

      expect(player.played, [_url('v1'), _url('v2')]);
      expect(coordinator.activeMessageId, 'v2');
      expect(coordinator.isPlaying, isTrue);
    });

    test('voice 1 chains through voice 2 into voice 3', () async {
      final messages = [
        _voice('v1', url: _url('v1')),
        _voice('v2', url: _url('v2')),
        _voice('v3', url: _url('v3')),
      ];
      final (coordinator, player) = _coordinator(messages);

      await coordinator.toggle(messages[0]);
      player.finish();
      await Future<void>.delayed(Duration.zero);
      player.finish();
      await Future<void>.delayed(Duration.zero);

      expect(player.played, [_url('v1'), _url('v2'), _url('v3')]);
      expect(coordinator.activeMessageId, 'v3');
    });

    test('a text message between two notes ends the chain', () async {
      // Voice 1 → Voice 2 → Voice 3 → Text → Voice 4.
      final messages = [
        _voice('v1', url: _url('v1')),
        _voice('v2', url: _url('v2')),
        _voice('v3', url: _url('v3')),
        _text('t1'),
        _voice('v4', url: _url('v4')),
      ];
      final (coordinator, player) = _coordinator(messages);

      await coordinator.toggle(messages[0]);
      for (var i = 0; i < 4; i++) {
        player.finish();
        await Future<void>.delayed(Duration.zero);
      }

      // Stops at v3. v4 is never reached — the chain does not skip the text.
      expect(player.played, [_url('v1'), _url('v2'), _url('v3')]);
      expect(player.played, isNot(contains(_url('v4'))));
      expect(coordinator.isPlaying, isFalse);
      expect(coordinator.isChainActive, isFalse);
    });

    test('the chain stops at the end of the conversation', () async {
      final messages = [_voice('v1', url: _url('v1'))];
      final (coordinator, player) = _coordinator(messages);

      await coordinator.toggle(messages[0]);
      player.finish();
      await Future<void>.delayed(Duration.zero);

      expect(player.played, [_url('v1')]);
      expect(coordinator.isPlaying, isFalse);
    });

    test(
      'the next note is read off the live list, not a cached index',
      () async {
        // Pagination prepends an older page, shifting every index. The chain
        // must still find the note that follows v1.
        final messages = [
          _voice('v1', url: _url('v1')),
          _voice('v2', url: _url('v2')),
        ];
        final player = _FakeVoicePlayer();
        final coordinator = VoicePlaybackCoordinator(player: player);
        addTearDown(coordinator.dispose);
        coordinator.bindMessages(() => messages);

        await coordinator.toggle(messages[0]);
        messages.insertAll(0, [_text('older-1'), _text('older-2')]);

        player.finish();
        await Future<void>.delayed(Duration.zero);

        expect(player.played, [_url('v1'), _url('v2')]);
      },
    );
  });

  group('manual interruption', () {
    test('a manual pause abandons the chain', () async {
      final messages = [
        _voice('v1', url: _url('v1')),
        _voice('v2', url: _url('v2')),
      ];
      final (coordinator, player) = _coordinator(messages);

      await coordinator.toggle(messages[0]);
      await coordinator.toggle(messages[0]); // pause
      expect(coordinator.isPlaying, isFalse);
      expect(coordinator.isChainActive, isFalse);

      // Resuming plays this note to its end and stops there.
      await coordinator.toggle(messages[0]);
      expect(player.calls, contains('resume'));
      player.finish();
      await Future<void>.delayed(Duration.zero);

      expect(player.played, [_url('v1')]);
    });

    test('a manual stop abandons the chain', () async {
      final messages = [
        _voice('v1', url: _url('v1')),
        _voice('v2', url: _url('v2')),
      ];
      final (coordinator, player) = _coordinator(messages);

      await coordinator.toggle(messages[0]);
      await coordinator.stop();

      expect(coordinator.activeMessageId, isNull);
      expect(coordinator.isChainActive, isFalse);

      player.finish();
      await Future<void>.delayed(Duration.zero);
      expect(player.played, [_url('v1')]);
    });

    test(
      'playing another note stops the first and starts a new chain',
      () async {
        final messages = [
          _voice('v1', url: _url('v1')),
          _text('t1'),
          _voice('v3', url: _url('v3')),
          _voice('v4', url: _url('v4')),
        ];
        final (coordinator, player) = _coordinator(messages);

        await coordinator.toggle(messages[0]);
        expect(coordinator.activeMessageId, 'v1');

        // Jump to v3 manually — v1 is stopped, and v3 heads a fresh chain.
        await coordinator.toggle(messages[2]);
        expect(coordinator.activeMessageId, 'v3');
        expect(player.calls.where((c) => c == 'stop'), isNotEmpty);

        player.finish();
        await Future<void>.delayed(Duration.zero);
        expect(player.played, [_url('v1'), _url('v3'), _url('v4')]);
      },
    );

    test('two notes never sound at once', () async {
      final messages = [
        _voice('v1', url: _url('v1')),
        _voice('v2', url: _url('v2')),
        _voice('v3', url: _url('v3')),
      ];
      final (coordinator, player) = _coordinator(messages);

      await coordinator.toggle(messages[0]);
      await coordinator.toggle(messages[2]); // interrupt with another note
      player.finish();
      await Future<void>.delayed(Duration.zero);

      expect(player.maxConcurrentSources, 1);
      expect(coordinator.isPlayingMessage('v1'), isFalse);
      expect(coordinator.isPlayingMessage('v2'), isFalse);
    });
  });

  group('failures', () {
    test('a next note that will not load stops the chain cleanly', () async {
      final messages = [
        _voice('v1', url: _url('v1')),
        _voice('v2', url: _url('v2')),
        _voice('v3', url: _url('v3')),
      ];
      final (coordinator, player) = _coordinator(messages);
      player.failingUrls.add(_url('v2'));

      await coordinator.toggle(messages[0]);
      player.finish();
      await Future<void>.delayed(Duration.zero);

      // v2 was attempted and failed; v3 is not reached and nothing throws.
      expect(player.calls, contains('play:${_url("v2")}'));
      expect(player.played, [_url('v1')]);
      expect(coordinator.activeMessageId, isNull);
      expect(coordinator.isPlaying, isFalse);
    });

    test('a deleted next note stops the chain', () async {
      final messages = [
        _voice('v1', url: _url('v1')),
        _deletedVoice('v2'),
        _voice('v3', url: _url('v3')),
      ];
      final (coordinator, player) = _coordinator(messages);

      await coordinator.toggle(messages[0]);
      player.finish();
      await Future<void>.delayed(Duration.zero);

      expect(player.played, [_url('v1')]);
      expect(coordinator.isChainActive, isFalse);
    });

    test('a next note with no media URL stops the chain', () async {
      final messages = [
        _voice('v1', url: _url('v1')),
        _voice('v2', url: null),
        _voice('v3', url: _url('v3')),
      ];
      final (coordinator, player) = _coordinator(messages);

      await coordinator.toggle(messages[0]);
      player.finish();
      await Future<void>.delayed(Duration.zero);

      expect(player.played, [_url('v1')]);
    });

    test('an unplayable note cannot be started by hand either', () async {
      final messages = [_voice('v1', url: null)];
      final (coordinator, player) = _coordinator(messages);

      await coordinator.toggle(messages[0]);

      expect(player.played, isEmpty);
      expect(coordinator.activeMessageId, isNull);
    });
  });

  group('in the conversation', () {
    testWidgets('auto-play does not move the scroll position', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Enough history to scroll, with two consecutive voice notes partway
      // up — so the reader is genuinely parked away from the bottom.
      final messages = <MessageEntity>[
        for (var i = 0; i < 40; i++) _text('t$i'),
        _voice('v1', url: _url('v1')),
        _voice('v2', url: _url('v2')),
        for (var i = 0; i < 15; i++) _text('after-$i'),
      ];
      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(
            _FixedChatRepository(messages),
          ),
          authStateProvider.overrideWith(_ClientAuthNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            const ChatDetailPage(conversationId: _conversationId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
      expect(scroll.position.maxScrollExtent, greaterThan(0));

      // Park the reader on the voice notes, away from the bottom.
      await tester.scrollUntilVisible(
        find.byKey(const Key('voice-play-v1')),
        -60,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final anchored = scroll.offset;
      expect(anchored, lessThan(scroll.position.maxScrollExtent));

      // Both voice bubbles rebuild when playback state changes; neither may
      // drag the conversation anywhere.
      await tester.tap(find.byKey(const Key('voice-play-v1')));
      await tester.pumpAndSettle();

      expect(scroll.offset, anchored);
      expect(find.byKey(const Key('voice-play-v2')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _FixedChatRepository implements ChatRepository {
  _FixedChatRepository(this.messages);

  final List<MessageEntity> messages;

  @override
  Future<Either<Failure, CachedResult<List<ConversationEntity>>>>
  getConversations() async => Right(
    CachedResult([
      ConversationEntity(
        id: _conversationId,
        clientUserId: 'me',
        workerUserId: 'other',
        createdByUserId: 'me',
        createdAt: '2026-08-20T10:00:00.000Z',
        updatedAt: '2026-08-20T12:00:00.000Z',
        otherParticipant: const ConversationParticipantEntity(
          userId: 'other',
          firstName: 'Ali',
          lastName: 'Khan',
        ),
      ),
    ]),
  );

  @override
  Future<Either<Failure, CachedResult<List<MessageEntity>>>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async {
    if (before != null) return const Right(CachedResult(<MessageEntity>[]));
    // The API's contract is newest-first; the provider reverses it.
    return Right(CachedResult(messages.reversed.toList()));
  }

  @override
  Future<Either<Failure, void>> ensureSupportConversation() async =>
      const Right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}
