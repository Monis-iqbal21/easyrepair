import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import '../../support/l10n_test_app.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/data/cached_result.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:handygo_app/features/chat/domain/entities/chat_entities.dart';
import 'package:handygo_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:handygo_app/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:handygo_app/features/chat/presentation/providers/chat_providers.dart';

const _bannerText = 'Apna masla ya sawal yahan likhein. '
    'HandyGo Support aapki madad karega.';

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
  }) async {
    // Deliberately empty: the banner must appear without any persisted
    // message backing it.
    return const Right(CachedResult(<MessageEntity>[]));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
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
}) async {
  final conversation = _conversation(
    id: 'conv-1',
    name: isSupport ? 'HandyGo Support' : 'Ali',
    isSupport: isSupport,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatRepositoryProvider
            .overrideWithValue(_FakeChatRepository([conversation])),
        authStateProvider.overrideWith((ref) async => null),
      ],
      // Roman Urdu: this banner's wording is specified in Roman Urdu, and now
      // lives in app_ur_Latn.arb.
      child: localizedApp(
        const ChatDetailPage(conversationId: 'conv-1'),
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
}
