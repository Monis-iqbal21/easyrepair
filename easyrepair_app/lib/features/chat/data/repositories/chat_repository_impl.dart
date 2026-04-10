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
}
