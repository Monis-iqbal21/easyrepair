import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _dataSource;

  const ChatRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation(
    String workerProfileId,
  ) async {
    try {
      final model = await _dataSource.getOrCreateConversation(workerProfileId);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ConversationEntity>>> getConversations() async {
    try {
      final models = await _dataSource.getConversations();
      return Right(models.map((m) => m.toEntity()).toList());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async {
    try {
      final models = await _dataSource.getMessages(
        conversationId,
        limit: limit,
        before: before,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendMessage(
    String conversationId,
    String text,
  ) async {
    try {
      final model = await _dataSource.sendMessage(conversationId, text);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendMediaMessage(
    String conversationId,
    String filePath,
    String mimeType,
  ) async {
    try {
      final model =
          await _dataSource.sendMediaMessage(conversationId, filePath, mimeType);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendVoiceMessage(
    String conversationId,
    String filePath,
  ) async {
    try {
      final model = await _dataSource.sendVoiceMessage(conversationId, filePath);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendLocationMessage(
    String conversationId,
    double latitude,
    double longitude,
  ) async {
    try {
      final model = await _dataSource.sendLocationMessage(
        conversationId,
        latitude,
        longitude,
      );
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> editMessage(
    String conversationId,
    String messageId,
    String text,
  ) async {
    try {
      final model =
          await _dataSource.editMessage(conversationId, messageId, text);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> deleteMessage(
    String conversationId,
    String messageId,
  ) async {
    try {
      final model = await _dataSource.deleteMessage(conversationId, messageId);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
