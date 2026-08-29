import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:handygo_app/features/chat/presentation/widgets/chat_composer.dart';

import '../../support/l10n_test_app.dart';

class _FakeAuthStateNotifier extends AuthStateNotifier {
  @override
  Future<UserEntity?> build() async => null;
}

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository(this.conversations);

  final List<ConversationEntity> conversations;

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
  }) async => const Right(CachedResult(<MessageEntity>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

ConversationEntity _conversation({
  required String name,
  required bool isSupport,
  String? phone,
}) {
  return ConversationEntity(
    id: 'conv-1',
    clientUserId: 'me',
    workerUserId: 'other',
    createdByUserId: 'me',
    createdAt: '2026-07-01T10:00:00.000Z',
    updatedAt: '2026-07-01T10:00:00.000Z',
    otherParticipant: ConversationParticipantEntity(
      userId: 'other',
      firstName: name,
      lastName: isSupport ? '' : 'Khan',
      phone: phone,
    ),
    isSupport: isSupport,
  );
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  final launchCalls = <MethodCall>[];
  bool launchShouldSucceed = true;

  setUp(() {
    launchCalls.clear();
    launchShouldSucceed = true;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        launchCalls.add(call);
        return launchShouldSucceed;
      },
    );
  });

  Future<void> pumpDetail(
    WidgetTester tester,
    ConversationEntity conversation,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider
              .overrideWithValue(_FakeChatRepository([conversation])),
          authStateProvider.overrideWith(() => _FakeAuthStateNotifier()),
        ],
        child: localizedApp(
          const ChatDetailPage(conversationId: 'conv-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final callIcon = find.byIcon(Icons.call_rounded);

  testWidgets(
    'an ordinary Client<->Worker conversation shows the call icon when the '
    'participant has a phone number',
    (tester) async {
      await pumpDetail(
        tester,
        _conversation(
          name: 'Ali',
          isSupport: false,
          phone: '+923001234567',
        ),
      );

      expect(callIcon, findsOneWidget);
    },
  );

  testWidgets(
    'the HandyGo Support thread never shows the call icon, even if a phone '
    'number is somehow present',
    (tester) async {
      await pumpDetail(
        tester,
        _conversation(
          name: 'HandyGo Support',
          isSupport: true,
          phone: '+923001234567',
        ),
      );

      expect(callIcon, findsNothing);
    },
  );

  testWidgets(
    'a missing phone number hides the call icon instead of crashing',
    (tester) async {
      await pumpDetail(
        tester,
        _conversation(name: 'Ali', isSupport: false, phone: null),
      );

      expect(callIcon, findsNothing);
    },
  );

  testWidgets(
    'an empty phone number also hides the call icon',
    (tester) async {
      await pumpDetail(
        tester,
        _conversation(name: 'Ali', isSupport: false, phone: ''),
      );

      expect(callIcon, findsNothing);
    },
  );

  testWidgets(
    'tapping the call icon opens the dialer pre-filled with the other '
    "participant's number, without placing the call automatically",
    (tester) async {
      await pumpDetail(
        tester,
        _conversation(
          name: 'Ali',
          isSupport: false,
          phone: '+923001234567',
        ),
      );

      await tester.tap(callIcon);
      await tester.pumpAndSettle();

      expect(launchCalls, hasLength(1));
      final call = launchCalls.single;
      expect(call.method, 'launch');
      expect(call.arguments['url'], 'tel:+923001234567');

      // Still on the same conversation screen — no navigation/reset was
      // triggered by opening the dialer.
      expect(find.text('Ali Khan'), findsOneWidget);
    },
  );

  testWidgets(
    'a dialer launch failure shows a clean snackbar, never a raw exception',
    (tester) async {
      launchShouldSucceed = false;
      await pumpDetail(
        tester,
        _conversation(
          name: 'Ali',
          isSupport: false,
          phone: '+923001234567',
        ),
      );

      await tester.tap(callIcon);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Could not open the phone dialer'), findsOneWidget);
    },
  );

  testWidgets(
    'the attachment menu no longer offers a duplicate voice option, but '
    'photo/video/location remain',
    (tester) async {
      await pumpDetail(
        tester,
        _conversation(
          name: 'Ali',
          isSupport: false,
          phone: '+923001234567',
        ),
      );

      await tester.tap(find.byKey(ChatComposerKeys.attachButton));
      await tester.pumpAndSettle();

      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Voice'), findsNothing);
      // Exactly one mic icon remains on screen — the dedicated composer
      // control underneath the open sheet. A second one would mean the
      // attachment menu's duplicate voice option is still there.
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'the dedicated voice-message control (mic/send action button) remains '
    'available in the composer',
    (tester) async {
      await pumpDetail(
        tester,
        _conversation(
          name: 'Ali',
          isSupport: false,
          phone: '+923001234567',
        ),
      );

      // The composer is empty, so the circular action button renders as the
      // dedicated mic (voice-record) control.
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    },
  );
}
