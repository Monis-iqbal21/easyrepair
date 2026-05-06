import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
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
    } catch (_) {
      await _storage.clearTokens();
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

Failure dioExceptionToFailure(DioException e) {
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout) {
    return const NetworkFailure('No internet connection');
  }

  final statusCode = e.response?.statusCode;
  final message = e.response?.data?['message'] as String? ??
      e.response?.data?['error'] as String? ??
      'An unexpected error occurred';

  return switch (statusCode) {
    401 => UnauthorizedFailure(message),
    409 => ConflictFailure(message),
    422 => ValidationFailure(message),
    _ => ServerFailure(message),
  };
}

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
