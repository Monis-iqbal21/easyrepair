import { Injectable } from '@nestjs/common';
import { MessageType, Prisma, Role } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

// ---------------------------------------------------------------------------
// Includes
// ---------------------------------------------------------------------------

const CONVERSATION_INCLUDE = {
  clientUser: {
    select: {
      id: true,
      // Reused by the chat "call" button — mirrors the same User.phone the
      // booking-detail Call Worker / Call Client actions already expose via
      // WorkerSummaryDto.phone / WorkerJobResponseDto.clientPhone.
      phone: true,
      clientProfile: {
        select: { firstName: true, lastName: true, avatarUrl: true },
      },
    },
  },
  workerUser: {
    select: {
      id: true,
      phone: true,
      workerProfile: {
        select: {
          firstName: true,
          lastName: true,
          avatarUrl: true,
          rating: true,
        },
      },
    },
  },
} satisfies Prisma.ConversationInclude;

export type ConversationWithParticipants = Prisma.ConversationGetPayload<{
  include: typeof CONVERSATION_INCLUDE;
}>;

// ---------------------------------------------------------------------------

@Injectable()
export class ChatRepository {
  constructor(private readonly prisma: PrismaService) {}

  // ── Conversations ─────────────────────────────────────────────────────────

  /** Find existing conversation by unique client-worker pair. */
  async findConversation(
    clientUserId: string,
    workerUserId: string,
  ): Promise<ConversationWithParticipants | null> {
    return this.prisma.conversation.findUnique({
      where: { clientUserId_workerUserId: { clientUserId, workerUserId } },
      include: CONVERSATION_INCLUDE,
    });
  }

  /** Find a conversation by id. */
  async findConversationById(
    id: string,
  ): Promise<ConversationWithParticipants | null> {
    return this.prisma.conversation.findUnique({
      where: { id },
      include: CONVERSATION_INCLUDE,
    });
  }

