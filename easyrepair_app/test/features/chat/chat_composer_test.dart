import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// fpdart also exports a `State`, which would shadow Flutter's inside the
// test harness widget below.
import 'package:fpdart/fpdart.dart' hide State;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// The composer is the one place a conversation is written from, so these
/// cover the whole surface: which action the right-hand button offers, that
/// text goes out through the existing send provider, that the emoji panel
/// takes the keyboard's place (and gives it back), that attach/camera/mic each
/// reach their own existing flow, and that none of it overflows on a small
/// phone or at a 2.0 text scale.

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

final _conversation = ConversationEntity(
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
);

MessageEntity _sentMessage(String text) => MessageEntity(
  id: 'message-sent',
  conversationId: _conversationId,
  senderUserId: 'me',
  senderRole: 'CLIENT',
  type: ChatMessageType.text,
  text: text,
  createdAt: '2026-08-20T12:05:00.000Z',
  updatedAt: '2026-08-20T12:05:00.000Z',
);

/// Records what the page asked the repository to send, so a test can assert
/// the composer went through the existing flow rather than inventing one.
class _RecordingChatRepository implements ChatRepository {
  final List<String> sentTexts = [];

  @override
  Future<Either<Failure, CachedResult<List<ConversationEntity>>>>
  getConversations() async => Right(CachedResult([_conversation]));

  @override
  Future<Either<Failure, CachedResult<List<MessageEntity>>>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async => const Right(CachedResult(<MessageEntity>[]));

  @override
  Future<Either<Failure, void>> ensureSupportConversation() async =>
      const Right(null);

