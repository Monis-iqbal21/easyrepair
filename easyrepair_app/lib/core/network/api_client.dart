import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import '../errors/dio_failure_mapper.dart' as failure_mapper;
import '../errors/failures.dart';
import '../storage/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;
  final Dio _dio;
  final Dio _refreshDio;

  bool _isRefreshing = false;
  Completer<void>? _refreshCompleter;

  /// The client used for `/auth/refresh`, exposed so a test can assert it is
  /// bounded — an unbounded refresh stalls every queued 401 behind it.
  @visibleForTesting
  Dio get refreshDio => _refreshDio;

  /// [refreshDio] is injectable purely so tests can point the `/auth/refresh`
  /// call at a fake adapter instead of the network; production always uses
  /// the default (a plain client with no interceptors, same as before this
  /// was hoisted out of `onError` into a field).
  AuthInterceptor(this._storage, this._dio, {Dio? refreshDio})
      : _refreshDio = refreshDio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                // Must be bounded like the main client. A refresh that never
                // returns holds `_isRefreshing` true forever, and every later
                // 401 then waits on a completer that never settles — the
                // request never fails, so the screen spins with no error.
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                sendTimeout: const Duration(seconds: 10),
              ),
            );

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _storage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      debugPrint('[AuthInterceptor] getAccessToken failed: $e');
    }
    handler.next(options);
  }

  /// Retries [requestOptions] with a fresh access token. `FormData` bodies
  /// (e.g. the inspection report multipart upload) are single-use — Dio
  /// throws a `StateError` re-finalizing a body that was already streamed
  /// during the original, now-401'd attempt — so a `FormData` body must be
  /// cloned before the request can be resent.
  Future<Response<dynamic>> _retryWithToken(
    RequestOptions requestOptions,
    String accessToken,
  ) {
    requestOptions.headers['Authorization'] = 'Bearer $accessToken';
    if (requestOptions.data is FormData) {
      requestOptions.data = (requestOptions.data as FormData).clone();
    }
    // Marks this request as already having gone through one auth-refresh
    // retry, so a 401 on the retry itself is never retried again below —
    // otherwise a persistently-401'ing endpoint would refresh forever.
    requestOptions.extra['_authRetried'] = true;
    return _dio.fetch(requestOptions);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    if (err.requestOptions.extra['_authRetried'] == true) {
      handler.next(err);
      return;
    }

    if (_isRefreshing) {
      try {
        await _refreshCompleter!.future;
      } catch (_) {
        // The in-flight refresh this request was waiting on failed — fall
        // through to the original 401 rather than let that error escape
        // uncaught from this handler (which would leave the request stuck
        // instead of ever resolving/rejecting).
        handler.next(err);
        return;
      }
      final token = await _storage.getAccessToken();
      if (token == null) {
        handler.next(err);
        return;
      }
      try {
        final retryResponse = await _retryWithToken(err.requestOptions, token);
        handler.resolve(retryResponse);
      } catch (e) {
        // The retry's own failure — not the original 401 — is what actually
        // happened here. A transient network blip on the retry must surface
        // as that (a NetworkFailure/timeout), never silently reappear as
        // the stale original 401 — that's exactly the shape of failure that
        // must never be mistaken for "the session is over".
        handler.next(e is DioException ? e : err);
      }
      return;
    }

    _isRefreshing = true;
    // Captured once, up front, and used for every completion below instead
    // of re-reading the `_refreshCompleter` field later. `resetRefreshState`
    // (called on logout) can null that field out from under a refresh that
    // is still in flight — completing/erroring THIS local reference instead
    // means that late finish can never null-check-crash, while a fresh
    // request started after the reset still correctly starts its own
    // refresh rather than waiting on this orphaned one (it only ever reads
    // the instance field, which the reset already cleared).
    final completer = Completer<void>();
    _refreshCompleter = completer;
    // A completer that errors with nothing ever listening to its `.future`
    // surfaces as an unhandled async error — harmless in production (Dio's
    // own error still reaches the caller via `handler.next` below) but worth
    // silencing at the source rather than relying on a follower always being
    // there to observe it.
    unawaited(completer.future.catchError((_) {}));

    String accessToken;
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        await _storage.clearTokens();
        completer.complete();
        handler.next(err);
        return;
      }

      final refreshResponse = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final data = refreshResponse.data['data'] ?? refreshResponse.data;
      accessToken = data['accessToken'] as String;
      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: data['refreshToken'] as String,
      );

      completer.complete();
    } catch (e) {
      // Only a definitive rejection from the refresh endpoint itself — it
      // responds 401 specifically when the refresh token is invalid,
      // expired, or revoked (see AuthService.refreshTokens) — means the
      // session is actually over. Any other error (a transient network
      // failure, a timeout, or the refresh endpoint returning a 5xx/429)
      // must never clear a still-valid session; the next request simply
      // gets to try the refresh again.
      final isDefiniteAuthRejection =
          e is DioException && e.response?.statusCode == 401;
      if (isDefiniteAuthRejection) {
        await _storage.clearTokens();
      }
      completer.completeError('refresh_failed');
      handler.next(err);
      return;
    } finally {
      // Only clear bookkeeping that still belongs to THIS refresh — a
      // concurrent reset (logout) or a newer refresh that started after
      // this one was orphaned must never have its state clobbered by this
      // one finishing late.
      if (identical(_refreshCompleter, completer)) {
        _isRefreshing = false;
        _refreshCompleter = null;
      }
    }

    // The refresh itself succeeded — retrying the original request from
    // here on is a separate concern. Its failure (e.g. the backend still
    // rejects it for an unrelated reason, or a stream-based body couldn't be
    // resent) must only fail *this* request, never reach back into the
    // refresh completer above, which has already settled successfully.
    try {
      final retryResponse = await _retryWithToken(err.requestOptions, accessToken);
      handler.resolve(retryResponse);
    } catch (e) {
      // Same reasoning as the shared-refresh branch above: the retry's own
      // exception (e.g. a timeout right after a successful refresh) must
      // propagate as itself, not as the stale pre-refresh 401 — otherwise a
      // one-off network blip on the retry reads exactly like an expired
      // session even though the refresh that just happened proves it isn't.
      handler.next(e is DioException ? e : err);
    }
  }

  /// Clears in-flight refresh bookkeeping. Called on logout so a refresh
  /// that was starting (or running) right as the user signed out can never
  /// leave this interceptor believing a refresh is still in progress for
  /// the next session.
  void resetRefreshState() {
    _isRefreshing = false;
    _refreshCompleter = null;
  }
}

