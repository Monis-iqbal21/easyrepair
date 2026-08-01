import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/chat_entities.dart';

abstract class ChatRepository {
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation(
    String bookingId,
    String workerProfileId,
  );
  Future<Either<Failure, ConversationEntity>> getOrCreateConversationForBooking(
    String bookingId,
  );
  /// Guarantees the caller's permanent HandyGo Support thread exists.
  /// Idempotent — repeated calls never create a second conversation.
  Future<Either<Failure, void>> ensureSupportConversation();
  Future<Either<Failure, List<ConversationEntity>>> getConversations();
  Future<Either<Failure, List<MessageEntity>>> getMessages(
    String conversationId, {
    int limit,
    String? before,
  });
  Future<Either<Failure, MessageEntity>> sendMessage(
    String conversationId,
    String text,
  );
  Future<Either<Failure, MessageEntity>> sendMediaMessage(
    String conversationId,
    String filePath,
    String mimeType,
  );
  Future<Either<Failure, MessageEntity>> sendVoiceMessage(
    String conversationId,
    String filePath,
  );
  Future<Either<Failure, MessageEntity>> sendLocationMessage(
    String conversationId,
    double latitude,
    double longitude,
  );
  Future<Either<Failure, MessageEntity>> editMessage(
    String conversationId,
    String messageId,
    String text,
  );
  Future<Either<Failure, MessageEntity>> deleteMessage(
    String conversationId,
    String messageId,
  );
}
