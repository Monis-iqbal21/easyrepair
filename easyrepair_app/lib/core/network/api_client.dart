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

  bool _isRefreshing = false;
  Completer<void>? _refreshCompleter;

  AuthInterceptor(this._storage, this._dio);

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

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    if (_isRefreshing) {
      await _refreshCompleter!.future;
      final token = await _storage.getAccessToken();
      if (token != null) {
        err.requestOptions.headers['Authorization'] = 'Bearer $token';
        try {
          final retryResponse = await _dio.fetch(err.requestOptions);
          handler.resolve(retryResponse);
          return;
        } catch (e) {
          handler.next(err);
          return;
        }
      }
      handler.next(err);
      return;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<void>();

    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        await _storage.clearTokens();
        _refreshCompleter!.complete();
        handler.next(err);
        return;
      }

      final refreshDio = Dio(
        BaseOptions(baseUrl: AppConfig.apiBaseUrl),
      );
      final refreshResponse = await refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final data = refreshResponse.data['data'] ?? refreshResponse.data;
      await _storage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );

      _refreshCompleter!.complete();

      err.requestOptions.headers['Authorization'] =
          'Bearer ${data['accessToken']}';
      final retryResponse = await _dio.fetch(err.requestOptions);
      handler.resolve(retryResponse);
    } catch (e) {
      // Only a definitive rejection from the server (the refresh token
      // itself is invalid/expired/revoked) means the session is actually
      // over. A transient network failure while refreshing — e.g. the app
      // resuming from background mid-upload, before connectivity is fully
      // re-established — must never clear a still-valid session; the next
      // request simply gets to try the refresh again.
      final isDefiniteAuthRejection = e is DioException && e.response != null;
      if (isDefiniteAuthRejection) {
        await _storage.clearTokens();
      }
      _refreshCompleter!.completeError('refresh_failed');
      handler.next(err);
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
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
Failure dioExceptionToFailure(DioException e) =>
    failure_mapper.dioExceptionToFailure(e);

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(storage, dio),
    ErrorInterceptor(),
    if (kDebugMode) PrettyDioLogger(requestBody: true, responseBody: true),
  ]);

  return dio;
});
