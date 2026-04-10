import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Server, Socket } from 'socket.io';

import { TokenPayload } from '../auth/entities/token-payload.entity';
import { ChatRepository } from './chat.repository';
import { MessageResponseDto } from './dto/message-response.dto';

// Augment Socket with our auth data so TypeScript knows what's on socket.data
type AuthSocket = Socket & { data: { userId: string; role: string } };

@WebSocketGateway({ namespace: '/chat', cors: { origin: '*' } })
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server!: Server;

  private readonly logger = new Logger(ChatGateway.name);

  constructor(
    private readonly chatRepository: ChatRepository,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  // ── Connection lifecycle ──────────────────────────────────────────────────

  async handleConnection(socket: Socket): Promise<void> {
    try {
      const token = socket.handshake.auth?.token as string | undefined;
      if (!token) {
        socket.disconnect();
        return;
      }

      const payload = this.jwtService.verify<TokenPayload>(token, {
        secret: this.configService.getOrThrow<string>('jwt.secret'),
      });

      socket.data.userId = payload.sub;
      socket.data.role = payload.role;

      // Join the caller's personal room so we can push conversation-list
      // updates to them directly (even when no conversation is open).
      await socket.join(`user:${payload.sub}`);

      this.logger.log(`[chat] connected userId=${payload.sub}`);
    } catch (err) {
      this.logger.warn(
        `[chat] auth failed: ${(err as Error)?.message}`,
      );
      socket.disconnect();
    }
  }

  handleDisconnect(socket: Socket): void {
    const userId = (socket.data as { userId?: string })?.userId ?? 'unknown';
    this.logger.log(`[chat] disconnected userId=${userId}`);
  }

  // ── Client → Server events ────────────────────────────────────────────────

  /**
   * Client opens a conversation screen.
   * Validates the caller is a participant, then joins the conversation room so
   * they receive new_message and message_seen events for it.
   */
  @SubscribeMessage('join_conversation')
  async handleJoinConversation(
    @ConnectedSocket() socket: AuthSocket,
    @MessageBody() payload: { conversationId: string },
  ): Promise<void> {
    try {
      const { userId } = socket.data;
      const conversation = await this.chatRepository.findConversationById(
        payload.conversationId,
      );
      if (!conversation) return;

      const isParticipant =
        conversation.clientUserId === userId ||
        conversation.workerUserId === userId;
      if (!isParticipant) return;

      await socket.join(`conversation:${payload.conversationId}`);
    } catch (err) {
      this.logger.warn(
        `[chat] join_conversation failed: ${(err as Error)?.message}`,
      );
    }
  }

  /**
   * Client leaves the conversation screen.
   */
  @SubscribeMessage('leave_conversation')
  async handleLeaveConversation(
    @ConnectedSocket() socket: AuthSocket,
    @MessageBody() payload: { conversationId: string },
  ): Promise<void> {
    await socket.leave(`conversation:${payload.conversationId}`);
  }

  /**
   * Client marks a message as seen.
   * The server validates:
   *   - caller is a participant
   *   - the message was NOT sent by the caller (can't mark own messages)
   *   - seenAt is not already set (idempotent)
   * Then emits message_seen to the conversation room.
   */
  @SubscribeMessage('mark_seen')
  async handleMarkSeen(
    @ConnectedSocket() socket: AuthSocket,
    @MessageBody() payload: { conversationId: string; messageId: string },
  ): Promise<void> {
    try {
      const { userId } = socket.data;

      const conversation = await this.chatRepository.findConversationById(
        payload.conversationId,
      );
      if (!conversation) return;

      const isParticipant =
        conversation.clientUserId === userId ||
        conversation.workerUserId === userId;
      if (!isParticipant) return;

      const seenAt = new Date();
      await this.chatRepository.markMessageSeen(
        payload.messageId,
        userId,
        seenAt,
      );

      this.server
        .to(`conversation:${payload.conversationId}`)
        .emit('message_seen', {
          messageId: payload.messageId,
          seenAt: seenAt.toISOString(),
        });
    } catch (err) {
      this.logger.warn(
        `[chat] mark_seen failed: ${(err as Error)?.message}`,
      );
    }
  }

  // ── Server → Clients (called by ChatController) ───────────────────────────

  /**
   * Broadcast a newly saved message to all sockets in the conversation room,
   * and push a lightweight conversation-list update to both participants'
   * personal rooms.
   *
   * Never throws — errors are caught and logged so they cannot affect the
   * HTTP sendMessage response.
   */
  async broadcastNewMessage(
    conversationId: string,
    message: MessageResponseDto,
  ): Promise<void> {
    try {
      // Push the full message to everyone currently viewing this conversation.
      this.server
        .to(`conversation:${conversationId}`)
        .emit('new_message', message);

      // Update both participants' conversation lists.
      const participants =
        await this.chatRepository.findConversationParticipants(conversationId);
      if (!participants) return;

      const preview =
        message.text != null
          ? message.text.length > 80
            ? message.text.slice(0, 80) + '…'
            : message.text
          : '';

      const updatePayload = {
        conversationId,
        lastMessagePreview: preview,
        lastMessageAt: message.createdAt,
      };

      this.server
        .to(`user:${participants.clientUserId}`)
        .emit('conversation_updated', updatePayload);
      this.server
        .to(`user:${participants.workerUserId}`)
        .emit('conversation_updated', updatePayload);
    } catch (err) {
      this.logger.warn(
        `[chat] broadcastNewMessage failed: ${(err as Error)?.message}`,
      );
    }
  }
}
