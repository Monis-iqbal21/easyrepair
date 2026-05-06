import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/notification_model.dart';

abstract class NotificationRemoteDatasource {
  Future<List<NotificationModel>> getNotifications();
  Future<int> getUnreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> saveFcmToken(String token);
}

class NotificationRemoteDatasourceImpl implements NotificationRemoteDatasource {
  final Dio _dio;

  NotificationRemoteDatasourceImpl(this._dio);

  @override
  Future<List<NotificationModel>> getNotifications() async {
    final response = await _dio.get<Map<String, dynamic>>('/notifications');
    final raw = response.data!['data'] as List<dynamic>;
    return raw
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
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
  return NotificationRemoteDatasourceImpl(ref.watch(dioProvider));
});
