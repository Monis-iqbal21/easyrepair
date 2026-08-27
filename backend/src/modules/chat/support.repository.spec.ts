import { ChatRepository } from './chat.repository';

const SUPPORT_USER_ID = 'support-user-id';

/**
 * Query-shape tests for the support inbox.
 *
 * The guarantees that keep ordinary client↔worker chats out of the admin
 * inbox — and keep the busiest thread on top — live in the Prisma arguments,
 * so that is what these assert.
 */
describe('ChatRepository — support inbox queries', () => {
  let prisma: any;
  let repository: ChatRepository;

  beforeEach(() => {
    prisma = {
      conversation: { findMany: jest.fn().mockResolvedValue([]) },
      message: { groupBy: jest.fn().mockResolvedValue([]) },
    };
    repository = new ChatRepository(prisma);
  });

  describe('findSupportConversations', () => {
    it('selects ONLY threads the support account participates in', async () => {
      await repository.findSupportConversations(SUPPORT_USER_ID);

      const { where } = prisma.conversation.findMany.mock.calls[0][0];
      // An ordinary booking chat has the support id in neither slot, so it
      // can never satisfy this clause.
      expect(where.AND[0]).toEqual({
        OR: [
          { clientUserId: SUPPORT_USER_ID },
          { workerUserId: SUPPORT_USER_ID },
        ],
      });
    });

    it('orders the most recently active thread first', async () => {
      await repository.findSupportConversations(SUPPORT_USER_ID);

      const { orderBy } = prisma.conversation.findMany.mock.calls[0][0];
      expect(orderBy).toEqual([
        // Threads that never got a message sort last, not first.
        { lastMessageAt: { sort: 'desc', nulls: 'last' } },
        { createdAt: 'desc' },
      ]);
    });

    it('keeps the support-only filter when a search term is applied', async () => {
      await repository.findSupportConversations(SUPPORT_USER_ID, {
        query: 'Sara',
      });

      const { where } = prisma.conversation.findMany.mock.calls[0][0];
      // Search narrows the support set; it must never widen it.
      expect(where.AND).toHaveLength(2);
      expect(where.AND[0].OR).toEqual([
        { clientUserId: SUPPORT_USER_ID },
        { workerUserId: SUPPORT_USER_ID },
      ]);
    });

    it('paginates by cursor, skipping the cursor row itself', async () => {
      await repository.findSupportConversations(SUPPORT_USER_ID, {
        take: 25,
        cursor: 'conv-5',
      });

      const args = prisma.conversation.findMany.mock.calls[0][0];
      expect(args.take).toBe(25);
      expect(args.cursor).toEqual({ id: 'conv-5' });
      expect(args.skip).toBe(1);
    });
  });

  describe('countUnreadByConversation', () => {
    it('aggregates every conversation in a single grouped query', async () => {
      prisma.message.groupBy.mockResolvedValue([
        { conversationId: 'conv-b', _count: { _all: 3 } },
      ]);

      const counts = await repository.countUnreadByConversation(
        ['conv-a', 'conv-b'],
        SUPPORT_USER_ID,
      );

      expect(prisma.message.groupBy).toHaveBeenCalledTimes(1);
      expect(prisma.message.groupBy).toHaveBeenCalledWith(
        expect.objectContaining({
          by: ['conversationId'],
          where: {
            conversationId: { in: ['conv-a', 'conv-b'] },
            // Support's own replies are not unread for support.
            senderUserId: { not: SUPPORT_USER_ID },
            seenAt: null,
            deletedAt: null,
          },
        }),
      );
      expect(counts.get('conv-b')).toBe(3);
      expect(counts.get('conv-a')).toBeUndefined();
    });

    it('short-circuits on an empty page rather than querying', async () => {
      const counts = await repository.countUnreadByConversation(
        [],
        SUPPORT_USER_ID,
      );

      expect(prisma.message.groupBy).not.toHaveBeenCalled();
      expect(counts.size).toBe(0);
    });
  });
});