extension DioAuthReset on Dio {
  /// Resets [AuthInterceptor]'s in-memory refresh state, if one is attached
  /// to this client's interceptor chain. A no-op otherwise (e.g. the public,
  /// pre-login Dio never has one).
  void resetAuthRefreshState() {
    for (final interceptor in interceptors) {
      if (interceptor is AuthInterceptor) interceptor.resetRefreshState();
    }
  }
}

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}

/// Delegates to the canonical mapper in `core/errors/dio_failure_mapper.dart`
/// — this file used to have its own separate, less complete implementation
/// (missing 400/429 handling, and crashing on NestJS's class-validator array
/// `message` responses via an unsafe `as String` cast). Kept as a thin
/// re-export so the 5 datasources already importing `dioExceptionToFailure`
/// from here don't need an import-path change.
///
/// [preserveUnauthorizedMessage]: see the mapper's own doc — only public,
/// pre-login auth endpoints (password login, register, OTP, reset) should
/// ever pass `true`.
Failure dioExceptionToFailure(
  DioException e, {
  bool preserveUnauthorizedMessage = false,
}) =>
    failure_mapper.dioExceptionToFailure(
      e,
      preserveUnauthorizedMessage: preserveUnauthorizedMessage,
    );

Dio _buildDio() {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      // Without this an upload that stalls mid-body never times out, and the
      // calling screen's loader never clears.
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );
}

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  final dio = _buildDio();

  dio.interceptors.addAll([
    AuthInterceptor(storage, dio),
    ErrorInterceptor(),
    if (kDebugMode) PrettyDioLogger(requestBody: true, responseBody: true),
  ]);

  return dio;
});

/// A Dio client for the public, pre-login auth endpoints only (login,
/// register, OTP request/verify, password reset, phone-check). Deliberately
/// carries no [AuthInterceptor]:
///
///  * No stale/leftover access token is ever attached to a request that
///    doesn't need one — these endpoints authenticate the *request body*
///    (phone + password/OTP), not the caller.
///  * A 401 here (wrong password, unknown account) is never mistaken for an
///    expired session — nothing tries to refresh a token or clear storage on
///    it, so it reaches the repository as a plain rejected request and the
///    backend's real message survives (see dioExceptionToFailure's
///    `preserveUnauthorizedMessage`).
///
/// `/auth/logout`, `/auth/me` and `/auth/account` are genuinely protected —
/// [AuthRemoteDatasource] keeps using [dioProvider] for those.
final publicDioProvider = Provider<Dio>((ref) {
  final dio = _buildDio();

  dio.interceptors.addAll([
    ErrorInterceptor(),
    if (kDebugMode) PrettyDioLogger(requestBody: true, responseBody: true),
  ]);

  return dio;
});
