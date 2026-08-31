import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { Role } from '@prisma/client';
import { ChatService } from './chat.service';

const SUPPORT_USER_ID = 'support-user-id';

function makeConversation(overrides: Partial<any> = {}) {
  return {
    id: 'conv-1',
    clientUserId: 'client-user-1',
    workerUserId: SUPPORT_USER_ID,
    createdByUserId: 'client-user-1',
    lastMessageAt: null,
    lastMessagePreview: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    workerUser: { phone: '+920000000000', workerProfile: null },
    clientUser: {
      phone: '+923001234567',
      clientProfile: { firstName: 'Sara', lastName: 'Ahmed', avatarUrl: null },
    },
    ...overrides,
  };
}

describe('ChatService — HandyGo Support', () => {
  let chatRepository: any;
  let supportUserService: any;
  let notificationsService: any;
  let service: ChatService;

  beforeEach(() => {
    chatRepository = {
      findConversation: jest.fn().mockResolvedValue(null),
      createConversation: jest.fn().mockResolvedValue(makeConversation()),
      findConversationById: jest.fn().mockResolvedValue(makeConversation()),
      findConversationsByUserId: jest.fn().mockResolvedValue([]),
      findSupportConversations: jest.fn().mockResolvedValue([]),
      countUnread: jest.fn().mockResolvedValue(0),
      countUnreadByConversation: jest.fn().mockResolvedValue(new Map()),
      createMessage: jest.fn().mockResolvedValue({
        id: 'msg-1',
        conversationId: 'conv-1',
        senderUserId: SUPPORT_USER_ID,
        senderRole: Role.ADMIN,
        type: 'TEXT',
        text: 'Assalam o alaikum',
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
      markAllSeenFrom: jest.fn().mockResolvedValue({
        count: 3,
        messageIds: ['msg-1', 'msg-2', 'msg-3'],
        seenAt: new Date('2026-08-31T10:00:00.000Z'),
      }),
      findUserSummary: jest.fn().mockResolvedValue({
        id: 'client-user-1',
        role: Role.CLIENT,
        phone: '+923001234567',
        createdAt: new Date(),
        clientProfile: {
          firstName: 'Sara',
          lastName: 'Ahmed',
          avatarUrl: null,
        },
        workerProfile: null,
      }),
    };
    supportUserService = {
      getSupportUserId: jest.fn().mockResolvedValue(SUPPORT_USER_ID),
      displayName: 'HandyGo Support',
    };
    notificationsService = { notify: jest.fn().mockResolvedValue(undefined) };
    service = new ChatService(
      chatRepository,
      {} as any,
      notificationsService,
      {} as any,
      supportUserService,
    );
  });

  // ── Create-or-return ─────────────────────────────────────────────────────
  describe('ensureSupportConversation', () => {
    it('creates the conversation when none exists, with the user in their own slot', async () => {
      await service.ensureSupportConversation('client-user-1', Role.CLIENT);

      expect(chatRepository.createConversation).toHaveBeenCalledWith({
        clientUserId: 'client-user-1',
        workerUserId: SUPPORT_USER_ID,
        createdByUserId: 'client-user-1',
      });
    });

    it('puts a WORKER in the workerUserId slot so their own list query finds it', async () => {
      await service.ensureSupportConversation('worker-user-1', Role.WORKER);

      expect(chatRepository.createConversation).toHaveBeenCalledWith({
        clientUserId: SUPPORT_USER_ID,
        workerUserId: 'worker-user-1',
        createdByUserId: 'worker-user-1',
      });
    });

    it('returns the existing conversation instead of creating a duplicate', async () => {
      chatRepository.findConversation.mockResolvedValue(makeConversation());

      const result = await service.ensureSupportConversation(
        'client-user-1',
        Role.CLIENT,
      );

      expect(result?.id).toBe('conv-1');
      expect(chatRepository.createConversation).not.toHaveBeenCalled();
    });

    it('is idempotent across repeated logins', async () => {
      // First call creates; subsequent calls find the existing row.
      let created: any = null;
      chatRepository.findConversation.mockImplementation(() =>
        Promise.resolve(created),
      );
      chatRepository.createConversation.mockImplementation(() => {
        created = makeConversation();
        return Promise.resolve(created);
      });

      for (let i = 0; i < 5; i++) {
        await service.ensureSupportConversation('client-user-1', Role.CLIENT);
      }

      expect(chatRepository.createConversation).toHaveBeenCalledTimes(1);
    });

    // Concurrency: both racers miss the lookup, both attempt the insert, and
    // the DB unique constraint means only one row can ever exist — the loser
    // gets the winner's row back from createConversation's P2002 retry.
    it('yields exactly ONE conversation under concurrent calls', async () => {
      const winner = makeConversation();
      chatRepository.findConversation.mockResolvedValue(null);
      chatRepository.createConversation.mockResolvedValue(winner);

      const results = await Promise.all([
        service.ensureSupportConversation('client-user-1', Role.CLIENT),
        service.ensureSupportConversation('client-user-1', Role.CLIENT),
        service.ensureSupportConversation('client-user-1', Role.CLIENT),
      ]);

      // Every racer ends up referring to the same conversation.
      expect(new Set(results.map((r) => r?.id))).toEqual(new Set(['conv-1']));
    });

    // ── Restricted to real users ───────────────────────────────────────────
    it('never creates a support conversation for an ADMIN', async () => {
      const result = await service.ensureSupportConversation(
        'admin-user-1',
        Role.ADMIN,
      );

      expect(result).toBeNull();
      expect(chatRepository.createConversation).not.toHaveBeenCalled();
    });

    it('never lets the support account open a thread with itself', async () => {
      const result = await service.ensureSupportConversation(
        SUPPORT_USER_ID,
        Role.CLIENT,
      );

      expect(result).toBeNull();
      expect(chatRepository.createConversation).not.toHaveBeenCalled();
    });

    it('never throws — a support failure must not break login', async () => {
      chatRepository.findConversation.mockRejectedValue(new Error('db down'));

      await expect(
        service.ensureSupportConversation('client-user-1', Role.CLIENT),
      ).resolves.toBeNull();
    });
  });

  // ── User-facing list ─────────────────────────────────────────────────────
  describe('getMyConversations', () => {
    it('flags the support thread and names it HandyGo Support', async () => {
      chatRepository.findConversation.mockResolvedValue(makeConversation());
      chatRepository.findConversationsByUserId.mockResolvedValue([
        makeConversation(),
      ]);

      const [conv] = await service.getMyConversations(
        'client-user-1',
        Role.CLIENT,
      );

      expect(conv.isSupport).toBe(true);
      // The support account has no worker profile, so without the override
      // this would render as an empty name.
      expect(conv.otherParticipant.firstName).toBe('HandyGo Support');
    });

    it('leaves ordinary booking chats untouched', async () => {
      const ordinary = makeConversation({
        id: 'conv-2',
        workerUserId: 'worker-user-9',
        workerUser: {
          workerProfile: {
            firstName: 'Ali',
            lastName: 'Khan',
            avatarUrl: null,
            rating: 4.5,
          },
        },
      });
      chatRepository.findConversation.mockResolvedValue(makeConversation());
      chatRepository.findConversationsByUserId.mockResolvedValue([ordinary]);

      const [conv] = await service.getMyConversations(
        'client-user-1',
        Role.CLIENT,
      );

      expect(conv.isSupport).toBe(false);
      expect(conv.otherParticipant.firstName).toBe('Ali');
    });
  });

  // ── Admin inbox ──────────────────────────────────────────────────────────
  describe('admin inbox', () => {
    it('labels the requester as CLIENT or WORKER', async () => {
      chatRepository.findSupportConversations.mockResolvedValue([
        // support sits in workerUserId ⇒ the requester is the client
        makeConversation(),
        // support sits in clientUserId ⇒ the requester is the worker
        makeConversation({
          id: 'conv-2',
          clientUserId: SUPPORT_USER_ID,
          workerUserId: 'worker-user-1',
          clientUser: { phone: '+920000000000', clientProfile: null },
          workerUser: {
            phone: '+923009876543',
            workerProfile: {
              firstName: 'Ali',
              lastName: 'Khan',
              avatarUrl: null,
              rating: 4.5,
            },
          },
        }),
      ]);

      const rows = await service.listSupportConversations({});

      expect(rows[0].requesterType).toBe(Role.CLIENT);
      expect(rows[0].requesterName).toBe('Sara Ahmed');
      expect(rows[0].requesterUserId).toBe('client-user-1');

      expect(rows[1].requesterType).toBe(Role.WORKER);
      expect(rows[1].requesterName).toBe('Ali Khan');
      expect(rows[1].requesterUserId).toBe('worker-user-1');
    });

    it('reports unread from the SUPPORT side — what the admin still owes', async () => {
      chatRepository.findSupportConversations.mockResolvedValue([
        makeConversation(),
      ]);
      chatRepository.countUnreadByConversation.mockResolvedValue(
        new Map([['conv-1', 4]]),
      );

      const [row] = await service.listSupportConversations({});

      expect(row.unreadCount).toBe(4);
      expect(chatRepository.countUnreadByConversation).toHaveBeenCalledWith(
        ['conv-1'],
        SUPPORT_USER_ID,
      );
    });

    it('counts unread for the whole page in ONE query, not one per row', async () => {
      chatRepository.findSupportConversations.mockResolvedValue([
        makeConversation({ id: 'conv-a' }),
        makeConversation({ id: 'conv-b' }),
        makeConversation({ id: 'conv-c' }),
      ]);
      chatRepository.countUnreadByConversation.mockResolvedValue(
        new Map([['conv-b', 2]]),
      );

      const rows = await service.listSupportConversations({});

      // One aggregate for all three, and no per-row COUNT fallback.
      expect(chatRepository.countUnreadByConversation).toHaveBeenCalledTimes(1);
      expect(chatRepository.countUnread).not.toHaveBeenCalled();
      // Threads absent from the aggregate mean "nothing unread", not undefined.
      expect(rows.map((r) => r.unreadCount)).toEqual([0, 2, 0]);
    });

    it('carries the requester phone so an admin can call back', async () => {
      chatRepository.findSupportConversations.mockResolvedValue([
        makeConversation(),
      ]);

      const [row] = await service.listSupportConversations({});

      expect(row.requesterPhone).toBe('+923001234567');
    });

    it('asks only for threads the support account is part of, newest first', async () => {
      await service.listSupportConversations({ take: 25, cursor: 'conv-5' });

      // The support-only filter and the ordering are the repository's job —
      // assert the service delegates with the support id, unmodified options.
      expect(chatRepository.findSupportConversations).toHaveBeenCalledWith(
        SUPPORT_USER_ID,
        { take: 25, cursor: 'conv-5' },
      );
    });

    it('replies AS the shared support identity, never as the individual admin', async () => {
      await service.sendSupportReply('conv-1', 'Assalam o alaikum');

      expect(chatRepository.createMessage).toHaveBeenCalledWith({
        conversationId: 'conv-1',
        senderUserId: SUPPORT_USER_ID,
        senderRole: Role.ADMIN,
        text: 'Assalam o alaikum',
      });
    });

    it('notifies the user through the ordinary chat notification path', async () => {
      await service.sendSupportReply('conv-1', 'Assalam o alaikum');

      // Same eventKey and route shape sendMessage uses — no parallel
      // delivery mechanism for support.
      expect(notificationsService.notify).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 'client-user-1',
          eventKey: 'chat.message',
          title: 'HandyGo Support',
          body: 'Assalam o alaikum',
          entityType: 'conversation',
          entityId: 'conv-1',
          route: '/client/chat/conv-1',
        }),
      );
    });

    it('routes the reply to the worker app when the requester is an Ustaad', async () => {
      chatRepository.findConversationById.mockResolvedValue(
        makeConversation({
          clientUserId: SUPPORT_USER_ID,
          workerUserId: 'worker-user-1',
        }),
      );

      await service.sendSupportReply('conv-1', 'Ji farmaiye');

      expect(notificationsService.notify).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 'worker-user-1',
          route: '/worker/chat/conv-1',
        }),
      );
    });

    it('replies into the existing thread — never opens a second one', async () => {
      await service.sendSupportReply('conv-1', 'Assalam o alaikum');

      expect(chatRepository.createConversation).not.toHaveBeenCalled();
      expect(chatRepository.createMessage).toHaveBeenCalledWith(
        expect.objectContaining({ conversationId: 'conv-1' }),
      );
    });

    it('marks the requester messages seen when a thread is opened', async () => {
      const count = await service.markSupportConversationRead('conv-1');

      expect(count).toEqual(
        expect.objectContaining({
          count: 3,
          messageIds: ['msg-1', 'msg-2', 'msg-3'],
        }),
      );
      expect(chatRepository.markAllSeenFrom).toHaveBeenCalledWith(
        'conv-1',
        SUPPORT_USER_ID,
      );
    });

    it('exposes only minimal requester info', async () => {
      const info = await service.getSupportRequesterInfo('conv-1');

      expect(info).toEqual({
        userId: 'client-user-1',
        role: Role.CLIENT,
        name: 'Sara Ahmed',
        avatarUrl: null,
        phone: '+923001234567',
        memberSince: expect.any(String),
      });
      // Nothing beyond the above — no email, address or booking history.
      expect(Object.keys(info).sort()).toEqual([
        'avatarUrl',
        'memberSince',
        'name',
        'phone',
        'role',
        'userId',
      ]);
    });

    // ── The admin endpoints must not become a backdoor into ordinary chats ─
    it.each([
      ['read messages', (s: ChatService) => s.getSupportMessages('conv-9')],
      ['reply', (s: ChatService) => s.sendSupportReply('conv-9', 'hi')],
      [
        'mark read',
        (s: ChatService) => s.markSupportConversationRead('conv-9'),
      ],
      [
        'requester info',
        (s: ChatService) => s.getSupportRequesterInfo('conv-9'),
      ],
    ])(
      'refuses to %s on an ordinary booking conversation',
      async (_label, call) => {
        // Neither participant is the support account.
        chatRepository.findConversationById.mockResolvedValue(
          makeConversation({
            id: 'conv-9',
            clientUserId: 'client-user-1',
            workerUserId: 'worker-user-1',
          }),
        );

        await expect(call(service)).rejects.toThrow(ForbiddenException);
      },
    );

    it.each([
      ['read messages', (s: ChatService) => s.getSupportMessages('nope')],
      ['reply', (s: ChatService) => s.sendSupportReply('nope', 'hi')],
      ['mark read', (s: ChatService) => s.markSupportConversationRead('nope')],
      ['requester info', (s: ChatService) => s.getSupportRequesterInfo('nope')],
    ])(
      '404s rather than 403s when asked to %s on a missing conversation',
      async (_label, call) => {
        chatRepository.findConversationById.mockResolvedValue(null);

        await expect(call(service)).rejects.toThrow(NotFoundException);
      },
    );
  });
});
