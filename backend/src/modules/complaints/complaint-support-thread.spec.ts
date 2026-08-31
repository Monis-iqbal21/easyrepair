import { ComplaintIssueType, MessageType, Role } from '@prisma/client';

import { ChatService } from '../chat/chat.service';
import { ComplaintsService } from './complaints.service';

/** Message row shape `_toMessageDto` needs, with test-friendly defaults. */
const messageRow = (over: Record<string, unknown> = {}) => ({
  id: 'msg-1',
  conversationId: 'support-convo-1',
  senderUserId: 'client-1',
  senderRole: Role.CLIENT,
  type: MessageType.SYSTEM,
  text: 'Report submitted',
  mediaUrl: null,
  storageKey: null,
  thumbnailUrl: null,
  mimeType: null,
  fileName: null,
  sizeBytes: null,
  durationSeconds: null,
  latitude: null,
  longitude: null,
  bookingId: 'booking-1',
  replyToMessageId: null,
  editedAt: null,
  deletedAt: null,
  seenAt: null,
  createdAt: new Date(),
  updatedAt: new Date(),
  ...over,
});

/**
 * ChatService wired against an in-memory conversation/message store that
 * enforces the same uniqueness Postgres does: ONE conversation per
 * (clientUserId, workerUserId) pair.
 */
function buildChatService() {
  const conversations: any[] = [];
  const messages: any[] = [];
  let convoSeq = 0;
  let msgSeq = 0;

  const chatRepository: any = {
    findConversation: jest.fn(async (clientUserId: string, workerUserId: string) =>
      conversations.find(
        (c) => c.clientUserId === clientUserId && c.workerUserId === workerUserId,
      ) ?? null,
    ),
    createConversation: jest.fn(async (data: any) => {
      const existing = conversations.find(
        (c) =>
          c.clientUserId === data.clientUserId &&
          c.workerUserId === data.workerUserId,
      );
      if (existing) return existing;
      const created = { id: `support-convo-${++convoSeq}`, ...data };
      conversations.push(created);
      return created;
    }),
    findMessageByConversationAndBooking: jest.fn(
      async (conversationId: string, bookingId: string) =>
        messages.find(
          (m) => m.conversationId === conversationId && m.bookingId === bookingId,
        ) ?? null,
    ),
    createSystemMessage: jest.fn(async (data: any) => {
      const created = messageRow({
        id: `msg-${++msgSeq}`,
        conversationId: data.conversationId,
        senderUserId: data.senderUserId,
        text: data.text,
        bookingId: data.bookingId ?? null,
      });
      messages.push(created);
      return created;
    }),
  };

  const supportUserService: any = {
    getSupportUserId: jest.fn().mockResolvedValue('support-user'),
    displayName: 'HandyGo Support',
  };

  const service = new ChatService(
    chatRepository,
    {} as any,
    { notify: jest.fn() } as any,
    {} as any,
    supportUserService,
  );

  return { service, chatRepository, conversations, messages };
}

describe('ChatService.appendComplaintSupportMessage', () => {
  it('creates the permanent support conversation when the client has none', async () => {
    const { service, conversations } = buildChatService();

    const message = await service.appendComplaintSupportMessage({
      userId: 'client-1',
      role: Role.CLIENT,
      bookingId: 'booking-1',
      text: 'Report submitted for booking #BOOKING1',
    });

    expect(conversations).toHaveLength(1);
    expect(conversations[0]).toMatchObject({
      clientUserId: 'client-1',
      workerUserId: 'support-user',
    });
    expect(message?.text).toBe('Report submitted for booking #BOOKING1');
  });

  it('reuses an existing support conversation instead of opening a new one', async () => {
    const { service, chatRepository, conversations } = buildChatService();
    await service.ensureSupportConversation('client-1', Role.CLIENT);
    chatRepository.createConversation.mockClear();

    await service.appendComplaintSupportMessage({
      userId: 'client-1',
      role: Role.CLIENT,
      bookingId: 'booking-1',
      text: 'Report submitted',
    });

    expect(chatRepository.createConversation).not.toHaveBeenCalled();
    expect(conversations).toHaveLength(1);
  });

  it('a second complaint adds a second message to the SAME conversation', async () => {
    const { service, conversations, messages } = buildChatService();

    await service.appendComplaintSupportMessage({
      userId: 'client-1',
      role: Role.CLIENT,
      bookingId: 'booking-1',
      text: 'Report for booking 1',
    });
    await service.appendComplaintSupportMessage({
      userId: 'client-1',
      role: Role.CLIENT,
      bookingId: 'booking-2',
      text: 'Report for booking 2',
    });

    expect(conversations).toHaveLength(1);
    expect(messages).toHaveLength(2);
    expect(new Set(messages.map((m) => m.conversationId)).size).toBe(1);
  });

  it('is idempotent: a retry re-finds the existing complaint message', async () => {
    const { service, chatRepository, messages } = buildChatService();

    const first = await service.appendComplaintSupportMessage({
      userId: 'client-1',
      role: Role.CLIENT,
      bookingId: 'booking-1',
      text: 'Report submitted',
    });
    chatRepository.createSystemMessage.mockClear();
    const second = await service.appendComplaintSupportMessage({
      userId: 'client-1',
      role: Role.CLIENT,
      bookingId: 'booking-1',
      text: 'Report submitted',
    });

    expect(chatRepository.createSystemMessage).not.toHaveBeenCalled();
    expect(messages).toHaveLength(1);
    expect(second?.id).toBe(first?.id);
  });

  it('does not open a support thread for an ADMIN', async () => {
    const { service, conversations } = buildChatService();

    const result = await service.appendComplaintSupportMessage({
      userId: 'admin-1',
      role: Role.ADMIN,
      bookingId: 'booking-1',
      text: 'Report submitted',
    });

    expect(result).toBeNull();
    expect(conversations).toHaveLength(0);
  });

  it('keeps the plain support thread usable: a normal reply still lands in it', async () => {
    const { service, chatRepository, conversations } = buildChatService();
    await service.appendComplaintSupportMessage({
      userId: 'client-1',
      role: Role.CLIENT,
      bookingId: 'booking-1',
      text: 'Report submitted',
    });

    // Existing behaviour must be untouched: the login-time ensure call still
    // returns the very same permanent thread the complaint was posted into.
    const ensured = await service.ensureSupportConversation(
      'client-1',
      Role.CLIENT,
    );

    expect(ensured?.id).toBe(conversations[0].id);
    expect(chatRepository.createConversation).toHaveBeenCalledTimes(1);
  });
});

