import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../models/chat_models.dart';

abstract class ChatRemoteDataSource {
  Future<ConversationModel> getOrCreateConversation(String workerProfileId);
  Future<List<ConversationModel>> getConversations();
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int limit,
    String? before,
  });
  Future<MessageModel> sendMessage(String conversationId, String text);
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final Dio _dio;

  const ChatRemoteDataSourceImpl(this._dio);

  @override
  Future<ConversationModel> getOrCreateConversation(
    String workerProfileId,
  ) async {
    try {
      final response = await _dio.post(
        '/chat/conversations',
        data: {'workerProfileId': workerProfileId},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return ConversationModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<List<ConversationModel>> getConversations() async {
    try {
      final response = await _dio.get('/chat/conversations');
      final data = response.data['data'] as List<dynamic>;
      return data
          .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async {
    try {
      final response = await _dio.get(
        '/chat/conversations/$conversationId/messages',
        queryParameters: {
          'limit': limit,
          if (before != null) 'before': before,
        },
      );
      final data = response.data['data'] as List<dynamic>;
      return data
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<MessageModel> sendMessage(
    String conversationId,
    String text,
  ) async {
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
}
