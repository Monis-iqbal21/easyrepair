import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/core/widgets/handygo_brand_lockup.dart';
import '../../support/l10n_test_app.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/data/cached_result.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:handygo_app/features/chat/domain/entities/chat_entities.dart';
import 'package:handygo_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:handygo_app/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:handygo_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:handygo_app/features/chat/presentation/widgets/chat_composer.dart';

const _bannerText =
    'Apna masla ya sawal yahan likhein. '
    'HandyGo Support aapki madad karega.';

class _SignedInAuthStateNotifier extends AuthStateNotifier {
  @override
  Future<UserEntity?> build() async => const UserEntity(
    id: 'me',
    phone: '+923000000000',
    role: 'CLIENT',
    firstName: 'Sara',
    lastName: 'Khan',
  );
}

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository(
    this.conversations, {
    this.messages = const <MessageEntity>[],
  });

  final List<ConversationEntity> conversations;
  final List<MessageEntity> messages;

  @override
  Future<Either<Failure, void>> ensureSupportConversation() async =>
      const Right(null);

  @override
  Future<Either<Failure, CachedResult<List<ConversationEntity>>>>
  getConversations() async => Right(CachedResult(conversations));

  @override
  Future<Either<Failure, CachedResult<List<MessageEntity>>>> getMessages(
    String conversationId, {
    int limit = 30,
    String? before,
  }) async {
    // Deliberately empty: the banner must appear without any persisted
    // message backing it.
    return Right(CachedResult(messages));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

MessageEntity _message(
  String id,
  ChatMessageType type, {
  String? text,
  String? mediaUrl,
  String? thumbnailUrl,
  double? latitude,
  double? longitude,
  double? durationSeconds,
  String senderUserId = 'other',
  String? seenAt,
}) {
  return MessageEntity(
    id: id,
    conversationId: 'conv-1',
    senderUserId: senderUserId,
    senderRole: senderUserId == 'me' ? 'CLIENT' : 'WORKER',
    type: type,
    text: text,
    mediaUrl: mediaUrl,
    thumbnailUrl: thumbnailUrl,
    durationSeconds: durationSeconds,
    latitude: latitude,
    longitude: longitude,
    seenAt: seenAt,
    createdAt: '2026-08-26T20:00:00.000Z',
    updatedAt: '2026-08-26T20:00:00.000Z',
  );
}

ConversationEntity _conversation({
  required String id,
  required String name,
  required bool isSupport,
}) {
  return ConversationEntity(
    id: id,
    clientUserId: 'me',
    workerUserId: 'other',
    createdByUserId: 'me',
    createdAt: '2026-07-01T10:00:00.000Z',
    updatedAt: '2026-07-01T10:00:00.000Z',
    otherParticipant: ConversationParticipantEntity(
      userId: 'other',
      firstName: name,
      lastName: isSupport ? '' : 'Khan',
    ),
    isSupport: isSupport,
  );
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required bool isSupport,
  List<MessageEntity> messages = const <MessageEntity>[],
  ThemeData? theme,
}) async {
  // Give each call a fresh ProviderScope and ChatDetailPage state. Several
  // tests intentionally pump multiple conversation variants in one body.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  final conversation = _conversation(
    id: 'conv-1',
    name: isSupport ? 'HandyGo Support' : 'Ali',
    isSupport: isSupport,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(
          _FakeChatRepository([conversation], messages: messages),
        ),
        authStateProvider.overrideWith(_SignedInAuthStateNotifier.new),
      ],
      // Roman Urdu: this banner's wording is specified in Roman Urdu, and now
      // lives in app_ur_Latn.arb.
      child: localizedApp(
        Theme(
          data: theme ?? AppTheme.lightTheme,
          child: const ChatDetailPage(conversationId: 'conv-1'),
        ),
        locale: AppLocale.romanUrdu,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the support thread shows the static Roman Urdu banner', (
    tester,
  ) async {
    await _pumpDetail(tester, isSupport: true);

    expect(find.text(_bannerText), findsOneWidget);
    expect(find.byType(HandyGoBrandMark), findsOneWidget);
    expect(
      find.image(
        const AssetImage('assets/images/logo-primary-transparent.png'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the banner needs no persisted SYSTEM message — the thread is '
      'genuinely empty', (tester) async {
    await _pumpDetail(tester, isSupport: true);

    expect(find.text(_bannerText), findsOneWidget);
    // The normal empty-thread state is still what the message list renders,
    // proving nothing was written to the conversation.
    expect(find.text('Abhi koi message nahi. Salam karein!'), findsOneWidget);
  });

  testWidgets('an ordinary booking chat shows no banner', (tester) async {
    await _pumpDetail(tester, isSupport: false);

    expect(find.text(_bannerText), findsNothing);
    expect(find.text('Ali Khan'), findsOneWidget);
  });

  testWidgets('all supported message presentations remain available', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      isSupport: false,
      messages: [
        _message(
          'location',
          ChatMessageType.location,
          latitude: 31.52,
          longitude: 74.35,
        ),
        _message(
          'voice',
          ChatMessageType.voice,
          mediaUrl: 'https://example.invalid/voice.m4a',
        ),
        _message(
          'video',
          ChatMessageType.video,
          mediaUrl: 'https://example.invalid/video.mp4',
        ),
        _message(
          'image',
          ChatMessageType.image,
          mediaUrl: 'https://example.invalid/photo.jpg',
        ),
        _message('text', ChatMessageType.text, text: 'Text message'),
        _message('system', ChatMessageType.system, text: 'System message'),
      ],
    );

    // Fake repository follows the API's newest-first contract, so the first
    // supplied location row is the absolute latest after provider reversal.
    expect(find.byIcon(Icons.location_on_rounded), findsWidgets);
    expect(find.byIcon(Icons.play_circle_filled_rounded), findsWidgets);
    // The composer offers emoji, attach, camera and the mic/send action.
    expect(find.byKey(ChatComposerKeys.emojiButton), findsOneWidget);
    expect(find.byKey(ChatComposerKeys.attachButton), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();

    expect(find.text('System message'), findsOneWidget);
    expect(find.text('Text message'), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_rounded), findsOneWidget);
  });

  testWidgets(
    'voice duration is visible before playback with a safe old-message fallback',
    (tester) async {
      await _pumpDetail(
        tester,
        isSupport: false,
        messages: [
          _message(
            'voice-known',
            ChatMessageType.voice,
            mediaUrl: 'https://example.invalid/known.m4a',
            durationSeconds: 7.6,
          ),
          _message(
            'voice-unknown',
            ChatMessageType.voice,
            mediaUrl: 'https://example.invalid/unknown.m4a',
          ),
        ],
      );

      expect(find.text('00:07'), findsOneWidget);
      expect(find.text('--:--'), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_filled_rounded), findsNothing);
    },
  );

  testWidgets(
    'saved and read ticks render truthfully for every outgoing message type',
    (tester) async {
      final cases = <ChatMessageType, Map<String, Object?>>{
        ChatMessageType.text: {'text': 'Hello'},
        ChatMessageType.voice: {
          'mediaUrl': 'https://example.invalid/voice.m4a',
          'durationSeconds': 4.0,
        },
        ChatMessageType.image: {
          'mediaUrl': 'https://example.invalid/photo.jpg',
        },
        ChatMessageType.location: {'latitude': 31.52, 'longitude': 74.35},
      };

      for (final entry in cases.entries) {
        final id = entry.key.name;
        await _pumpDetail(
          tester,
          isSupport: entry.key == ChatMessageType.text,
          messages: [
            _message(
              id,
              entry.key,
              text: entry.value['text'] as String?,
              mediaUrl: entry.value['mediaUrl'] as String?,
              durationSeconds: entry.value['durationSeconds'] as double?,
              latitude: entry.value['latitude'] as double?,
              longitude: entry.value['longitude'] as double?,
              senderUserId: 'me',
              seenAt: '2026-08-31T10:01:00.000Z',
            ),
          ],
        );

        final tick = tester.widget<Icon>(find.byKey(Key('message-state-$id')));
        expect(tick.icon, Icons.done_all_rounded, reason: '$id read tick');
      }

      await _pumpDetail(
        tester,
        isSupport: true,
        messages: [
          _message(
            'saved-only',
            ChatMessageType.text,
            text: 'Waiting for recipient',
            senderUserId: 'me',
          ),
        ],
      );
      final sentTick = tester.widget<Icon>(
        find.byKey(const Key('message-state-saved-only')),
      );
      expect(sentTick.icon, Icons.done_rounded);
    },
  );

  testWidgets('the shared conversation has no overflow at supported widths', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in <double>[320, 360, 390, 430, 600]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await _pumpDetail(
        tester,
        isSupport: false,
        messages: [
          _message(
            'long-text',
            ChatMessageType.text,
            text:
                'A long message that must wrap naturally without overflowing the shared Client and Ustaad conversation layout.',
          ),
          _message(
            'location',
            ChatMessageType.location,
            latitude: 31.52,
            longitude: 74.35,
          ),
          _message(
            'voice',
            ChatMessageType.voice,
            mediaUrl: 'https://example.invalid/voice.m4a',
          ),
        ],
      );

      expect(tester.takeException(), isNull, reason: 'overflow at $width px');
      expect(find.text('Ali Khan'), findsOneWidget);
    }
  });

  testWidgets('the shared conversation reads the dark semantic palette', (
    tester,
  ) async {
    await _pumpDetail(tester, isSupport: true, theme: AppTheme.darkTheme);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppSemanticColors.dark.background);
    expect(find.text(_bannerText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