  /**
   * Idempotent create — Conversation has a DB-level @@unique([clientUserId,
   * workerUserId]) constraint, so if a concurrent request already created
   * this exact pair's conversation between the caller's own findConversation
   * check and this call, Postgres rejects our insert (P2002). We catch that
   * specific race and return the winning row instead of surfacing a raw 500
   * — this is what makes get-or-create safe under concurrent duplicate taps.
   */
  async createConversation(data: {
    clientUserId: string;
    workerUserId: string;
    createdByUserId: string;
  }): Promise<ConversationWithParticipants> {
    try {
      return await this.prisma.conversation.create({
        data: {
          clientUserId: data.clientUserId,
          workerUserId: data.workerUserId,
          createdByUserId: data.createdByUserId,
        },
        include: CONVERSATION_INCLUDE,
      });
    } catch (err) {
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2002'
      ) {
        const existing = await this.findConversation(
          data.clientUserId,
          data.workerUserId,
        );
        if (existing) return existing;
      }
      throw err;
    }
  }

  /**
   * Return all conversations where this user is a participant.
   * Sorted by most recently active first.
   */
  async findConversationsByUserId(
    userId: string,
    role: Role,
  ): Promise<ConversationWithParticipants[]> {
    const where: Prisma.ConversationWhereInput =
      role === Role.CLIENT
        ? { clientUserId: userId }
        : { workerUserId: userId };

    return this.prisma.conversation.findMany({
      where,
      include: CONVERSATION_INCLUDE,
      orderBy: [
        { lastMessageAt: { sort: 'desc', nulls: 'last' } },
        { createdAt: 'desc' },
      ],
    });
  }

  /**
   * All support conversations, for the admin inbox.
   *
   * A conversation is a support thread iff the support system user is one of
   * its two participants — derived, so no schema discriminator is needed.
   * [query] matches the counterpart's name (never the message bodies).
   */
  async findSupportConversations(
    supportUserId: string,
    options: { query?: string; take?: number; cursor?: string } = {},
  ): Promise<ConversationWithParticipants[]> {
    const nameFilter = options.query?.trim();
    const matchesName: Prisma.ConversationWhereInput | undefined = nameFilter
      ? {
          OR: [
            {
              clientUser: {
                clientProfile: {
                  OR: [
                    {
                      firstName: { contains: nameFilter, mode: 'insensitive' },
                    },
                    { lastName: { contains: nameFilter, mode: 'insensitive' } },
                  ],
                },
              },
            },
            {
              workerUser: {
                workerProfile: {
                  OR: [
                    {
                      firstName: { contains: nameFilter, mode: 'insensitive' },
                    },
                    { lastName: { contains: nameFilter, mode: 'insensitive' } },
                  ],
                },
              },
            },
            { clientUser: { phone: { contains: nameFilter } } },
            { workerUser: { phone: { contains: nameFilter } } },
          ],
        }
      : undefined;

    return this.prisma.conversation.findMany({
      where: {
        AND: [
          {
            OR: [
              { clientUserId: supportUserId },
              { workerUserId: supportUserId },
            ],
          },
          ...(matchesName ? [matchesName] : []),
        ],
      },
      include: CONVERSATION_INCLUDE,
      orderBy: [
        { lastMessageAt: { sort: 'desc', nulls: 'last' } },
        { createdAt: 'desc' },
      ],
      take: options.take ?? 50,
      ...(options.cursor ? { cursor: { id: options.cursor }, skip: 1 } : {}),
    });
  }

  /** Marks every inbound message in a conversation as seen, in one write. */
  async markAllSeenFrom(
    conversationId: string,
    readerUserId: string,
  ): Promise<number> {
    const res = await this.prisma.message.updateMany({
      where: {
        conversationId,
        senderUserId: { not: readerUserId },
        seenAt: null,
        deletedAt: null,
      },
      data: { seenAt: new Date() },
    });
    return res.count;
  }

  /** Minimal, deliberately non-sensitive detail about a support requester. */
  async findUserSummary(userId: string) {
    return this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        role: true,
        phone: true,
        createdAt: true,
        clientProfile: {
          select: { firstName: true, lastName: true, avatarUrl: true },
        },
        workerProfile: {
          select: { firstName: true, lastName: true, avatarUrl: true },
        },
      },
    });
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  /**
   * Create a text message and update conversation lastMessage* in one
   * transaction so the list view is always consistent.
   */
  async createMessage(data: {
    conversationId: string;
    senderUserId: string;
    senderRole: Role;
    text: string;
  }) {
    const preview =
      data.text.length > 80 ? data.text.slice(0, 80) + '…' : data.text;
    const now = new Date();

    const [message] = await this.prisma.$transaction([
      this.prisma.message.create({
        data: {
          conversationId: data.conversationId,
          senderUserId: data.senderUserId,
          senderRole: data.senderRole,
          type: MessageType.TEXT,
          text: data.text,
        },
      }),
      this.prisma.conversation.update({
        where: { id: data.conversationId },
        data: { lastMessageAt: now, lastMessagePreview: preview },
      }),
    ]);

    return message;
  }

  /**
   * Create a SYSTEM-type message and update conversation lastMessage* in one
   * transaction.  Used for automated messages (e.g. booking assignment event).
   * Does not return the message — callers don't need it.
   */
  async createSystemMessage(data: {
    conversationId: string;
    senderUserId: string;
    text: string;
  }): Promise<void> {
    const preview =
      data.text.length > 80 ? data.text.slice(0, 80) + '…' : data.text;
    const now = new Date();

    await this.prisma.$transaction([
      this.prisma.message.create({
        data: {
          conversationId: data.conversationId,
          senderUserId: data.senderUserId,
          senderRole: Role.CLIENT,
          type: MessageType.SYSTEM,
          text: data.text,
        },
      }),
      this.prisma.conversation.update({
        where: { id: data.conversationId },
        data: { lastMessageAt: now, lastMessagePreview: preview },
      }),
    ]);
  }

  /**
   * Return messages in a conversation, newest first (client reverses for display).
   * Default page size: 50.
   */
  async findMessages(conversationId: string, limit = 50, before?: string) {
    return this.prisma.message.findMany({
      where: {
        conversationId,
        deletedAt: null,
        ...(before ? { createdAt: { lt: new Date(before) } } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  /**
   * Unread counts for MANY conversations in ONE query.
   *
   * The support inbox lists up to 100 threads at a time; counting per row
   * would issue one COUNT per conversation (N+1). `groupBy` collapses that
   * into a single aggregate. Conversations with nothing unread are simply
   * absent from the result — callers default them to 0.
   */
  async countUnreadByConversation(
    conversationIds: string[],
    readerUserId: string,
  ): Promise<Map<string, number>> {
    if (conversationIds.length === 0) return new Map();

    const rows = await this.prisma.message.groupBy({
      by: ['conversationId'],
      where: {
        conversationId: { in: conversationIds },
        senderUserId: { not: readerUserId },
        seenAt: null,
        deletedAt: null,
      },
      _count: { _all: true },
    });

    return new Map(rows.map((r) => [r.conversationId, r._count._all]));
  }

  /**
   * Count messages in a conversation that were sent by others and not yet seen
   * by the given user.  Used to populate the unreadCount field in conversation lists.
   */
  async countUnread(
    conversationId: string,
    currentUserId: string,
  ): Promise<number> {
    return this.prisma.message.count({
      where: {
        conversationId,
        senderUserId: { not: currentUserId },
        seenAt: null,
        deletedAt: null,
      },
    });
  }

  // ── Seen status ───────────────────────────────────────────────────────────

  /**
   * Mark a message as seen.
   * Uses updateMany with three guards so it is safe to call multiple times:
   *   - message must match the given id
   *   - message must NOT have been sent by the viewer (can't see own messages)
   *   - seenAt must still be null (idempotent)
   */
  async markMessageSeen(
    messageId: string,
    seenByUserId: string,
    seenAt: Date,
  ): Promise<void> {
    await this.prisma.message.updateMany({
      where: {
        id: messageId,
        senderUserId: { not: seenByUserId },
        seenAt: null,
      },
      data: { seenAt },
    });
  }

  /**
   * Lightweight fetch of only the two participant IDs for a conversation.
   * Used by ChatGateway to fan out conversation_updated events.
   */
  async findConversationParticipants(
    conversationId: string,
  ): Promise<{ clientUserId: string; workerUserId: string } | null> {
    return this.prisma.conversation.findUnique({
      where: { id: conversationId },
      select: { clientUserId: true, workerUserId: true },
    });
  }

  // ── Media / voice / location messages ────────────────────────────────────

  async createMediaMessage(data: {
    conversationId: string;
    senderUserId: string;
    senderRole: Role;
    type: MessageType; // IMAGE or VIDEO
    mediaUrl: string;
    storageKey?: string;
    mimeType?: string;
    fileName?: string;
    sizeBytes?: number;
  }) {
    const preview = data.type === MessageType.IMAGE ? '📷 Image' : '🎥 Video';
    const now = new Date();
    const [message] = await this.prisma.$transaction([
      this.prisma.message.create({
        data: {
          conversationId: data.conversationId,
          senderUserId: data.senderUserId,
          senderRole: data.senderRole,
          type: data.type,
          mediaUrl: data.mediaUrl,
          storageKey: data.storageKey ?? null,
          mimeType: data.mimeType ?? null,
          fileName: data.fileName ?? null,
          sizeBytes: data.sizeBytes ?? null,
        },
      }),
      this.prisma.conversation.update({
        where: { id: data.conversationId },
        data: { lastMessageAt: now, lastMessagePreview: preview },
      }),
    ]);
    return message;
  }

  async createVoiceMessage(data: {
    conversationId: string;
    senderUserId: string;
    senderRole: Role;
    mediaUrl: string;
    storageKey?: string;
    mimeType?: string;
    fileName?: string;
    sizeBytes?: number;
  }) {
    const preview = '🎙️ Voice message';
    const now = new Date();
    const [message] = await this.prisma.$transaction([
      this.prisma.message.create({
        data: {
          conversationId: data.conversationId,
          senderUserId: data.senderUserId,
          senderRole: data.senderRole,
          type: MessageType.VOICE,
          mediaUrl: data.mediaUrl,
          storageKey: data.storageKey ?? null,
          mimeType: data.mimeType ?? null,
          fileName: data.fileName ?? null,
          sizeBytes: data.sizeBytes ?? null,
        },
      }),
      this.prisma.conversation.update({
        where: { id: data.conversationId },
        data: { lastMessageAt: now, lastMessagePreview: preview },
      }),
    ]);
    return message;
  }

  async createLocationMessage(data: {
    conversationId: string;
    senderUserId: string;
    senderRole: Role;
    latitude: number;
    longitude: number;
  }) {
    const preview = '📍 Location';
    const now = new Date();
    const [message] = await this.prisma.$transaction([
      this.prisma.message.create({
        data: {
          conversationId: data.conversationId,
          senderUserId: data.senderUserId,
          senderRole: data.senderRole,
          type: MessageType.LOCATION,
          latitude: data.latitude,
          longitude: data.longitude,
        },
      }),
      this.prisma.conversation.update({
        where: { id: data.conversationId },
        data: { lastMessageAt: now, lastMessagePreview: preview },
      }),
    ]);
    return message;
  }

  // ── Edit / delete ─────────────────────────────────────────────────────────

  async findMessageById(messageId: string) {
    return this.prisma.message.findUnique({ where: { id: messageId } });
  }

  async updateMessageText(messageId: string, text: string, editedAt: Date) {
    return this.prisma.message.update({
      where: { id: messageId },
      data: { text, editedAt },
    });
  }

  async softDeleteMessage(messageId: string, deletedAt: Date) {
    return this.prisma.message.update({
      where: { id: messageId },
      data: { deletedAt },
    });
  }

  // ── Worker lookup ─────────────────────────────────────────────────────────

  /**
   * Resolve a WorkerProfile.id → the worker's User record.
   * Used when the client provides a workerProfileId to start a conversation.
   */
  async findWorkerUserByProfileId(
    workerProfileId: string,
  ): Promise<{ userId: string; firstName: string; lastName: string } | null> {
    const profile = await this.prisma.workerProfile.findUnique({
      where: { id: workerProfileId },
      select: { userId: true, firstName: true, lastName: true },
    });
    return profile ?? null;
  }

  /**
   * Resolve a ClientProfile.userId → the client's profile info.
   * Used to build the otherParticipant DTO for worker-side responses.
   */
  async findClientProfileByUserId(userId: string) {
    return this.prisma.clientProfile.findUnique({
      where: { userId },
      select: { firstName: true, lastName: true, avatarUrl: true },
    });
  }

  /**
   * Lean lookup used to authorize a worker-initiated (pre-bid) chat request:
   * resolves the booking's client userId and, if already assigned, the
   * assigned worker's userId so the caller can be checked for eligibility.
   */
  async findBookingForChatEligibility(bookingId: string): Promise<{
    id: string;
    clientProfile: { userId: string };
    workerProfile: { userId: string } | null;
  } | null> {
    return this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: {
        id: true,
        clientProfile: { select: { userId: true } },
        workerProfile: { select: { userId: true } },
      },
    });
  }
}
