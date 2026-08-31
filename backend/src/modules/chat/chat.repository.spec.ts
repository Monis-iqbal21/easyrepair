import { MessageType, Role } from '@prisma/client';
import { ChatRepository } from './chat.repository';

describe('ChatRepository message persistence', () => {
  it('stores voice duration in the existing Message.durationSeconds field', async () => {
    const saved = {
      id: 'message-1',
      type: MessageType.VOICE,
      durationSeconds: 8.75,
    };
    const prisma = {
      message: { create: jest.fn().mockReturnValue('create-message') },
      conversation: {
        update: jest.fn().mockReturnValue('update-conversation'),
      },
      $transaction: jest.fn().mockResolvedValue([saved, {}]),
    };
    const repository = new ChatRepository(prisma as any);

    await expect(
      repository.createVoiceMessage({
        conversationId: 'conversation-1',
        senderUserId: 'client-1',
        senderRole: Role.CLIENT,
        mediaUrl: 'https://cdn.invalid/voice.m4a',
        durationSeconds: 8.75,
      }),
    ).resolves.toBe(saved);

    expect(prisma.message.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        type: MessageType.VOICE,
        durationSeconds: 8.75,
      }),
    });
  });
});
