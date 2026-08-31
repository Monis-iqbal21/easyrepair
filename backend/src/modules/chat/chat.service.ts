import {
  Injectable,
  Inject,
  forwardRef,
  Logger,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { MessageType, Role } from '@prisma/client';
import {
  ChatRepository,
  ConversationWithParticipants,
} from './chat.repository';
import { ConversationResponseDto } from './dto/conversation-response.dto';
import { MessageResponseDto } from './dto/message-response.dto';
import { SupportConversationDto } from './dto/support-conversation-response.dto';
import { StorageService } from '../storage/storage.service';
import { NotificationsService } from '../notifications/notifications.service';
import { BookingsService } from '../bookings/bookings.service';
import { SupportUserService } from './support-user.service';

@Injectable()
export class ChatService {
  private readonly logger = new Logger(ChatService.name);

  constructor(
    private readonly chatRepository: ChatRepository,
    private readonly storageService: StorageService,
    private readonly notificationsService: NotificationsService,
    @Inject(forwardRef(() => BookingsService))
    private readonly bookingsService: BookingsService,
    private readonly supportUserService: SupportUserService,
  ) {}

  // ── Conversations ─────────────────────────────────────────────────────────

  /**
   * CLIENT action: create or retrieve the conversation with the given worker,
   * in the context of a specific booking the client owns.
   *
   * An existing conversation for this client/worker pair is always reopened
   * (preserving message history) regardless of the booking's current status
   * — a completed or cancelled booking must never lock out a legitimate,
   * already-established conversation. Creating a brand-new conversation,
   * however, requires the shared eligibility check (BookingsService.
   * assertClientCanChatWithWorker) so a client can't chat with an arbitrary
   * worker by guessing a profile id.
   */
  async getOrCreateConversation(
    clientUserId: string,
    bookingId: string,
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
      const unreadCount = await this.chatRepository.countUnread(
        existing.id,
        clientUserId,
      );
      return this._toConversationDto(
        existing,
        clientUserId,
        Role.CLIENT,
        unreadCount,
      );
    }

    // No existing conversation — enforce the full eligibility gate before
    // creating a brand new one.
    await this.bookingsService.assertClientCanChatWithWorker(
      clientUserId,
      bookingId,
      workerProfileId,
    );

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

    if (
      booking.workerProfile &&
      booking.workerProfile.userId !== workerUserId
    ) {
      throw new ForbiddenException('This job is assigned to another worker.');
    }

    const clientUserId = booking.clientProfile.userId;

    const existing = await this.chatRepository.findConversation(
      clientUserId,
      workerUserId,
    );
    if (existing) {
      const unreadCount = await this.chatRepository.countUnread(
        existing.id,
        workerUserId,
      );
      return this._toConversationDto(
        existing,
        workerUserId,
        Role.WORKER,
        unreadCount,
      );
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
    // Self-healing for accounts that predate the support feature: the Chat
    // tab is the one place every user reliably visits, and this is idempotent.
    await this.ensureSupportConversation(userId, role);

    const [conversations, supportUserId] = await Promise.all([
      this.chatRepository.findConversationsByUserId(userId, role),
      this.supportUserService.getSupportUserId().catch(() => null),
    ]);

    return Promise.all(
      conversations.map(async (c) => {
        const unreadCount = await this.chatRepository.countUnread(c.id, userId);
        const isSupport =
          supportUserId != null &&
          this._isSupportConversation(c, supportUserId);
        return this._toConversationDto(c, userId, role, unreadCount, isSupport);
      }),
    );
  }

  // ── HandyGo Support ───────────────────────────────────────────────────────

  /**
   * Idempotently ensure this user has their one HandyGo Support conversation.
   *
   * Safe to call on every login, registration, app resume and Chat-tab load:
   * uniqueness is owned by the DB (`@@unique([clientUserId, workerUserId])`),
   * and `createConversation` already resolves the P2002 race by returning the
   * winning row — so concurrent calls can only ever yield ONE conversation.
   *
   * Only CLIENT and WORKER get a support thread. ADMIN (which includes the
   * support system account itself) is excluded: support must never open a
   * conversation with itself, and admins reach users through the inbox.
   *
   * The support user takes the opposite participant slot, so each real user's
   * own id always lands in the slot `findConversationsByUserId` queries for
   * their role — a client in `clientUserId`, a worker in `workerUserId`.
   *
   * Never throws: a support-thread failure must not break login.
   */
  async ensureSupportConversation(
    userId: string,
    role: Role,
  ): Promise<ConversationWithParticipants | null> {
    try {
      if (role !== Role.CLIENT && role !== Role.WORKER) return null;

      const supportUserId = await this.supportUserService.getSupportUserId();
      // Belt and braces: the support account is ADMIN so the check above
      // already excludes it, but never let it pair with itself.
      if (userId === supportUserId) return null;

      const clientUserId = role === Role.CLIENT ? userId : supportUserId;
      const workerUserId = role === Role.CLIENT ? supportUserId : userId;

      const existing = await this.chatRepository.findConversation(
        clientUserId,
        workerUserId,
      );
      if (existing) return existing;

      return await this.chatRepository.createConversation({
        clientUserId,
        workerUserId,
        createdByUserId: userId,
      });
    } catch (err) {
      this.logger.warn(
        `[ensureSupportConversation] failed for userId=${userId}: ${(err as Error)?.message}`,
      );
      return null;
    }
  }

  /**
   * Append ONE complaint-linked message to a user's PERMANENT HandyGo Support
   * conversation, creating that conversation if the user has none yet.
   *
   * There is deliberately no per-complaint conversation: HandyGo's product rule
   * is one permanent support thread per user, so this reuses
   * [ensureSupportConversation] (idempotent, DB-owned uniqueness) and simply
   * posts into it. Writing the message bumps `lastMessageAt`, which is what
   * floats the thread to the top of the Admin Support Inbox and gives support
   * an unread count — after which admin and client keep talking in that same
   * thread through the existing reply endpoints.
   *
   * Idempotent: (conversation, bookingId) is a natural key — Message.bookingId
   * is written by this path only, and Complaint.bookingId is `@unique` — so a
   * retried complaint creation re-finds the existing message instead of posting
   * a second one.
   *
   * Returns null when the user cannot have a support thread (ADMIN), which is
   * not an error.
   */
  async appendComplaintSupportMessage(params: {
    userId: string;
    role: Role;
    bookingId: string;
    text: string;
  }): Promise<MessageResponseDto | null> {
    const conversation = await this.ensureSupportConversation(
      params.userId,
      params.role,
    );
    if (!conversation) return null;

    const existing =
      await this.chatRepository.findMessageByConversationAndBooking(
        conversation.id,
        params.bookingId,
      );
    if (existing) return this._toMessageDto(existing);

    const message = await this.chatRepository.createSystemMessage({
      conversationId: conversation.id,
      senderUserId: params.userId,
      text: params.text,
      bookingId: params.bookingId,
    });
    return this._toMessageDto(message);
  }

  /** True when the support system user is one of the two participants. */
  private _isSupportConversation(
    c: ConversationWithParticipants,
    supportUserId: string,
  ): boolean {
    return c.clientUserId === supportUserId || c.workerUserId === supportUserId;
  }

  // ── Admin support inbox ───────────────────────────────────────────────────
  //
  // Authorization for these lives in SupportController's SUPPORT_ROLES guard,
  // so granting a future SUPPORT role access is a one-line change there.

  /** Support threads for the inbox, newest activity first. */
  async listSupportConversations(options: {
    query?: string;
    take?: number;
    cursor?: string;
  }): Promise<SupportConversationDto[]> {
    const supportUserId = await this.supportUserService.getSupportUserId();
    const conversations = await this.chatRepository.findSupportConversations(
      supportUserId,
      options,
    );

    // ONE aggregate for the whole page rather than a COUNT per row — the
    // inbox loads up to 100 threads and must not fan out into 100 queries.
    const unreadByConversation =
      await this.chatRepository.countUnreadByConversation(
        conversations.map((c) => c.id),
        supportUserId,
      );

    return conversations.map((c) => {
      // The requester is whichever side ISN'T support.
      const requesterUserId =
        c.clientUserId === supportUserId ? c.workerUserId : c.clientUserId;
      const isWorkerRequester = c.clientUserId === supportUserId;
      const requesterUser = isWorkerRequester ? c.workerUser : c.clientUser;
      const profile = isWorkerRequester
        ? c.workerUser.workerProfile
        : c.clientUser.clientProfile;

      return {
        id: c.id,
        requesterUserId,
        // Lets the inbox show "Client" vs "Ustaad" at a glance.
        requesterType: isWorkerRequester ? Role.WORKER : Role.CLIENT,
        requesterName:
          [profile?.firstName, profile?.lastName].filter(Boolean).join(' ') ||
          'User',
        // Already loaded by CONVERSATION_INCLUDE, and the same User.phone the
        // per-thread requester-info endpoint already shows an admin — so the
        // inbox can dial a caller back without a second round trip.
        requesterPhone: requesterUser.phone,
        requesterAvatarUrl: profile?.avatarUrl ?? null,
        lastMessageAt: c.lastMessageAt?.toISOString() ?? null,
        lastMessagePreview: c.lastMessagePreview ?? null,
        // Unread from the SUPPORT side — i.e. what the admin still owes.
        unreadCount: unreadByConversation.get(c.id) ?? 0,
        createdAt: c.createdAt.toISOString(),
      };
    });
  }

  /** Messages in a support thread, for the inbox. */
  async getSupportMessages(
    conversationId: string,
    limit = 50,
    before?: string,
  ): Promise<MessageResponseDto[]> {
    await this._assertSupportConversation(conversationId);
    const messages = await this.chatRepository.findMessages(
      conversationId,
      limit,
      before,
    );
    return messages.map((m) => this._toMessageDto(m));
  }

  /**
   * Admin reply. Sent AS the shared support identity, not as the individual
   * admin, so the user always sees one consistent "HandyGo Support" and can
   * never message a specific admin back.
   */
  async sendSupportReply(
    conversationId: string,
    text: string,
  ): Promise<MessageResponseDto> {
    if (!text?.trim()) throw new BadRequestException('Message cannot be empty');
    const conversation = await this._assertSupportConversation(conversationId);

    const supportUserId = await this.supportUserService.getSupportUserId();
    const body = text.trim();
    const message = await this.chatRepository.createMessage({
      conversationId,
      senderUserId: supportUserId,
      senderRole: Role.ADMIN,
      text: body,
    });

    // Same notification path an ordinary chat message takes (see sendMessage)
    // — a support reply must reach the user's phone exactly like any other
    // incoming message, and must not invent a parallel delivery mechanism.
    const receiverId =
      conversation.clientUserId === supportUserId
        ? conversation.workerUserId
        : conversation.clientUserId;
    const receiverIsWorker = conversation.workerUserId === receiverId;
    void this.notificationsService.notify({
      userId: receiverId,
      eventKey: 'chat.message',
      // The shared support identity, never the individual admin.
      title: this.supportUserService.displayName,
      body: body.length > 100 ? body.slice(0, 100) + '…' : body,
      entityType: 'conversation',
      entityId: conversationId,
      route: receiverIsWorker
        ? `/worker/chat/${conversationId}`
        : `/client/chat/${conversationId}`,
    });

    return this._toMessageDto(message);
  }

  /** Marks the requester's messages as seen once an admin opens the thread. */
  async markSupportConversationRead(conversationId: string): Promise<{
    count: number;
    messageIds: string[];
    seenAt: Date;
  }> {
    await this._assertSupportConversation(conversationId);
    const supportUserId = await this.supportUserService.getSupportUserId();
    return this.chatRepository.markAllSeenFrom(conversationId, supportUserId);
  }

  /** Minimal, deliberately non-sensitive requester detail for the inbox. */
  async getSupportRequesterInfo(conversationId: string) {
    const conversation = await this._assertSupportConversation(conversationId);
    const supportUserId = await this.supportUserService.getSupportUserId();
    const requesterUserId =
      conversation.clientUserId === supportUserId
        ? conversation.workerUserId
        : conversation.clientUserId;

    const user = await this.chatRepository.findUserSummary(requesterUserId);
    if (!user) throw new NotFoundException('User not found');

    const profile = user.clientProfile ?? user.workerProfile;
    return {
      userId: user.id,
      role: user.role,
      name:
        [profile?.firstName, profile?.lastName].filter(Boolean).join(' ') ||
        'User',
      avatarUrl: profile?.avatarUrl ?? null,
      phone: user.phone,
      memberSince: user.createdAt.toISOString(),
    };
  }

  /** The conversation must genuinely be a support thread. */
  private async _assertSupportConversation(
    conversationId: string,
  ): Promise<ConversationWithParticipants> {
    const conversation =
      await this.chatRepository.findConversationById(conversationId);
    if (!conversation) throw new NotFoundException('Conversation not found');

    const supportUserId = await this.supportUserService.getSupportUserId();
    if (!this._isSupportConversation(conversation, supportUserId)) {
      // Stops the admin endpoints being used to read ordinary booking chats.
      throw new ForbiddenException('Not a support conversation');
    }
    return conversation;
  }

  /** The support user's id — used by the gateway for room routing. */
  async getSupportUserId(): Promise<string> {
    return this.supportUserService.getSupportUserId();
  }

  /** Whether a conversation id is a support thread (for socket fan-out). */
  async isSupportConversationId(conversationId: string): Promise<boolean> {
    const conversation =
      await this.chatRepository.findConversationById(conversationId);
    if (!conversation) return false;
    const supportUserId = await this.supportUserService.getSupportUserId();
    return this._isSupportConversation(conversation, supportUserId);
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
    durationSeconds?: number,
  ): Promise<MessageResponseDto> {
    const conversation =
      await this.chatRepository.findConversationById(conversationId);
    if (!conversation) throw new NotFoundException('Conversation not found');
    this._assertParticipant(conversation, userId);

    const voiceMime =
      fileMimeType ||
      (originalName.endsWith('.m4a') ? 'audio/x-m4a' : 'audio/mp4');
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
      durationSeconds,
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
    if (!isParticipant)
      throw new ForbiddenException('Not a conversation participant');
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
    isSupport = false,
  ): ConversationResponseDto {
    // The support account has neither a clientProfile nor a workerProfile
    // (deliberately — that keeps it out of every matching query), so the
    // normal profile lookup below would yield empty strings. Name it here
    // instead; the app renders the bundled HandyGo logo for the avatar.
    const otherParticipant = isSupport
      ? {
          userId: c.clientUserId === callerId ? c.workerUserId : c.clientUserId,
          firstName: this.supportUserService.displayName,
          lastName: '',
          avatarUrl: null,
          rating: null,
          // Never invent a support phone number — the app hides the call
          // button for the Support thread when this is null.
          phone: null,
        }
      : // Build otherParticipant from the opposite side's user record
        callerRole === Role.CLIENT
        ? {
            userId: c.workerUserId,
            firstName: c.workerUser.workerProfile?.firstName ?? '',
            lastName: c.workerUser.workerProfile?.lastName ?? '',
            avatarUrl: c.workerUser.workerProfile?.avatarUrl ?? null,
            rating: c.workerUser.workerProfile?.rating ?? null,
            phone: c.workerUser.phone,
          }
        : {
            userId: c.clientUserId,
            firstName: c.clientUser.clientProfile?.firstName ?? '',
            lastName: c.clientUser.clientProfile?.lastName ?? '',
            avatarUrl: c.clientUser.clientProfile?.avatarUrl ?? null,
            rating: null,
            phone: c.clientUser.phone,
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
      isSupport,
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
