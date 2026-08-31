import 'package:fpdart/fpdart.dart';

import '../../../../core/data/cached_result.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _dataSource;

  const ChatRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation(
    String bookingId,
    String workerProfileId,
  ) async {
    try {
      final model = await _dataSource.getOrCreateConversation(
        bookingId,
        workerProfileId,
      );
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(
        ServerFailure('', code: FailureCode.unknown, diagnostic: e.toString()),
      );
    }
  }

  @override
  Future<Either<Failure, ConversationEntity>> getOrCreateConversationForBooking(
    String bookingId,
  ) async {
    try {
      final model = await _dataSource.getOrCreateConversationForBooking(
        bookingId,
      );
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(
        ServerFailure('', code: FailureCode.unknown, diagnostic: e.toString()),
      );
    }
  }

  @override
  Future<Either<Failure, void>> ensureSupportConversation() async {
    try {
      await _dataSource.ensureSupportConversation();
      return const Right(null);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(
        ServerFailure('', code: FailureCode.unknown, diagnostic: e.toString()),
      );
    }
  }

  @override
  Future<Either<Failure, CachedResult<List<ConversationEntity>>>>
  getConversations() async {
    try {
      final result = await _dataSource.getConversations();
      return Right(
        CachedResult(
          result.data.map((m) => m.toEntity()).toList(),
          isStale: result.isStale,
        ),
      );
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(
        ServerFailure('', code: FailureCode.unknown, diagnostic: e.toString()),
      );
    }
  }

  @override
  Future<Either<Failure, CachedResult<List<MessageEntity>>>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async {
    try {
      final result = await _dataSource.getMessages(
        conversationId,
        limit: limit,
        before: before,
      );
      return Right(
        CachedResult(
          result.data.map((m) => m.toEntity()).toList(),
          isStale: result.isStale,
        ),
      );
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(
        ServerFailure('', code: FailureCode.unknown, diagnostic: e.toString()),
      );
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendMessage(
    String conversationId,
    String text,
  ) async {
    final offline = offlineActionGuard();
    if (offline != null) return Left(offline);
    try {
      final model = await _dataSource.sendMessage(conversationId, text);
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(
        ServerFailure('', code: FailureCode.unknown, diagnostic: e.toString()),
      );
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendMediaMessage(
    String conversationId,
    String filePath,
    String mimeType,
  ) async {
    final offline = offlineActionGuard();
    if (offline != null) return Left(offline);
    try {
      final model = await _dataSource.sendMediaMessage(
        conversationId,
        filePath,
        mimeType,
      );
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(
        ServerFailure('', code: FailureCode.unknown, diagnostic: e.toString()),
      );
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendVoiceMessage(
    String conversationId,
    String filePath,
    double durationSeconds,
  ) async {
    final offline = offlineActionGuard();
    if (offline != null) return Left(offline);
    try {
      final model = await _dataSource.sendVoiceMessage(
        conversationId,
        filePath,
        durationSeconds,
      );
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(
        ServerFailure('', code: FailureCode.unknown, diagnostic: e.toString()),
      );
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendLocationMessage(
    String conversationId,
    double latitude,
    double longitude,
  ) async {
    final offline = offlineActionGuard();
    if (offline != null) return Left(offline);
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
      return Left(
        ServerFailure('', code: FailureCode.unknown, diagnostic: e.toString()),
      );
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> editMessage(
    String conversationId,
    String messageId,
    String text,
  ) async {
    try {
      final model = await _dataSource.editMessage(
        conversationId,
        messageId,
        text,
      );
      return Right(model.toEntity());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(
        ServerFailure('', code: FailureCode.unknown, diagnostic: e.toString()),
      );
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
      return Left(
        ServerFailure('', code: FailureCode.unknown, diagnostic: e.toString()),
      );
    }
  }
}
