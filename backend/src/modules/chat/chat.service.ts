import {
  Injectable,
  Logger,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { MessageType, Role } from '@prisma/client';
import { ChatRepository, ConversationWithParticipants } from './chat.repository';
import { ConversationResponseDto } from './dto/conversation-response.dto';
import { MessageResponseDto } from './dto/message-response.dto';
import { StorageService } from '../storage/storage.service';

@Injectable()
export class ChatService {
  private readonly logger = new Logger(ChatService.name);

  constructor(
    private readonly chatRepository: ChatRepository,
    private readonly storageService: StorageService,
  ) {}

  // ── Conversations ─────────────────────────────────────────────────────────

  /**
   * CLIENT action: create or retrieve the conversation with the given worker.
   * If a conversation already exists for this pair, it is returned as-is.
   * Workers cannot call this to initiate with a new client.
   */
  async getOrCreateConversation(
    clientUserId: string,
    workerProfileId: string,
  ): Promise<ConversationResponseDto> {
    // Resolve workerProfileId → workerUserId
    const worker =
      await this.chatRepository.findWorkerUserByProfileId(workerProfileId);
    if (!worker) throw new NotFoundException('Worker not found');

    const workerUserId = worker.userId;

    // Return existing conversation if one already exists
    const existing = await this.chatRepository.findConversation(
      clientUserId,
      workerUserId,
    );
    if (existing) {
      return this._toConversationDto(existing, clientUserId, Role.CLIENT);
    }

    // Create new conversation — client is the creator
    const created = await this.chatRepository.createConversation({
      clientUserId,
      workerUserId,
      createdByUserId: clientUserId,
    });
    return this._toConversationDto(created, clientUserId, Role.CLIENT);
  }

  /**
   * Called internally by the booking assignment flow.
   * Ensures a conversation exists for this client-worker pair — creates one
   * automatically (with a system message) if none exists yet.
   * If a conversation is already open, this is a no-op.
   *
   * This method NEVER throws — errors are logged and swallowed so they cannot
   * affect the booking assignment response.
   */
  async ensureConversationForBooking(
    clientUserId: string,
    workerUserId: string,
  ): Promise<void> {
    try {
      const existing = await this.chatRepository.findConversation(
        clientUserId,
        workerUserId,
      );
      if (existing) return; // conversation already open — nothing to do

      const created = await this.chatRepository.createConversation({
        clientUserId,
        workerUserId,
        createdByUserId: clientUserId,
      });

      await this.chatRepository.createSystemMessage({
        conversationId: created.id,
        senderUserId: clientUserId,
        text: 'Worker assigned to your booking',
      });
    } catch (err) {
      this.logger.warn(
        `[ensureConversationForBooking] failed for client=${clientUserId} worker=${workerUserId}: ${(err as Error)?.message}`,
      );
    }
  }

  /**
   * Return all conversations where the caller is a participant.
   * CLIENT: conversations they initiated.
   * WORKER: conversations clients opened with them.
   */
  async getMyConversations(
    userId: string,
    role: Role,
  ): Promise<ConversationResponseDto[]> {
    const conversations = await this.chatRepository.findConversationsByUserId(
      userId,
      role,
    );
    return conversations.map((c) => this._toConversationDto(c, userId, role));
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  /**
   * Return messages for a conversation.
   * Caller must be a participant (client or worker in that conversation).
   */
  async getMessages(
    userId: string,
    conversationId: string,
    limit = 50,
    before?: string,
  ): Promise<MessageResponseDto[]> {
    const conversation =
      await this.chatRepository.findConversationById(conversationId);
    if (!conversation) throw new NotFoundException('Conversation not found');

    this._assertParticipant(conversation, userId);

    const messages = await this.chatRepository.findMessages(
      conversationId,
      limit,
      before,
    );
    return messages.map((m) => this._toMessageDto(m));
  }

  /**
   * Send a text message to a conversation.
   * Caller must be a participant.
   */
  async sendMessage(
    userId: string,
    role: Role,
    conversationId: string,
    text: string,
  ): Promise<MessageResponseDto> {
    const conversation =
      await this.chatRepository.findConversationById(conversationId);
    if (!conversation) throw new NotFoundException('Conversation not found');

    this._assertParticipant(conversation, userId);

    const message = await this.chatRepository.createMessage({
      conversationId,
      senderUserId: userId,
      senderRole: role,
      text,
    });
    return this._toMessageDto(message);
  }

  // ── Media / voice / location ──────────────────────────────────────────────

  async sendMediaMessage(
    userId: string,
    role: Role,
    conversationId: string,
    buffer: Buffer,
    originalName: string,
    mimeType: string,
  ): Promise<MessageResponseDto> {
    const conversation =
      await this.chatRepository.findConversationById(conversationId);
    if (!conversation) throw new NotFoundException('Conversation not found');
    this._assertParticipant(conversation, userId);

    const isVideo = mimeType.startsWith('video/');
    const folder = isVideo ? 'chat-videos' : 'chat-images';
    const mediaUrl = await this.storageService.upload(
      buffer,
      originalName,
      mimeType,
      folder,
    );
    const message = await this.chatRepository.createMediaMessage({
      conversationId,
      senderUserId: userId,
      senderRole: role,
      type: isVideo ? MessageType.VIDEO : MessageType.IMAGE,
      mediaUrl,
    });
    return this._toMessageDto(message);
  }

  async sendVoiceMessage(
    userId: string,
    role: Role,
    conversationId: string,
    buffer: Buffer,
    originalName: string,
  ): Promise<MessageResponseDto> {
    const conversation =
      await this.chatRepository.findConversationById(conversationId);
    if (!conversation) throw new NotFoundException('Conversation not found');
    this._assertParticipant(conversation, userId);

    const mediaUrl = await this.storageService.upload(
      buffer,
      originalName,
      'audio/m4a',
      'chat-voice',
    );
    const message = await this.chatRepository.createVoiceMessage({
      conversationId,
      senderUserId: userId,
      senderRole: role,
      mediaUrl,
    });
    return this._toMessageDto(message);
  }

  async sendLocationMessage(
    userId: string,
    role: Role,
    conversationId: string,
    latitude: number,
    longitude: number,
  ): Promise<MessageResponseDto> {
    const conversation =
      await this.chatRepository.findConversationById(conversationId);
    if (!conversation) throw new NotFoundException('Conversation not found');
    this._assertParticipant(conversation, userId);

    const message = await this.chatRepository.createLocationMessage({
      conversationId,
      senderUserId: userId,
      senderRole: role,
      latitude,
      longitude,
    });
    return this._toMessageDto(message);
  }

  // ── Edit / delete ─────────────────────────────────────────────────────────

  async editMessage(
    userId: string,
    conversationId: string,
    messageId: string,
    text: string,
  ): Promise<MessageResponseDto> {
    const conversation =
      await this.chatRepository.findConversationById(conversationId);
    if (!conversation) throw new NotFoundException('Conversation not found');
    this._assertParticipant(conversation, userId);

    const message = await this.chatRepository.findMessageById(messageId);
    if (!message) throw new NotFoundException('Message not found');
    if (message.conversationId !== conversationId)
      throw new ForbiddenException('Message not in this conversation');
    if (message.senderUserId !== userId)
      throw new ForbiddenException("Cannot edit another user's message");
    if (message.type !== MessageType.TEXT)
      throw new BadRequestException('Only text messages can be edited');
    if (message.deletedAt)
      throw new BadRequestException('Cannot edit a deleted message');

    const ageMs = Date.now() - message.createdAt.getTime();
    if (ageMs > 5 * 60 * 1000)
      throw new BadRequestException('Edit window has expired (5 minutes)');

    const updated = await this.chatRepository.updateMessageText(
      messageId,
      text,
      new Date(),
    );
    return this._toMessageDto(updated);
  }

  async deleteMessage(
    userId: string,
    conversationId: string,
    messageId: string,
  ): Promise<MessageResponseDto> {
    const conversation =
      await this.chatRepository.findConversationById(conversationId);
    if (!conversation) throw new NotFoundException('Conversation not found');
    this._assertParticipant(conversation, userId);

    const message = await this.chatRepository.findMessageById(messageId);
    if (!message) throw new NotFoundException('Message not found');
    if (message.conversationId !== conversationId)
      throw new ForbiddenException('Message not in this conversation');
    if (message.senderUserId !== userId)
      throw new ForbiddenException("Cannot delete another user's message");
    if (message.deletedAt)
      throw new BadRequestException('Message already deleted');

    const ageMs = Date.now() - message.createdAt.getTime();
    if (ageMs > 5 * 60 * 1000)
      throw new BadRequestException('Delete window has expired (5 minutes)');

    const updated = await this.chatRepository.softDeleteMessage(
      messageId,
      new Date(),
    );
    return this._toMessageDto(updated);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /** Throw ForbiddenException if userId is not a participant in this conversation. */
  private _assertParticipant(
    conversation: ConversationWithParticipants,
    userId: string,
  ): void {
    const isParticipant =
      conversation.clientUserId === userId ||
      conversation.workerUserId === userId;
    if (!isParticipant) throw new ForbiddenException('Not a conversation participant');
  }

  private _toConversationDto(
    c: ConversationWithParticipants,
    callerId: string,
    callerRole: Role,
  ): ConversationResponseDto {
    // Build otherParticipant from the opposite side's user record
    const otherParticipant =
      callerRole === Role.CLIENT
        ? {
            userId: c.workerUserId,
            firstName: c.workerUser.workerProfile?.firstName ?? '',
            lastName: c.workerUser.workerProfile?.lastName ?? '',
            avatarUrl: c.workerUser.workerProfile?.avatarUrl ?? null,
            rating: c.workerUser.workerProfile?.rating ?? null,
          }
        : {
            userId: c.clientUserId,
            firstName: c.clientUser.clientProfile?.firstName ?? '',
            lastName: c.clientUser.clientProfile?.lastName ?? '',
            avatarUrl: c.clientUser.clientProfile?.avatarUrl ?? null,
            rating: null,
          };

    return {
      id: c.id,
      clientUserId: c.clientUserId,
      workerUserId: c.workerUserId,
      createdByUserId: c.createdByUserId,
      lastMessageAt: c.lastMessageAt?.toISOString() ?? null,
      lastMessagePreview: c.lastMessagePreview ?? null,
      createdAt: c.createdAt.toISOString(),
      updatedAt: c.updatedAt.toISOString(),
      otherParticipant,
    };
  }

  private _toMessageDto(m: {
    id: string;
    conversationId: string;
    senderUserId: string;
    senderRole: import('@prisma/client').Role;
    type: import('@prisma/client').MessageType;
    text: string | null;
    mediaUrl: string | null;
    thumbnailUrl: string | null;
    latitude: number | null;
    longitude: number | null;
    bookingId: string | null;
    replyToMessageId: string | null;
    editedAt: Date | null;
    deletedAt: Date | null;
    seenAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
  }): MessageResponseDto {
    return {
      id: m.id,
      conversationId: m.conversationId,
      senderUserId: m.senderUserId,
      senderRole: m.senderRole,
      type: m.type,
      text: m.text,
      mediaUrl: m.mediaUrl,
      thumbnailUrl: m.thumbnailUrl,
      latitude: m.latitude,
      longitude: m.longitude,
      bookingId: m.bookingId,
      replyToMessageId: m.replyToMessageId,
      editedAt: m.editedAt?.toISOString() ?? null,
      deletedAt: m.deletedAt?.toISOString() ?? null,
      seenAt: m.seenAt?.toISOString() ?? null,
      createdAt: m.createdAt.toISOString(),
      updatedAt: m.updatedAt.toISOString(),
    };
  }
}
