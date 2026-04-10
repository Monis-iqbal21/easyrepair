import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/chat_entities.dart';

abstract class ChatRepository {
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation(
    String workerProfileId,
  );
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
}
