import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

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
  Future<MessageModel> sendMediaMessage(
    String conversationId,
    String filePath,
    String mimeType,
  );
  Future<MessageModel> sendVoiceMessage(
    String conversationId,
    String filePath,
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
  Future<MessageModel> deleteMessage(
    String conversationId,
    String messageId,
  );
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

  @override
  Future<MessageModel> sendMediaMessage(
    String conversationId,
    String filePath,
    String mimeType,
  ) async {
    try {
      final fileName = filePath.split('/').last;
      final parts = mimeType.split('/');
      final contentType =
          parts.length == 2 ? MediaType(parts[0], parts[1]) : null;
      final isVideo = mimeType.startsWith('video/');

      final Map<String, dynamic> fields = {
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: contentType,
        ),
      };

      if (isVideo) {
        try {
          final tmpDir = await getTemporaryDirectory();
          final thumbPath = await VideoThumbnail.thumbnailFile(
            video: filePath,
            thumbnailPath: tmpDir.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 512,
            quality: 75,
          );
          if (thumbPath != null && await File(thumbPath).exists()) {
            fields['thumbnail'] = await MultipartFile.fromFile(
              thumbPath,
              filename: 'thumb.jpg',
              contentType: MediaType('image', 'jpeg'),
            );
          }
        } catch (_) {
          // Thumbnail generation failed — proceed without it; backend handles null
        }
      }

      final formData = FormData.fromMap(fields);
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
  ) async {
    try {
      final fileName = filePath.split('/').last;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: MediaType('audio', 'm4a'),
        ),
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
