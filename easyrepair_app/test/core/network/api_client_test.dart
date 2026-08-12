import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/network/api_client.dart';
import 'package:handygo_app/core/storage/secure_storage_service.dart';
import 'package:handygo_app/features/auth/data/datasources/auth_remote_datasource.dart';

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
      'access token expiry never logs out an active user — a single request '
      'that 401s on an expired access token silently refreshes and succeeds, '
      'with the newly-issued (sliding-expiry) refresh token persisted',
      () async {
        final storage = _FakeSecureStorage()
          ..accessToken = 'expired'
          ..refreshToken = 'valid-refresh';

        final refreshDio = _buildRefreshDio((options) async {
          return _json(200, {
            'accessToken': 'fresh-token',
            // A genuinely new refresh token, distinct from the one
            // presented — this is what makes 30d an inactivity timeout
            // rather than a fixed session cap: every successful refresh
            // both the app and the backend agree the clock restarts.
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
          return _json(200, {'ok': 'true'});
        });

        mainDio.interceptors.add(
          AuthInterceptor(storage, mainDio, refreshDio: refreshDio),
        );

        final response = await mainDio.get<dynamic>('/a');

        expect(attempt, 2, reason: 'the 401, then one silent retry');
        expect(response.statusCode, 200);
        // Never a "session expired" outcome, and the persisted refresh
        // token is the fresh one — not cleared, not left as the old one.
        expect(storage.clearCount, 0);
        expect(storage.accessToken, 'fresh-token');
        expect(storage.refreshToken, 'fresh-refresh');
      },
    );

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

    test(
      'a transient network failure on the retry (right after a successful '
      'refresh) surfaces as itself, never as the stale pre-refresh 401 — a '
      'one-off blip on the retry must not read as an expired session',
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
          // The retry itself (now carrying the fresh token) hits a
          // transient network failure — nothing to do with authorization.
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        });

        mainDio.interceptors.add(
          AuthInterceptor(storage, mainDio, refreshDio: refreshDio),
        );

        await expectLater(
          mainDio.get<dynamic>('/a'),
          throwsA(
            isA<DioException>()
                .having((e) => e.type, 'type', DioExceptionType.connectionError)
                .having((e) => e.response?.statusCode, 'statusCode', isNull),
          ),
        );

        expect(attempt, 2, reason: 'original attempt + the retry that then failed');
        // The refresh itself succeeded — a transient retry failure must
        // never be treated as proof the refresh token is bad.
        expect(storage.clearCount, 0);
        expect(storage.accessToken, 'fresh-token');
      },
    );

    test(
      'app restart with an expired access token but a valid refresh token '
      'silently restores the session — GET /auth/me 401s once, the '
      'interceptor refreshes and retries behind the scenes, and the caller '
      'sees a normal successful user, never a "session expired" error',
      () async {
        final storage = _FakeSecureStorage()
          ..accessToken = 'expired-access'
          ..refreshToken = 'still-valid-refresh';

        final refreshDio = _buildRefreshDio((options) async {
          return _json(200, {
            'accessToken': 'fresh-access',
            'refreshToken': 'fresh-refresh',
          });
        });

        final mainDio = _buildMainDio((options) async {
          final auth = options.headers['Authorization'] as String? ?? '';
          if (auth == 'Bearer expired-access') {
            return ResponseBody.fromString(
              '{"message":"Unauthorized"}',
              401,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          expect(auth, 'Bearer fresh-access');
          return ResponseBody.fromString(
            '{"data":{"id":"u1","phone":"+923001234567","role":"CLIENT",'
            '"firstName":"Ali","lastName":"Khan"}}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        mainDio.interceptors.add(
          AuthInterceptor(storage, mainDio, refreshDio: refreshDio),
        );

        final datasource = AuthRemoteDatasource(mainDio, mainDio);
        final user = await datasource.getCurrentUser();

        expect(user.id, 'u1');
        expect(user.role, 'CLIENT');
        // The old token was silently replaced — never wiped, which is what
        // would force the user back to a login screen.
        expect(storage.clearCount, 0);
        expect(storage.accessToken, 'fresh-access');
        expect(storage.refreshToken, 'fresh-refresh');
      },
    );

    test(
      'resetRefreshState lets a subsequent 401 start its own fresh refresh '
      'instead of waiting on a refresh left orphaned by a logout',
      () async {
        final storage = _FakeSecureStorage()
          ..accessToken = 'expired'
          ..refreshToken = 'valid-refresh';

        final firstRefreshGate = Completer<ResponseBody>();
        var refreshCalls = 0;
        final refreshDio = _buildRefreshDio((options) async {
          refreshCalls++;
          if (refreshCalls == 1) {
            // Simulates a refresh still in flight at the moment of logout —
            // deliberately never resolves during the assertions below.
            return firstRefreshGate.future;
          }
          return _json(200, {
            'accessToken': 'fresh-token-2',
            'refreshToken': 'fresh-refresh-2',
          });
        });

        final mainDio = _buildMainDio((options) async {
          final auth = options.headers['Authorization'] as String? ?? '';
          if (auth == 'Bearer expired' || auth.isEmpty) {
            return ResponseBody.fromString(
              '{"message":"Unauthorized"}',
              401,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          return _json(200, {'ok': 'true'});
        });

        final interceptor = AuthInterceptor(
          storage,
          mainDio,
          refreshDio: refreshDio,
        );
        mainDio.interceptors.add(interceptor);

        // Kick off a request that 401s and starts a refresh which will
        // never resolve on its own.
        final stuckRequest = mainDio.get<dynamic>('/a');
        // Let its onError reach _isRefreshing = true before logout happens.
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Logout resets the interceptor's bookkeeping — same call
        // LogoutNotifier makes via Dio.resetAuthRefreshState().
        interceptor.resetRefreshState();

        // A fresh 401 for a different request must not wait on the orphaned
        // completer — it starts (and completes) its own refresh.
        final secondResponse = await mainDio
            .get<dynamic>('/b')
            .timeout(const Duration(seconds: 2));

        expect(secondResponse.statusCode, 200);
        expect(
          refreshCalls,
          2,
          reason: 'the second request ran its own refresh rather than '
              'reusing the stuck one',
        );

        // Let the first refresh resolve so nothing leaks past the test —
        // its retry then goes through normally with the token it got.
        firstRefreshGate.complete(
          _json(200, {'accessToken': 'ignored', 'refreshToken': 'ignored'}),
        );
        await stuckRequest;
      },
    );

    test('resetAuthRefreshState is a no-op on a Dio with no AuthInterceptor', () {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      expect(() => dio.resetAuthRefreshState(), returnsNormally);
    });
  });
}
