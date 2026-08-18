import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cached_result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/cacheable_fetch.dart';
import '../../../../core/storage/local_cache_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/notification_model.dart';

abstract class NotificationRemoteDatasource {
  /// The account's notification history, falling back to the last cached
  /// list when the server is unreachable (`CachedResult.isStale`).
  Future<CachedResult<List<NotificationModel>>> getNotifications();
  Future<int> getUnreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> saveFcmToken(String token);
}

class NotificationRemoteDatasourceImpl implements NotificationRemoteDatasource {
  final Dio _dio;
  final LocalCacheService _cache;
  final SecureStorageService _secureStorage;

  NotificationRemoteDatasourceImpl(this._dio, this._cache, this._secureStorage);

  @override
  Future<CachedResult<List<NotificationModel>>> getNotifications() {
    // Account history: the last known list stays viewable offline for as long
    // as it is the last thing the server told us. READ ONLY while offline —
    // markRead/markAllRead below are ordinary writes and are blocked by the
    // notifier's offline guard, so nothing is ever marked read locally and
    // then "synced later". The server remains the only authority on read
    // state, and a reconnect refetches it.
    return fetchWithCache(
      cache: _cache,
      secureStorage: _secureStorage,
      cacheKey: 'notifications',
      request: () async {
        final response = await _dio.get<Map<String, dynamic>>('/notifications');
        return response.data!['data'];
      },
      decode: (json) => (json as List<dynamic>)
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<int> getUnreadCount() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/notifications/unread-count');
    final data = response.data!['data'] as Map<String, dynamic>;
    return data['count'] as int? ?? 0;
  }

  @override
  Future<void> markRead(String id) async {
    await _dio.patch<void>('/notifications/$id/read');
  }

  @override
  Future<void> markAllRead() async {
    await _dio.patch<void>('/notifications/read-all');
  }

  @override
  Future<void> saveFcmToken(String token) async {
    await _dio.post<void>('/auth/fcm-token', data: {'token': token});
  }
}

final notificationRemoteDatasourceProvider =
    Provider<NotificationRemoteDatasource>((ref) {
  return NotificationRemoteDatasourceImpl(
    ref.watch(dioProvider),
    ref.watch(localCacheServiceProvider),
    ref.watch(secureStorageServiceProvider),
  );
});
