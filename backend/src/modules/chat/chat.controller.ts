import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { Role } from '@prisma/client';
import { ChatService } from './chat.service';
import { ChatGateway } from './chat.gateway';
import { CreateConversationDto } from './dto/create-conversation.dto';
import { SendMessageDto } from './dto/send-message.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Role as AppRole } from '../../common/enums/role.enum';

@Controller('chat')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ChatController {
  constructor(
    private readonly chatService: ChatService,
    private readonly chatGateway: ChatGateway,
  ) {}

  /**
   * POST /chat/conversations
   * CLIENT only — create a new conversation with a worker, or return the
   * existing one if it already exists (idempotent).
   * Body: { workerProfileId }
   */
  @Post('conversations')
  @Roles(AppRole.CLIENT)
  @HttpCode(HttpStatus.OK)
  getOrCreateConversation(
    @CurrentUser() user: { id: string; role: string },
    @Body() dto: CreateConversationDto,
  ) {
    return this.chatService.getOrCreateConversation(user.id, dto.workerProfileId);
  }

  /**
   * GET /chat/conversations
   * Both CLIENT and WORKER — returns their own conversation list.
   * No @Roles restriction: RolesGuard passes through when no roles are set.
   */
  @Get('conversations')
  getMyConversations(@CurrentUser() user: { id: string; role: Role }) {
    return this.chatService.getMyConversations(user.id, user.role);
  }

  /**
   * GET /chat/conversations/:id/messages?limit=50&before=<ISO>
   * Both CLIENT and WORKER — caller must be a participant.
   * `before` enables cursor pagination: return messages older than that timestamp.
   */
  @Get('conversations/:id/messages')
  getMessages(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Query('limit') limit?: string,
    @Query('before') before?: string,
  ) {
    const parsedLimit = limit !== undefined ? parseInt(limit, 10) : 50;
    const safeLimit = Number.isFinite(parsedLimit)
      ? Math.min(Math.max(parsedLimit, 1), 100)
      : 50;
    return this.chatService.getMessages(user.id, id, safeLimit, before);
  }

  /**
   * POST /chat/conversations/:id/messages
   * Both CLIENT and WORKER — caller must be a participant.
   * After saving, broadcasts the message to the conversation room via the
   * ChatGateway (fire-and-forget — never blocks the HTTP response).
   */
  @Post('conversations/:id/messages')
  @HttpCode(HttpStatus.CREATED)
  async sendMessage(
    @CurrentUser() user: { id: string; role: Role },
    @Param('id') id: string,
    @Body() dto: SendMessageDto,
  ) {
    const message = await this.chatService.sendMessage(
      user.id,
      user.role,
      id,
      dto.text,
    );
    // Fire-and-forget: errors are swallowed inside broadcastNewMessage
    void this.chatGateway.broadcastNewMessage(id, message);
    return message;
  }
}
