import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/network/api_client.dart';
import 'package:handygo_app/core/storage/secure_storage_service.dart';

/// In-memory stand-in for [SecureStorageService] — overrides every method so
/// none of them ever touch the real `flutter_secure_storage` platform
/// channel. The base constructor argument is never used by the overrides.
class _FakeSecureStorage extends SecureStorageService {
  _FakeSecureStorage() : super(const FlutterSecureStorage());

  String? accessToken;
  String? refreshToken;
  int clearCount = 0;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    clearCount++;
    accessToken = null;
    refreshToken = null;
  }
}

typedef _Handler = Future<ResponseBody> Function(RequestOptions options);

/// A minimal fake transport — lets each test script exactly how the "main"
/// Dio and the "refresh" Dio respond, without touching the network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final _Handler handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);
}

ResponseBody _json(int statusCode, Map<String, dynamic> data) {
  return ResponseBody.fromString(
    '{"data":${_encode(data)}}',
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

String _encode(Map<String, dynamic> data) {
  final entries = data.entries
      .map((e) => '"${e.key}":"${e.value}"')
      .join(',');
  return '{$entries}';
}

Dio _buildMainDio(_Handler handler) {
  return Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = _FakeAdapter(handler);
}

Dio _buildRefreshDio(_Handler handler) {
  return Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = _FakeAdapter(handler);
}

void main() {
  group('AuthInterceptor', () {
    test(
      'concurrent 401s share a single refresh and both retry with the new token',
      () async {
        final storage = _FakeSecureStorage()
          ..accessToken = 'expired'
          ..refreshToken = 'valid-refresh';

        var refreshCalls = 0;
        final refreshDio = _buildRefreshDio((options) async {
          refreshCalls++;
          // A real refresh has some latency — exaggerating it here is what
          // guarantees the second concurrent request actually observes
          // `_isRefreshing == true` instead of racing ahead of it.
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return _json(200, {
            'accessToken': 'fresh-token',
            'refreshToken': 'fresh-refresh',
          });
        });

        final seenAuthHeaders = <String>[];
        final mainDio = _buildMainDio((options) async {
          final auth = options.headers['Authorization'] as String? ?? '';
          if (auth == 'Bearer expired') {
            return ResponseBody.fromString(
              '{"message":"Unauthorized"}',
              401,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          seenAuthHeaders.add(auth);
          return _json(200, {'ok': 'true'});
        });

        mainDio.interceptors.add(
          AuthInterceptor(storage, mainDio, refreshDio: refreshDio),
        );

        final results = await Future.wait([
          mainDio.get<dynamic>('/a'),
          mainDio.get<dynamic>('/b'),
        ]);

        expect(refreshCalls, 1, reason: 'only one refresh for both 401s');
        expect(results[0].statusCode, 200);
        expect(results[1].statusCode, 200);
        expect(seenAuthHeaders, everyElement('Bearer fresh-token'));
        expect(storage.accessToken, 'fresh-token');
      },
    );

    test(
      'a successful refresh retries a FormData request without throwing '
      '(FormData is single-use and must be cloned before the retry)',
      () async {
        final storage = _FakeSecureStorage()
          ..accessToken = 'expired'
          ..refreshToken = 'valid-refresh';

        final refreshDio = _buildRefreshDio((options) async {
          return _json(200, {
            'accessToken': 'fresh-token',
            'refreshToken': 'fresh-refresh',
          });
        });

        var attempt = 0;
        final mainDio = _buildMainDio((options) async {
          attempt++;
          final auth = options.headers['Authorization'] as String? ?? '';
          if (auth == 'Bearer expired') {
            return ResponseBody.fromString(
              '{"message":"Unauthorized"}',
              401,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          return _json(201, {'ok': 'true'});
        });

        mainDio.interceptors.add(
          AuthInterceptor(storage, mainDio, refreshDio: refreshDio),
        );

        final formData = FormData.fromMap({
          'payload': '{"labourCost":100,"partsNeeded":false,"parts":[]}',
          'photos': <MultipartFile>[],
        });

        final response = await mainDio.post<dynamic>(
          '/bookings/b1/inspection-report',
          data: formData,
        );

        expect(attempt, 2, reason: 'first 401, then one retry');
        expect(response.statusCode, 201);
      },
    );

    test(
      'a temporary network failure during refresh does not clear tokens, '
      'and the original request fails instead of hanging',
      () async {
        final storage = _FakeSecureStorage()
          ..accessToken = 'expired'
          ..refreshToken = 'valid-refresh';

        final refreshDio = _buildRefreshDio((options) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
          );
        });

        final mainDio = _buildMainDio((options) async {
          return ResponseBody.fromString(
            '{"message":"Unauthorized"}',
            401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        mainDio.interceptors.add(
          AuthInterceptor(storage, mainDio, refreshDio: refreshDio),
        );

        await expectLater(
          mainDio.get<dynamic>('/a'),
          throwsA(isA<DioException>()),
        );

        expect(storage.clearCount, 0);
        expect(storage.refreshToken, 'valid-refresh');
      },
    );

    test(
      'a definite 401 rejection from the refresh endpoint clears the session',
      () async {
        final storage = _FakeSecureStorage()
          ..accessToken = 'expired'
          ..refreshToken = 'revoked-refresh';

        final refreshDio = _buildRefreshDio((options) async {
          return ResponseBody.fromString(
            '{"message":"Invalid or expired refresh token"}',
            401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final mainDio = _buildMainDio((options) async {
          return ResponseBody.fromString(
            '{"message":"Unauthorized"}',
            401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        mainDio.interceptors.add(
          AuthInterceptor(storage, mainDio, refreshDio: refreshDio),
        );

        await expectLater(
          mainDio.get<dynamic>('/a'),
          throwsA(isA<DioException>()),
        );

        expect(storage.clearCount, 1);
      },
    );

    test(
      'a plain 403 is passed straight through without touching the session',
      () async {
        final storage = _FakeSecureStorage()
          ..accessToken = 'still-valid'
          ..refreshToken = 'still-valid-refresh';

        final refreshDio = _buildRefreshDio((options) async {
          fail('refresh should never be attempted for a 403');
        });

        final mainDio = _buildMainDio((options) async {
          return ResponseBody.fromString(
            '{"message":"Forbidden"}',
            403,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        mainDio.interceptors.add(
          AuthInterceptor(storage, mainDio, refreshDio: refreshDio),
        );

        await expectLater(
          mainDio.get<dynamic>('/a'),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'statusCode',
              403,
            ),
          ),
        );

        expect(storage.clearCount, 0);
        expect(storage.accessToken, 'still-valid');
      },
    );

    test(
      'a 401 on the retried request itself is not retried again (no infinite loop)',
      () async {
        final storage = _FakeSecureStorage()
          ..accessToken = 'expired'
          ..refreshToken = 'valid-refresh';

        var refreshCalls = 0;
        final refreshDio = _buildRefreshDio((options) async {
          refreshCalls++;
          return _json(200, {
            'accessToken': 'still-bad-token',
            'refreshToken': 'fresh-refresh',
          });
        });

        var requestCount = 0;
        final mainDio = _buildMainDio((options) async {
          requestCount++;
          // Every attempt — including the retry — comes back 401, simulating
          // a persistently-401ing endpoint unrelated to token freshness.
          return ResponseBody.fromString(
            '{"message":"Unauthorized"}',
            401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        mainDio.interceptors.add(
          AuthInterceptor(storage, mainDio, refreshDio: refreshDio),
        );

        await expectLater(
          mainDio.get<dynamic>('/a'),
          throwsA(isA<DioException>()),
        );

        expect(refreshCalls, 1, reason: 'exactly one refresh attempt, never looping');
        expect(requestCount, 2, reason: 'original attempt + exactly one retry');
      },
    );
  });
}
