import { BadRequestException } from '@nestjs/common';
import { Role } from '@prisma/client';
import { ChatController } from './chat.controller';

describe('ChatController voice messages', () => {
  const file = {
    buffer: Buffer.from('voice'),
    originalname: 'voice.m4a',
    mimetype: 'audio/m4a',
  } as Express.Multer.File;

  let chatService: { sendVoiceMessage: jest.Mock };
  let chatGateway: { broadcastNewMessage: jest.Mock };
  let controller: ChatController;

  beforeEach(() => {
    chatService = {
      sendVoiceMessage: jest.fn().mockResolvedValue({
        id: 'message-1',
        durationSeconds: 12.345,
      }),
    };
    chatGateway = { broadcastNewMessage: jest.fn() };
    controller = new ChatController(chatService as any, chatGateway as any);
  });

  it('parses an optional multipart duration and acknowledges only the saved response', async () => {
    const response = await controller.sendVoiceMessage(
      { id: 'client-1', role: Role.CLIENT },
      'conversation-1',
      file,
      '12.345',
    );

    expect(chatService.sendVoiceMessage).toHaveBeenCalledWith(
      'client-1',
      Role.CLIENT,
      'conversation-1',
      file.buffer,
      file.originalname,
      file.mimetype,
      12.345,
    );
    expect(response).toEqual(
      expect.objectContaining({ id: 'message-1', durationSeconds: 12.345 }),
    );
    expect(chatGateway.broadcastNewMessage).toHaveBeenCalledWith(
      'conversation-1',
      response,
    );
  });

  it('keeps old clients compatible when durationSeconds is absent', async () => {
    await controller.sendVoiceMessage(
      { id: 'client-1', role: Role.CLIENT },
      'conversation-1',
      file,
    );

    expect(chatService.sendVoiceMessage).toHaveBeenLastCalledWith(
      'client-1',
      Role.CLIENT,
      'conversation-1',
      file.buffer,
      file.originalname,
      file.mimetype,
      undefined,
    );
  });

  it.each(['0', '-1', '3601', 'NaN', 'Infinity', '12seconds'])(
    'rejects unsafe durationSeconds=%s',
    async (durationSeconds) => {
      await expect(
        controller.sendVoiceMessage(
          { id: 'client-1', role: Role.CLIENT },
          'conversation-1',
          file,
          durationSeconds,
        ),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(chatService.sendVoiceMessage).not.toHaveBeenCalled();
    },
  );
});
