import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../../../core/data/cached_result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/cacheable_fetch.dart';
import '../../../../core/storage/local_cache_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/chat_models.dart';

abstract class ChatRemoteDataSource {
  Future<ConversationModel> getOrCreateConversation(
    String bookingId,
    String workerProfileId,
  );
  Future<ConversationModel> getOrCreateConversationForBooking(String bookingId);

  /// Idempotent on the backend — safe to call on every Chat-tab load.
  Future<void> ensureSupportConversation();
  Future<CachedResult<List<ConversationModel>>> getConversations();
  Future<CachedResult<List<MessageModel>>> getMessages(
    String conversationId, {
    int limit,
    String? before,
  });
  Future<MessageModel> sendMessage(String conversationId, String text);
  Future<MessageModel> sendMediaMessage(
    String conversationId,
    String filePath,
    String mimeType,
  );
  Future<MessageModel> sendVoiceMessage(
    String conversationId,
    String filePath,
    double durationSeconds,
  );
  Future<MessageModel> sendLocationMessage(
    String conversationId,
    double latitude,
    double longitude,
  );
  Future<MessageModel> editMessage(
    String conversationId,
    String messageId,
    String text,
  );
  Future<MessageModel> deleteMessage(String conversationId, String messageId);
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final Dio _dio;
  final LocalCacheService _cache;
  final SecureStorageService _secureStorage;

  const ChatRemoteDataSourceImpl(this._dio, this._cache, this._secureStorage);

  @override
  Future<ConversationModel> getOrCreateConversation(
    String bookingId,
    String workerProfileId,
  ) async {
    try {
      final response = await _dio.post(
        '/chat/conversations',
        data: {'bookingId': bookingId, 'workerProfileId': workerProfileId},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return ConversationModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<ConversationModel> getOrCreateConversationForBooking(
    String bookingId,
  ) async {
    try {
      final response = await _dio.post(
        '/chat/conversations/for-booking',
        data: {'bookingId': bookingId},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return ConversationModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<void> ensureSupportConversation() async {
    try {
      await _dio.post('/chat/conversations/support');
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<CachedResult<List<ConversationModel>>> getConversations() {
    return fetchWithCache(
      cache: _cache,
      secureStorage: _secureStorage,
      cacheKey: 'chat_conversations',
      request: () async {
        final response = await _dio.get('/chat/conversations');
        return response.data['data'];
      },
      decode: (json) => (json as List<dynamic>)
          .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<CachedResult<List<MessageModel>>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) {
    Future<dynamic> request() async {
      final response = await _dio.get(
        '/chat/conversations/$conversationId/messages',
        queryParameters: {'limit': limit, 'before': ?before},
      );
      return response.data['data'];
    }

    List<MessageModel> decode(dynamic json) => (json as List<dynamic>)
        .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // Only the most-recent page (no `before` cursor) is cached for offline
    // read — a paginated "load older messages" request always needs the
    // network and never falls back to (necessarily different) cached data.
    if (before != null) {
      return _fetchPageUncached(request, decode);
    }

    return fetchWithCache(
      cache: _cache,
      secureStorage: _secureStorage,
      cacheKey: 'chat_messages:$conversationId',
      request: request,
      decode: decode,
    );
  }

  static Future<CachedResult<List<MessageModel>>> _fetchPageUncached(
    Future<dynamic> Function() request,
    List<MessageModel> Function(dynamic) decode,
  ) async {
    try {
      return CachedResult(decode(await request()));
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<MessageModel> sendMessage(String conversationId, String text) async {
    try {
      final response = await _dio.post(
        '/chat/conversations/$conversationId/messages',
        data: {'text': text},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return MessageModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<MessageModel> sendMediaMessage(
    String conversationId,
    String filePath,
    String mimeType,
  ) async {
    try {
      final fileName = filePath.split('/').last;
      final parts = mimeType.split('/');
      final contentType = parts.length == 2
          ? MediaType(parts[0], parts[1])
          : null;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: contentType,
        ),
      });

      final response = await _dio.post(
        '/chat/conversations/$conversationId/messages/media',
        data: formData,
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return MessageModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<MessageModel> sendVoiceMessage(
    String conversationId,
    String filePath,
    double durationSeconds,
  ) async {
    try {
      final fileName = filePath.split('/').last;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: MediaType('audio', 'm4a'),
        ),
        'durationSeconds': durationSeconds.toStringAsFixed(3),
      });

      final response = await _dio.post(
        '/chat/conversations/$conversationId/messages/voice',
        data: formData,
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return MessageModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<MessageModel> sendLocationMessage(
    String conversationId,
    double latitude,
    double longitude,
  ) async {
    try {
      final response = await _dio.post(
        '/chat/conversations/$conversationId/messages/location',
        data: {'latitude': latitude, 'longitude': longitude},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return MessageModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<MessageModel> editMessage(
    String conversationId,
    String messageId,
    String text,
  ) async {
    try {
      final response = await _dio.put(
        '/chat/conversations/$conversationId/messages/$messageId',
        data: {'text': text},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return MessageModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<MessageModel> deleteMessage(
    String conversationId,
    String messageId,
  ) async {
    try {
      final response = await _dio.delete(
        '/chat/conversations/$conversationId/messages/$messageId',
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return MessageModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }
}
