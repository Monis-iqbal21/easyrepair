import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/network/api_client.dart';
import 'package:handygo_app/core/storage/secure_storage_service.dart';
import 'package:handygo_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:handygo_app/features/auth/data/repositories/auth_repository_impl.dart';

/// Covers the password-login-shows-"Session expired" bug end to end:
///  * Password login (Client and Worker) must work with no tokens at all —
///    the state right after logout or a fresh app restart.
///  * A wrong password must surface the backend's own message, never the
///    generic session-expired copy.
///  * Public auth endpoints (login, register, OTP, reset) must never carry
///    an Authorization header and must never trigger the refresh dance on a
///    401 — that's what `publicDioProvider` exists for.
///  * Logout must clear both tokens regardless of whether the backend call
///    itself succeeds.
///  * OTP login must keep working — the fix must not change that path.

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

ResponseBody _jsonBody(int status, Map<String, dynamic> data) {
  return ResponseBody.fromString(
    jsonEncode({'data': data}),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

ResponseBody _errorBody(int status, String message) {
  return ResponseBody.fromString(
    jsonEncode({'message': message}),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Map<String, dynamic> _authPayload({String role = 'CLIENT'}) => {
      'accessToken': 'access-1',
      'refreshToken': 'refresh-1',
      'user': {
        'id': 'u1',
        'phone': '+923001234567',
        'role': role,
        'firstName': 'Ali',
        'lastName': 'Khan',
      },
    };

Dio _dio(_Handler handler) =>
    Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = _FakeAdapter(handler);

void main() {
  group('Password login after logout / app restart', () {
    test(
      'Client password login succeeds with no tokens in storage '
      '(post-logout state)',
      () async {
        final storage = _FakeSecureStorage(); // no tokens at all
        RequestOptions? seen;
        final publicDio = _dio((options) async {
          seen = options;
          return _jsonBody(200, _authPayload());
        });
        final repo = AuthRepositoryImpl(
          AuthRemoteDatasource(publicDio, Dio(BaseOptions(baseUrl: 'http://test'))),
          storage,
        );

        final result = await repo.clientPasswordLogin(
          phone: '03001234567',
          password: 'correct-password',
        );

        expect(result.isRight(), isTrue);
        expect(storage.accessToken, 'access-1');
        expect(storage.refreshToken, 'refresh-1');
        expect(seen?.path, '/auth/client/password-login');
      },
    );

    test(
      'Worker password login (generic /auth/login) succeeds with no tokens '
      'in storage (post-logout state)',
      () async {
        final storage = _FakeSecureStorage();
        RequestOptions? seen;
        final publicDio = _dio((options) async {
          seen = options;
          return _jsonBody(200, _authPayload(role: 'WORKER'));
        });
        final repo = AuthRepositoryImpl(
          AuthRemoteDatasource(publicDio, Dio(BaseOptions(baseUrl: 'http://test'))),
          storage,
        );

        final result = await repo.login(
          phone: '03001234567',
          password: 'correct-password',
        );

        expect(result.isRight(), isTrue);
        expect(storage.accessToken, 'access-1');
        expect(seen?.path, '/auth/login');
      },
    );

    test(
      'password login also succeeds when storage never had a refresh token '
      'either — the exact shape of a fresh app restart',
      () async {
        final storage = _FakeSecureStorage();
        expect(storage.accessToken, isNull);
        expect(storage.refreshToken, isNull);

        final publicDio = _dio((options) async => _jsonBody(200, _authPayload()));
        final repo = AuthRepositoryImpl(
          AuthRemoteDatasource(publicDio, Dio(BaseOptions(baseUrl: 'http://test'))),
          storage,
        );

        final result = await repo.clientPasswordLogin(
          phone: '03001234567',
          password: 'correct-password',
        );

        expect(result.isRight(), isTrue);
      },
    );
  });

  group('wrong credentials show the real reason, never "session expired"', () {
    test('wrong password on Worker login', () async {
      final storage = _FakeSecureStorage();
      final publicDio = _dio(
        (options) async => _errorBody(401, 'Invalid phone number or password'),
      );
      final repo = AuthRepositoryImpl(
        AuthRemoteDatasource(publicDio, Dio(BaseOptions(baseUrl: 'http://test'))),
        storage,
      );

      final result = await repo.login(phone: '03001234567', password: 'wrong');

      expect(result.isLeft(), isTrue);
      final failure = result.fold((f) => f, (_) => throw StateError('expected Left'));
      expect(failure, isA<UnauthorizedFailure>());
      expect(failure.message, 'Invalid phone number or password');
      // Never saved tokens for a failed attempt.
      expect(storage.accessToken, isNull);
    });

    test('wrong password on Client password login', () async {
      final storage = _FakeSecureStorage();
      final publicDio = _dio(
        (options) async => _errorBody(401, 'Invalid phone number or password'),
      );
      final repo = AuthRepositoryImpl(
        AuthRemoteDatasource(publicDio, Dio(BaseOptions(baseUrl: 'http://test'))),
        storage,
      );

      final result = await repo.clientPasswordLogin(
        phone: '03001234567',
        password: 'wrong',
      );

      final failure = result.fold((f) => f, (_) => throw StateError('expected Left'));
      expect(failure.message, 'Invalid phone number or password');
    });

    test('an inactive/rejected account (403) still shows its own message', () async {
      final storage = _FakeSecureStorage();
      final publicDio = _dio(
        (options) async => ResponseBody.fromString(
          jsonEncode({'message': 'Account is deactivated'}),
          403,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final repo = AuthRepositoryImpl(
        AuthRemoteDatasource(publicDio, Dio(BaseOptions(baseUrl: 'http://test'))),
        storage,
      );

      final result = await repo.login(phone: '03001234567', password: 'x');
      final failure = result.fold((f) => f, (_) => throw StateError('expected Left'));

      expect(failure, isA<ForbiddenFailure>());
      expect(failure.message, 'Account is deactivated');
    });
  });

  group('public auth Dio client', () {
    test(
      'never attaches an Authorization header, even with a stale token '
      'sitting in storage',
      () async {
        final storage = _FakeSecureStorage()..accessToken = 'stale-leftover-token';
        final container = ProviderContainer(
          overrides: [secureStorageServiceProvider.overrideWithValue(storage)],
        );
        addTearDown(container.dispose);

        final dio = container.read(publicDioProvider);
        RequestOptions? seen;
        dio.httpClientAdapter = _FakeAdapter((options) async {
          seen = options;
          return _jsonBody(200, _authPayload());
        });

        await dio.post(
          '/auth/client/password-login',
          data: {'phone': '03001234567', 'password': 'x'},
        );

        expect(seen, isNotNull);
        expect(seen!.headers.containsKey('Authorization'), isFalse);
      },
    );

    test(
      'a 401 from a public auth endpoint never triggers a refresh attempt '
      'or a retry — exactly one request reaches the server',
      () async {
        final storage = _FakeSecureStorage()..refreshToken = 'some-refresh-token';
        final container = ProviderContainer(
          overrides: [secureStorageServiceProvider.overrideWithValue(storage)],
        );
        addTearDown(container.dispose);

        final dio = container.read(publicDioProvider);
        final seenPaths = <String>[];
        dio.httpClientAdapter = _FakeAdapter((options) async {
          seenPaths.add(options.path);
          return _errorBody(401, 'Invalid phone number or password');
        });

        await expectLater(
          dio.post(
            '/auth/client/password-login',
            data: {'phone': '03001234567', 'password': 'wrong'},
          ),
          throwsA(isA<DioException>()),
        );

        expect(seenPaths, ['/auth/client/password-login']);
        expect(seenPaths, isNot(contains('/auth/refresh')));
        // The 401 never triggered a token clear either — nothing about the
        // (irrelevant) refresh token in storage was touched.
        expect(storage.refreshToken, 'some-refresh-token');
      },
    );
  });

  group('logout clears all auth/session state', () {
    test('tokens are cleared even when the backend logout call fails', () async {
      final storage = _FakeSecureStorage()
        ..accessToken = 'a1'
        ..refreshToken = 'r1';
      final protectedDio = _dio(
        (options) async => ResponseBody.fromString(
          jsonEncode({'message': 'boom'}),
          500,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final repo = AuthRepositoryImpl(
        AuthRemoteDatasource(Dio(BaseOptions(baseUrl: 'http://test')), protectedDio),
        storage,
      );

      final result = await repo.logout();

      expect(result.isLeft(), isTrue);
      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
      expect(storage.clearCount, 1);
    });

    test('tokens are cleared on a successful backend logout too', () async {
      final storage = _FakeSecureStorage()
        ..accessToken = 'a1'
        ..refreshToken = 'r1';
      final protectedDio = _dio(
        (options) async => ResponseBody.fromString(
          '{}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final repo = AuthRepositoryImpl(
        AuthRemoteDatasource(Dio(BaseOptions(baseUrl: 'http://test')), protectedDio),
        storage,
      );

      final result = await repo.logout();

      expect(result.isRight(), isTrue);
      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
    });
  });

  group('the account role only ever comes from the login response', () {
    // Neither AuthRepositoryImpl nor AuthRemoteDatasource takes a "role" or
    // "selected auth flow" argument anywhere — structurally, nothing but the
    // backend's own JSON can end up in AuthTokensEntity.user.role, no matter
    // which role a user tapped on the selection page beforehand.
    test('a CLIENT backend response reports role CLIENT', () async {
      final storage = _FakeSecureStorage();
      final publicDio = _dio((options) async => _jsonBody(200, _authPayload(role: 'CLIENT')));
      final repo = AuthRepositoryImpl(
        AuthRemoteDatasource(publicDio, Dio(BaseOptions(baseUrl: 'http://test'))),
        storage,
      );

      final result = await repo.clientPasswordLogin(
        phone: '03001234567',
        password: 'x',
      );

      final tokens = result.fold((f) => throw StateError('expected Right'), (t) => t);
      expect(tokens.user.role, 'CLIENT');
    });

    test('a WORKER backend response reports role WORKER', () async {
      final storage = _FakeSecureStorage();
      final publicDio = _dio((options) async => _jsonBody(200, _authPayload(role: 'WORKER')));
      final repo = AuthRepositoryImpl(
        AuthRemoteDatasource(publicDio, Dio(BaseOptions(baseUrl: 'http://test'))),
        storage,
      );

      // Same call shape as the CLIENT case above — the role comes from the
      // response body, never from which auth page the request was made on.
      final result = await repo.login(phone: '03001234567', password: 'x');

      final tokens = result.fold((f) => throw StateError('expected Right'), (t) => t);
      expect(tokens.user.role, 'WORKER');
    });
  });

  group('OTP login keeps working', () {
    test('Client OTP login', () async {
      final storage = _FakeSecureStorage();
      final publicDio = _dio((options) async => _jsonBody(200, _authPayload()));
      final repo = AuthRepositoryImpl(
        AuthRemoteDatasource(publicDio, Dio(BaseOptions(baseUrl: 'http://test'))),
        storage,
      );

      final result = await repo.clientOtpLogin(
        fullName: 'Ali Khan',
        phone: '03001234567',
        otp: '123456',
      );

      expect(result.isRight(), isTrue);
      expect(storage.accessToken, 'access-1');
    });

    test('Worker OTP login', () async {
      final storage = _FakeSecureStorage();
      final publicDio = _dio(
        (options) async => _jsonBody(200, _authPayload(role: 'WORKER')),
      );
      final repo = AuthRepositoryImpl(
        AuthRemoteDatasource(publicDio, Dio(BaseOptions(baseUrl: 'http://test'))),
        storage,
      );

      final result = await repo.workerOtpLogin(
        phone: '03001234567',
        otp: '123456',
      );

      expect(result.isRight(), isTrue);
      expect(storage.accessToken, 'access-1');
    });
  });
}
