import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/network/connectivity_service.dart';
import 'package:handygo_app/core/storage/local_cache_service.dart';
import 'package:handygo_app/core/storage/secure_storage_service.dart';
import 'package:handygo_app/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:handygo_app/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStorage extends SecureStorageService {
  _FakeSecureStorage() : super(const FlutterSecureStorage());

  @override
  Future<String?> getCurrentUserId() async => 'u1';
}

typedef _Handler = Future<ResponseBody> Function(RequestOptions options);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final _Handler handler;
  int callCount = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    await requestStream?.drain<void>();
    return handler(options);
  }
}

ResponseBody _jsonBody(int statusCode, String jsonData) {
  return ResponseBody.fromString(
    '{"data":$jsonData}',
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

const _conversationJson = '''
{
  "id": "c1",
  "clientUserId": "client1",
  "workerUserId": "worker1",
  "createdByUserId": "client1",
  "lastMessageAt": null,
  "lastMessagePreview": null,
  "createdAt": "2026-01-01T00:00:00.000Z",
  "updatedAt": "2026-01-01T00:00:00.000Z",
  "otherParticipant": {"userId": "worker1", "firstName": "Ali", "lastName": "Khan"},
  "unreadCount": 0,
  "isSupport": false
}''';

const _messageJson = '''
{
  "id": "m1",
  "conversationId": "c1",
  "senderUserId": "client1",
  "senderRole": "CLIENT",
  "type": "TEXT",
  "text": "Hello",
  "createdAt": "2026-01-01T00:00:00.000Z",
  "updatedAt": "2026-01-01T00:00:00.000Z"
}''';

void main() {
  late LocalCacheService cache;
  late _FakeSecureStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = LocalCacheService(await SharedPreferences.getInstance());
    storage = _FakeSecureStorage();
    ConnectivityService.instance.debugIsOnline = true;
  });

  tearDown(() => ConnectivityService.instance.debugIsOnline = true);

  ChatRepositoryImpl repoWith(_Handler handler, {_FakeAdapter? capture}) {
    final adapter = capture ?? _FakeAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    final datasource = ChatRemoteDataSourceImpl(dio, cache, storage);
    return ChatRepositoryImpl(datasource);
  }

  group('chat offline read', () {
    test('cached conversation list is available offline after a prior '
        'successful load', () async {
      var online = true;
      final repo = repoWith((options) async {
        if (!online) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }
        return _jsonBody(200, '[$_conversationJson]');
      });

      final first = await repo.getConversations();
      expect(first.isRight(), isTrue);
      first.fold((_) => fail('expected success'), (r) {
        expect(r.isStale, isFalse);
        expect(r.data, hasLength(1));
        expect(r.data.first.id, 'c1');
      });

      online = false;
      final second = await repo.getConversations();
      expect(second.isRight(), isTrue);
      second.fold((_) => fail('expected cached fallback, not a failure'), (r) {
        expect(r.isStale, isTrue, reason: 'served from cache while offline');
        expect(r.data, hasLength(1));
        expect(r.data.first.id, 'c1');
      });
    });

    test('cached messages for a previously-opened conversation are '
        'available offline', () async {
      var online = true;
      final repo = repoWith((options) async {
        if (!online) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }
        return _jsonBody(200, '[$_messageJson]');
      });

      await repo.getMessages('c1');

      online = false;
      final result = await repo.getMessages('c1');

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('expected cached fallback'), (r) {
        expect(r.isStale, isTrue);
        expect(r.data, hasLength(1));
        expect(r.data.first.text, 'Hello');
      });
    });

    test('no prior successful load + offline yields a friendly failure, '
        'never a raw exception', () async {
      final repo = repoWith((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });

      final result = await repo.getConversations();

      expect(result.isLeft(), isTrue);
      result.fold((f) {
        expect(f, isA<NetworkFailure>());
        expect(f.code, FailureCode.noInternet);
      }, (_) => fail('expected a failure with nothing cached'));
    });
  });

  group('chat offline send', () {
    test(
      'voice upload includes the measured duration in multipart data',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'chat-voice-test-',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final voiceFile = File('${tempDir.path}/voice.m4a');
        await voiceFile.writeAsBytes([1, 2, 3]);

        final repo = repoWith((options) async {
          expect(options.path, '/chat/conversations/c1/messages/voice');
          final formData = options.data as FormData;
          expect(
            Map<String, String>.fromEntries(formData.fields)['durationSeconds'],
            '3.275',
          );
          return _jsonBody(
            201,
            _messageJson
                .replaceFirst('"type": "TEXT"', '"type": "VOICE"')
                .replaceFirst('"text": "Hello",', '"durationSeconds": 3.275,'),
          );
        });

        final result = await repo.sendVoiceMessage('c1', voiceFile.path, 3.275);

        result.fold(
          (failure) => fail('expected voice upload success: $failure'),
          (message) => expect(message.durationSeconds, 3.275),
        );
      },
    );

    test('sending while offline is blocked before ever reaching the network '
        '— it never pretends success', () async {
      final adapter = _FakeAdapter((options) async {
        fail('the network must never be reached while offline');
      });
      final repo = repoWith(
        (_) async => throw StateError('unused'),
        capture: adapter,
      );

      ConnectivityService.instance.debugIsOnline = false;

      final result = await repo.sendMessage('c1', 'hi there');

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<OfflineActionBlockedFailure>()),
        (_) => fail('offline send must not succeed'),
      );
      expect(adapter.callCount, 0);
    });

    test('once connectivity returns, sending resumes the normal network '
        'path', () async {
      final adapter = _FakeAdapter(
        (options) async => _jsonBody(200, _messageJson),
      );
      final repo = repoWith(
        (_) async => throw StateError('unused'),
        capture: adapter,
      );

      ConnectivityService.instance.debugIsOnline = false;
      final blocked = await repo.sendMessage('c1', 'hi there');
      expect(blocked.isLeft(), isTrue);

      ConnectivityService.instance.debugIsOnline = true;
      final result = await repo.sendMessage('c1', 'hi there');

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('expected success once online'), (message) {
        expect(message.id, 'm1');
      });
      expect(
        adapter.callCount,
        1,
        reason: 'only the online attempt hit the network',
      );
    });
  });
}
