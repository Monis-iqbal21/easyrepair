import { ChatGateway } from './chat.gateway';

describe('ChatGateway read receipts', () => {
  let repository: {
    findConversationById: jest.Mock;
    markMessageSeen: jest.Mock;
  };
  let gateway: ChatGateway;
  let emit: jest.Mock;

  beforeEach(() => {
    repository = {
      findConversationById: jest.fn().mockResolvedValue({
        clientUserId: 'client-1',
        workerUserId: 'worker-1',
      }),
      markMessageSeen: jest.fn().mockResolvedValue(true),
    };
    gateway = new ChatGateway(
      repository as any,
      {} as any,
      {} as any,
      {} as any,
    );
    emit = jest.fn();
    gateway.server = { to: jest.fn(() => ({ emit })) } as any;
  });

  it('emits message_seen only after the guarded database write succeeds', async () => {
    await gateway.handleMarkSeen(
      { data: { userId: 'worker-1', role: 'WORKER' } } as any,
      { conversationId: 'conversation-1', messageId: 'message-1' },
    );

    expect(repository.markMessageSeen).toHaveBeenCalledWith(
      'conversation-1',
      'message-1',
      'worker-1',
      expect.any(Date),
    );
    expect(emit).toHaveBeenCalledWith('message_seen', {
      messageId: 'message-1',
      seenAt: expect.any(String),
    });
  });

  it('does not claim a read when the database write is a no-op', async () => {
    repository.markMessageSeen.mockResolvedValue(false);

    await gateway.handleMarkSeen(
      { data: { userId: 'worker-1', role: 'WORKER' } } as any,
      { conversationId: 'conversation-1', messageId: 'message-1' },
    );

    expect(emit).not.toHaveBeenCalled();
  });
});
