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
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class ChatService {
  private readonly logger = new Logger(ChatService.name);

  constructor(
    private readonly chatRepository: ChatRepository,
    private readonly storageService: StorageService,
    private readonly notificationsService: NotificationsService,
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
      const unreadCount = await this.chatRepository.countUnread(existing.id, clientUserId);
      return this._toConversationDto(existing, clientUserId, Role.CLIENT, unreadCount);
    }

    // Create new conversation — client is the creator
    const created = await this.chatRepository.createConversation({
      clientUserId,
      workerUserId,
      createdByUserId: clientUserId,
    });
    return this._toConversationDto(created, clientUserId, Role.CLIENT, 0);
  }

  /**
   * WORKER action: create or retrieve the conversation with the client who
   * posted a given booking — lets a worker ask questions before placing a
   * bid. Idempotent (same client-worker pair reuses the one conversation,
   * consistent with the client-initiated path above).
   *
   * Eligibility: the booking must exist, and if it is already assigned to a
   * worker, only that worker may open the conversation — prevents an
   * unrelated worker from messaging a client about a job that isn't theirs.
   */
  async getOrCreateConversationForBooking(
    workerUserId: string,
    bookingId: string,
  ): Promise<ConversationResponseDto> {
    const booking =
      await this.chatRepository.findBookingForChatEligibility(bookingId);
    if (!booking) throw new NotFoundException('Booking not found');

    if (booking.workerProfile && booking.workerProfile.userId !== workerUserId) {
      throw new ForbiddenException(
        'This job is assigned to another worker.',
      );
    }

    const clientUserId = booking.clientProfile.userId;

    const existing = await this.chatRepository.findConversation(
      clientUserId,
      workerUserId,
    );
    if (existing) {
      const unreadCount = await this.chatRepository.countUnread(existing.id, workerUserId);
      return this._toConversationDto(existing, workerUserId, Role.WORKER, unreadCount);
    }

    const created = await this.chatRepository.createConversation({
      clientUserId,
      workerUserId,
      createdByUserId: workerUserId,
    });
    return this._toConversationDto(created, workerUserId, Role.WORKER, 0);
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
    return Promise.all(
      conversations.map(async (c) => {
        const unreadCount = await this.chatRepository.countUnread(c.id, userId);
        return this._toConversationDto(c, userId, role, unreadCount);
      }),
    );
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

    const receiverId =
      conversation.clientUserId === userId
        ? conversation.workerUserId
        : conversation.clientUserId;
    const receiverIsWorker = conversation.workerUserId === receiverId;
    const chatRoute = receiverIsWorker
      ? `/worker/chat/${conversationId}`
      : `/client/chat/${conversationId}`;
    const senderName = this._senderName(conversation, userId, role);
    void this.notificationsService.notify({
      userId: receiverId,
      eventKey: 'chat.message',
      title: senderName,
      body: text.length > 100 ? text.slice(0, 100) + '…' : text,
      entityType: 'conversation',
      entityId: conversationId,
      route: chatRoute,
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
    const folder = isVideo
      ? `uploads/chat/${conversationId}/videos`
      : `uploads/chat/${conversationId}/images`;
    const uploaded = await this.storageService.uploadFile(
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
      mediaUrl: uploaded.url,
      storageKey: uploaded.key,
      mimeType: uploaded.mimeType,
      fileName: uploaded.fileName,
      sizeBytes: uploaded.sizeBytes,
    });

    const receiverId =
      conversation.clientUserId === userId
        ? conversation.workerUserId
        : conversation.clientUserId;
    const receiverIsWorker = conversation.workerUserId === receiverId;
    void this.notificationsService.notify({
      userId: receiverId,
      eventKey: 'chat.message',
      title: this._senderName(conversation, userId, role),
      body: isVideo ? 'Sent a video' : 'Sent an image',
      entityType: 'conversation',
      entityId: conversationId,
      route: receiverIsWorker
        ? `/worker/chat/${conversationId}`
        : `/client/chat/${conversationId}`,
    });

    return this._toMessageDto(message);
  }

  async sendVoiceMessage(
    userId: string,
    role: Role,
    conversationId: string,
    buffer: Buffer,
    originalName: string,
    fileMimeType?: string,
  ): Promise<MessageResponseDto> {
    const conversation =
      await this.chatRepository.findConversationById(conversationId);
    if (!conversation) throw new NotFoundException('Conversation not found');
    this._assertParticipant(conversation, userId);

    const voiceMime = fileMimeType || (originalName.endsWith('.m4a') ? 'audio/x-m4a' : 'audio/mp4');
    const uploaded = await this.storageService.uploadFile(
      buffer,
      originalName,
      voiceMime,
      `uploads/chat/${conversationId}/voice`,
    );
    const message = await this.chatRepository.createVoiceMessage({
      conversationId,
      senderUserId: userId,
      senderRole: role,
      mediaUrl: uploaded.url,
      storageKey: uploaded.key,
      mimeType: uploaded.mimeType,
      fileName: uploaded.fileName,
      sizeBytes: uploaded.sizeBytes,
    });

    const receiverId =
      conversation.clientUserId === userId
        ? conversation.workerUserId
        : conversation.clientUserId;
    const receiverIsWorker = conversation.workerUserId === receiverId;
    void this.notificationsService.notify({
      userId: receiverId,
      eventKey: 'chat.message',
      title: this._senderName(conversation, userId, role),
      body: 'Sent a voice note',
      entityType: 'conversation',
      entityId: conversationId,
      route: receiverIsWorker
        ? `/worker/chat/${conversationId}`
        : `/client/chat/${conversationId}`,
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

    const receiverId =
      conversation.clientUserId === userId
        ? conversation.workerUserId
        : conversation.clientUserId;
    const receiverIsWorker = conversation.workerUserId === receiverId;
    void this.notificationsService.notify({
      userId: receiverId,
      eventKey: 'chat.message',
      title: this._senderName(conversation, userId, role),
      body: 'Shared a location',
      entityType: 'conversation',
      entityId: conversationId,
      route: receiverIsWorker
        ? `/worker/chat/${conversationId}`
        : `/client/chat/${conversationId}`,
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

  /** Return the display name of the sender for push notification titles. */
  private _senderName(
    conversation: ConversationWithParticipants,
    senderId: string,
    senderRole: Role,
  ): string {
    if (senderRole === Role.CLIENT) {
      const p = conversation.clientUser.clientProfile;
      return [p?.firstName, p?.lastName].filter(Boolean).join(' ') || 'Client';
    }
    const p = conversation.workerUser.workerProfile;
    return [p?.firstName, p?.lastName].filter(Boolean).join(' ') || 'Worker';
  }

  private _toConversationDto(
    c: ConversationWithParticipants,
    callerId: string,
    callerRole: Role,
    unreadCount = 0,
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
      unreadCount,
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
    storageKey?: string | null;
    thumbnailUrl: string | null;
    mimeType?: string | null;
    fileName?: string | null;
    sizeBytes?: number | null;
    durationSeconds?: number | null;
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
      storageKey: m.storageKey ?? null,
      thumbnailUrl: m.thumbnailUrl,
      mimeType: m.mimeType ?? null,
      fileName: m.fileName ?? null,
      sizeBytes: m.sizeBytes ?? null,
      durationSeconds: m.durationSeconds ?? null,
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