  @override
  Future<Either<Failure, MessageEntity>> sendMessage(
    String conversationId,
    String text,
  ) async {
    sentTexts.add(text);
    return Right(_sentMessage(text));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

/// Stands in for the real picker and records the [ImageSource] asked for, so
/// "the camera button opens the camera" is checked rather than assumed.
class _RecordingImagePicker extends ImagePickerPlatform {
  final List<ImageSource> imageRequests = [];
  final List<ImageSource> videoRequests = [];

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    imageRequests.add(source);
    // Null stands for "the user backed out", which stops the flow before any
    // upload — this test is about which picker opened, not the upload.
    return null;
  }

  @override
  Future<XFile?> getVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async {
    videoRequests.add(source);
    return null;
  }
}

class _GrantedPermissionHandler extends PermissionHandlerPlatform {
  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      PermissionStatus.granted;
}

Finder get _actionButton => find.byKey(ChatComposerKeys.actionButton);
Finder get _emojiPanel => find.byKey(ChatComposerKeys.emojiPanel);

bool _showsMic(WidgetTester tester) => tester
    .widgetList(
      find.descendant(
        of: _actionButton,
        matching: find.byIcon(Icons.mic_rounded),
      ),
    )
    .isNotEmpty;

bool _showsSend(WidgetTester tester) => tester
    .widgetList(
      find.descendant(
        of: _actionButton,
        matching: find.byIcon(Icons.send_rounded),
      ),
    )
    .isNotEmpty;

TextEditingController _composerController(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(ChatComposerKeys.textField))
    .controller!;

Future<_RecordingChatRepository> _pumpConversation(
  WidgetTester tester, {
  Size size = const Size(390, 780),
  double textScale = 1.0,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final repository = _RecordingChatRepository();
  final container = ProviderContainer(
    overrides: [
      chatRepositoryProvider.overrideWithValue(repository),
      authStateProvider.overrideWith(_ClientAuthNotifier.new),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedApp(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const ChatDetailPage(conversationId: _conversationId),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  setUp(() {
    // The emoji picker reads its "recent" list from SharedPreferences on the
    // first build; without a mock store that future never completes.
    SharedPreferences.setMockInitialValues({});
    PermissionHandlerPlatform.instance = _GrantedPermissionHandler();
  });

  group('mic / send action', () {
    testWidgets('an empty composer offers the mic, not send', (tester) async {
      await _pumpConversation(tester);

      expect(_actionButton, findsOneWidget);
      expect(_showsMic(tester), isTrue);
      expect(_showsSend(tester), isFalse);
    });

    testWidgets('typing text turns the mic into send', (tester) async {
      await _pumpConversation(tester);

      await tester.enterText(find.byKey(ChatComposerKeys.textField), 'Salam');
      await tester.pump();

      expect(_showsSend(tester), isTrue);
      expect(_showsMic(tester), isFalse);
    });

    testWidgets('clearing the field restores the mic', (tester) async {
      await _pumpConversation(tester);
      final field = find.byKey(ChatComposerKeys.textField);

      await tester.enterText(field, 'Salam');
      await tester.pump();
      expect(_showsSend(tester), isTrue);

      await tester.enterText(field, '');
      await tester.pump();

      expect(_showsMic(tester), isTrue);
      expect(_showsSend(tester), isFalse);
    });

    testWidgets('whitespace alone is not something to send', (tester) async {
      await _pumpConversation(tester);

      await tester.enterText(find.byKey(ChatComposerKeys.textField), '   ');
      await tester.pump();

      expect(_showsMic(tester), isTrue);
    });

    testWidgets('send goes through the existing message flow and clears', (
      tester,
    ) async {
      final repository = await _pumpConversation(tester);

      await tester.enterText(
        find.byKey(ChatComposerKeys.textField),
        '  Kal aa jayen  ',
      );
      await tester.pump();
      await tester.tap(_actionButton);
      await tester.pumpAndSettle();

      // Trimmed, sent once, through the repository the page already used.
      expect(repository.sentTexts, ['Kal aa jayen']);
      expect(_composerController(tester).text, isEmpty);
      expect(_showsMic(tester), isTrue);
    });

    testWidgets('an empty composer taps through to voice recording', (
      tester,
    ) async {
      // The recorder itself is a platform plugin, so this asserts the wiring:
      // an empty composer dispatches to onStartRecording, which the page
      // routes to its existing _startVoiceRecording — the same one the old
      // input bar used. The mic never opens the attachment sheet.
      var startedRecording = false;
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: _Harness(onStartRecording: () => startedRecording = true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_actionButton);
      await tester.pump();

      expect(startedRecording, isTrue);
    });

    testWidgets('a recording composer sends the recording, never text', (
      tester,
    ) async {
      var sentRecording = false;
      var sentText = false;
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: _Harness(
              isRecording: true,
              onSendRecording: () => sentRecording = true,
              onSendText: () => sentText = true,
            ),
          ),
        ),
      );
      // Not pumpAndSettle: the recording bar's blinking dot never stops.
      await tester.pump();

      expect(_showsSend(tester), isTrue);
      await tester.tap(_actionButton);
      await tester.pump();

      expect(sentRecording, isTrue);
      expect(sentText, isFalse);
    });
  });

  group('emoji panel', () {
    testWidgets('the emoji button opens the panel and drops the keyboard', (
      tester,
    ) async {
      await _pumpConversation(tester);

      await tester.tap(find.byKey(ChatComposerKeys.textField));
      await tester.pumpAndSettle();
      final focus = tester
          .widget<TextField>(find.byKey(ChatComposerKeys.textField))
          .focusNode!;
      expect(focus.hasFocus, isTrue);
      expect(_emojiPanel, findsNothing);

      await tester.tap(find.byKey(ChatComposerKeys.emojiButton));
      await tester.pumpAndSettle();

      expect(_emojiPanel, findsOneWidget);
      expect(focus.hasFocus, isFalse);
      // The same button now offers the keyboard back.
      expect(find.byIcon(Icons.keyboard_rounded), findsOneWidget);
      expect(find.byIcon(Icons.emoji_emotions_outlined), findsNothing);
    });

    testWidgets('the keyboard toggle closes the panel and refocuses', (
      tester,
    ) async {
      await _pumpConversation(tester);

      await tester.tap(find.byKey(ChatComposerKeys.emojiButton));
      await tester.pumpAndSettle();
      expect(_emojiPanel, findsOneWidget);

      await tester.tap(find.byKey(ChatComposerKeys.emojiButton));
      await tester.pumpAndSettle();

      expect(_emojiPanel, findsNothing);
      expect(find.byIcon(Icons.emoji_emotions_outlined), findsOneWidget);
      final focus = tester
          .widget<TextField>(find.byKey(ChatComposerKeys.textField))
          .focusNode!;
      expect(focus.hasFocus, isTrue);
    });

    testWidgets('tapping back into the field closes the panel', (tester) async {
      await _pumpConversation(tester);

      await tester.tap(find.byKey(ChatComposerKeys.emojiButton));
      await tester.pumpAndSettle();
      expect(_emojiPanel, findsOneWidget);

      await tester.tap(find.byKey(ChatComposerKeys.textField));
      await tester.pumpAndSettle();

      expect(_emojiPanel, findsNothing);
    });

    testWidgets('a chosen emoji lands at the cursor, keeping the text', (
      tester,
    ) async {
      await _pumpConversation(tester);
      final controller = _composerController(tester);

      controller.text = 'ab';
      controller.selection = const TextSelection.collapsed(offset: 1);
      await tester.pump();

      await tester.tap(find.byKey(ChatComposerKeys.emojiButton));
      await tester.pumpAndSettle();

      // The first cell of the grid the panel opens on.
      final firstEmoji = find
          .descendant(
            of: find.descendant(
              of: _emojiPanel,
              matching: find.byType(GridView),
            ),
            matching: find.byType(Text),
          )
          .first;
      final glyph = tester.widget<Text>(firstEmoji).data!;
      await tester.tap(firstEmoji);
      await tester.pumpAndSettle();

      expect(
        controller.text,
        'a$glyph'
        'b',
      );
      expect(controller.selection.baseOffset, 1 + glyph.length);
    });

    testWidgets('Android back closes the panel before leaving the chat', (
      tester,
    ) async {
      final observer = _RouteObserver();
      await tester.binding.setSurfaceSize(const Size(390, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _RecordingChatRepository();
      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith(_ClientAuthNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            const _Origin(),
            navigatorObserver: observer,
            routes: {
              '/chat': (_) =>
                  const ChatDetailPage(conversationId: _conversationId),
            },
          ),
        ),
      );
      await tester.tap(find.text('open chat'));
      await tester.pumpAndSettle();
      expect(find.byKey(ChatComposerKeys.composer), findsOneWidget);

      await tester.tap(find.byKey(ChatComposerKeys.emojiButton));
      await tester.pumpAndSettle();
      expect(_emojiPanel, findsOneWidget);

      // First back: the panel closes and the conversation stays put.
      await _pressSystemBack(tester);
      await tester.pumpAndSettle();
      expect(_emojiPanel, findsNothing);
      expect(find.byKey(ChatComposerKeys.composer), findsOneWidget);
      expect(observer.popCount, 0);

      // Second back: ordinary behaviour, unchanged — it leaves the chat.
      await _pressSystemBack(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(ChatComposerKeys.composer), findsNothing);
      expect(find.text('open chat'), findsOneWidget);
      expect(observer.popCount, 1);
    });
  });

  group('attachment and camera', () {
    testWidgets('the paperclip still offers photo, video and location', (
      tester,
    ) async {
      await _pumpConversation(tester);

      await tester.tap(find.byKey(ChatComposerKeys.attachButton));
      await tester.pumpAndSettle();

      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      // Camera video survived the camera sheet's removal.
      expect(find.byKey(const Key('attach-camera-video')), findsOneWidget);
    });

    testWidgets('voice is not duplicated in the attachment sheet', (
      tester,
    ) async {
      await _pumpConversation(tester);

      await tester.tap(find.byKey(ChatComposerKeys.attachButton));
      await tester.pumpAndSettle();

      // Voice has its own dedicated mic action; offering it here as well
      // would give the same recorder two entry points. Scoped to the sheet —
      // the composer's own mic is still on screen behind it.
      final sheet = find.byType(GridView);
      expect(
        find.descendant(of: sheet, matching: find.text('Voice')),
        findsNothing,
      );
      expect(
        find.descendant(of: sheet, matching: find.byIcon(Icons.mic_rounded)),
        findsNothing,
      );
    });

    testWidgets('the camera button opens the camera, not a menu', (
      tester,
    ) async {
      final picker = _RecordingImagePicker();
      final previous = ImagePickerPlatform.instance;
      ImagePickerPlatform.instance = picker;
      addTearDown(() => ImagePickerPlatform.instance = previous);

      await _pumpConversation(tester);
      await tester.tap(find.byKey(ChatComposerKeys.cameraButton));
      await tester.pumpAndSettle();

      expect(picker.imageRequests, [ImageSource.camera]);
      // No intermediate sheet: nothing was pushed over the conversation.
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(ChatComposerKeys.composer), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('the composer grows with the draft, then stops', (
      tester,
    ) async {
      await _pumpConversation(tester);
      final composer = find.byKey(ChatComposerKeys.composer);
      final field = find.byKey(ChatComposerKeys.textField);

      final singleLine = tester.getSize(composer).height;

      await tester.enterText(field, 'one\ntwo\nthree');
      await tester.pumpAndSettle();
      final threeLines = tester.getSize(composer).height;
      expect(threeLines, greaterThan(singleLine));

      await tester.enterText(field, List.filled(5, 'line').join('\n'));
      await tester.pumpAndSettle();
      final fiveLines = tester.getSize(composer).height;
      expect(fiveLines, greaterThan(threeLines));

      // Past the cap the composer holds its height and the field scrolls
      // its own content instead.
      await tester.enterText(field, List.filled(40, 'line').join('\n'));
      await tester.pumpAndSettle();
      expect(tester.getSize(composer).height, fiveLines);
      expect(tester.takeException(), isNull);
    });

    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      testWidgets('nothing overflows at ${width.toInt()}px wide', (
        tester,
      ) async {
        await _pumpConversation(tester, size: Size(width, 780));

        expect(tester.takeException(), isNull);
        final composerWidth = tester
            .getSize(find.byKey(ChatComposerKeys.composer))
            .width;
        expect(composerWidth, lessThanOrEqualTo(width));

        // With the emoji panel open too — that is the tallest the bottom of
        // the screen ever gets.
        await tester.tap(find.byKey(ChatComposerKeys.emojiButton));
        await tester.pumpAndSettle();
        expect(_emojiPanel, findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a 2.0 text scale does not overflow', (tester) async {
      await _pumpConversation(
        tester,
        size: const Size(320, 780),
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);

      await tester.enterText(
        find.byKey(ChatComposerKeys.textField),
        'a message long enough to wrap onto several lines at this scale',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(ChatComposerKeys.emojiButton));
      await tester.pumpAndSettle();
      expect(_emojiPanel, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the attachment sheet fits its four tiles on a 320px screen', (
      tester,
    ) async {
      // A fourth tile pushed "Record Video" onto a second line, which square
      // cells had no room for.
      await _pumpConversation(tester, size: const Size(320, 780));

      await tester.tap(find.byKey(ChatComposerKeys.attachButton));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('attach-camera-video')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every composer control clears a 44px touch target', (
      tester,
    ) async {
      await _pumpConversation(tester);

      for (final key in [
        ChatComposerKeys.emojiButton,
        ChatComposerKeys.attachButton,
        ChatComposerKeys.cameraButton,
        ChatComposerKeys.actionButton,
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(44), reason: '$key width');
        expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
      }
    });
  });
}

/// Drives the composer on its own, for the callbacks whose real
/// implementations are platform plugins (the recorder).
class _Harness extends StatefulWidget {
  const _Harness({
    this.isRecording = false,
    this.onStartRecording,
    this.onSendRecording,
    this.onSendText,
  });

  final bool isRecording;
  final VoidCallback? onStartRecording;
  final VoidCallback? onSendRecording;
  final VoidCallback? onSendText;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ChatComposer(
          controller: _controller,
          focusNode: _focusNode,
          isSending: false,
          isAttachmentBusy: false,
          isRecording: widget.isRecording,
          isPaused: false,
          recordingDuration: Duration.zero,
          amplitudeBars: const [],
          isEmojiPanelVisible: false,
          applyBottomSafeArea: true,
          onToggleEmojiPanel: () {},
          onSendText: widget.onSendText ?? () {},
          onAttachmentTap: () {},
          onCameraTap: () {},
          onStartRecording: widget.onStartRecording ?? () {},
          onCancelRecording: () {},
          onSendRecording: widget.onSendRecording ?? () {},
          onTogglePauseResume: () {},
        ),
      ],
    );
  }
}

class _Origin extends StatelessWidget {
  const _Origin();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).pushNamed('/chat'),
          child: const Text('open chat'),
        ),
      ),
    );
  }
}

class _RouteObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount++;
    super.didPop(route, previousRoute);
  }
}

/// Delivers the Android system back gesture the way the platform does, so
/// PopScope is exercised rather than bypassed.
Future<void> _pressSystemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
}