describe('ComplaintsService support-thread announcement', () => {
  const booking = {
    id: 'booking-1',
    title: 'Ceiling fan repair',
    status: 'COMPLETED',
    workerProfileId: 'worker-profile-1',
    clientProfile: { userId: 'client-1' },
  };

  const created = {
    id: 'complaint-abcdef12',
    bookingId: 'booking-1',
    reporterUserId: 'client-1',
    issueTypes: [ComplaintIssueType.WORK_QUALITY, ComplaintIssueType.DAMAGE],
    otherText: 'Fan still wobbles',
    status: 'OPEN',
    events: [{ id: 'event-created' }],
  };

  const build = () => {
    const repository: any = {
      findBookingForComplaint: jest.fn().mockResolvedValue(booking),
      findByBookingId: jest.fn().mockResolvedValue(null),
      createBookingComplaint: jest.fn().mockResolvedValue(created),
    };
    const chat: any = {
      appendComplaintSupportMessage: jest.fn().mockResolvedValue({ id: 'm1' }),
    };
    const notifications: any = { notify: jest.fn().mockResolvedValue(undefined) };
    return {
      repository,
      chat,
      notifications,
      service: new ComplaintsService(repository, notifications, chat),
    };
  };

  it('posts exactly one complaint-linked support message with safe context', async () => {
    const { service, chat } = build();

    await service.createForBooking('client-1', 'booking-1', {
      issueTypes: [ComplaintIssueType.WORK_QUALITY, ComplaintIssueType.DAMAGE],
      otherText: 'Fan still wobbles',
    });

    expect(chat.appendComplaintSupportMessage).toHaveBeenCalledTimes(1);
    const call = chat.appendComplaintSupportMessage.mock.calls[0][0];
    expect(call).toMatchObject({
      userId: 'client-1',
      role: Role.CLIENT,
      bookingId: 'booking-1',
    });
    expect(call.text).toContain('Report submitted for booking #BOOKING-');
    expect(call.text).toContain('Ceiling fan repair');
    expect(call.text).toContain('Work quality, Damage');
    expect(call.text).toContain('Fan still wobbles');
    expect(call.text).toContain('Report ref: #COMPLAIN');
    // No internal metadata leaks into a client-visible message.
    expect(call.text).not.toContain('workerProfileId');
    expect(call.text).not.toContain('reporterUserId');
    expect(call.text).not.toMatch(/cnic/i);
  });

  it('still returns the complaint when the support message fails', async () => {
    const { service, chat } = build();
    chat.appendComplaintSupportMessage.mockRejectedValue(new Error('redis down'));

    // The complaint row is authoritative: a transient chat problem must never
    // fail the client's report.
    const result = await service.createForBooking('client-1', 'booking-1', {
        issueTypes: [ComplaintIssueType.WORK_QUALITY],
        otherText: 'Ustaad left the job half finished',
      });

    expect(result).toMatchObject({ id: 'complaint-abcdef12' });
  });

  it('does not post a second message when creation is retried', async () => {
    const { service, repository, chat } = build();
    repository.findByBookingId.mockResolvedValue({ id: 'complaint-abcdef12' });

    await expect(
      service.createForBooking('client-1', 'booking-1', {
        issueTypes: [ComplaintIssueType.WORK_QUALITY],
        otherText: 'Ustaad left the job half finished',
      }),
    ).rejects.toThrow();

    // A duplicate create is rejected before it can reach the support thread;
    // the idempotency inside appendComplaintSupportMessage is the second line
    // of defence, covered above.
    expect(chat.appendComplaintSupportMessage).not.toHaveBeenCalled();
  });
});
