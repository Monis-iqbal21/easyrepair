import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Role } from '../../common/enums/role.enum';
import { ChatService } from './chat.service';
import { ChatGateway } from './chat.gateway';

/**
 * Roles permitted to work the Support Inbox.
 *
 * Extracted so granting a future dedicated SUPPORT role is a ONE-LINE change
 * here (and in the Role enum) rather than an edit to every route below.
 */
export const SUPPORT_ROLES: Role[] = [Role.ADMIN];

/**
 * Admin-facing Support Inbox API.
 *
 * API-only by design: the HandyGo web admin frontend lives outside this
 * repository and integrates against these endpoints. Nothing here renders UI.
 *
 * Every route is scoped to support threads — `_assertSupportConversation` in
 * ChatService rejects any conversation the support user is not part of, so
 * these endpoints can never be used to read ordinary booking chats.
 */
@Controller('admin/support')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(...SUPPORT_ROLES)
export class SupportController {
  constructor(
    private readonly chatService: ChatService,
    private readonly chatGateway: ChatGateway,
  ) {}

  /**
   * GET /admin/support/conversations?q=&cursor=&take=
   * Users who have a support thread, newest activity first, with the count of
   * messages still awaiting a reply.
   */
  @Get('conversations')
  listConversations(
    @Query('q') q?: string,
    @Query('cursor') cursor?: string,
    @Query('take') take?: string,
  ) {
    return this.chatService.listSupportConversations({
      query: q,
      cursor,
      take: take ? Math.min(parseInt(take, 10) || 50, 100) : 50,
    });
  }

  /** GET /admin/support/conversations/:id — who is asking. */
  @Get('conversations/:id')
  getRequesterInfo(@Param('id') conversationId: string) {
    return this.chatService.getSupportRequesterInfo(conversationId);
  }

  /** GET /admin/support/conversations/:id/messages */
  @Get('conversations/:id/messages')
  getMessages(
    @Param('id') conversationId: string,
    @Query('limit') limit?: string,
    @Query('before') before?: string,
  ) {
    return this.chatService.getSupportMessages(
      conversationId,
      limit ? Math.min(parseInt(limit, 10) || 50, 100) : 50,
      before,
    );
  }

  /**
   * POST /admin/support/conversations/:id/messages
   *
   * The reply is sent as the shared "HandyGo Support" identity, never as the
   * individual admin — so a user can never message a specific admin back.
   * Broadcast reuses the existing chat websocket path, so the user's app
   * receives it exactly like any other message.
   */
  @Post('conversations/:id/messages')
  @HttpCode(HttpStatus.CREATED)
  async sendReply(
    @CurrentUser() user: { id: string },
    @Param('id') conversationId: string,
    @Body() body: { text: string },
  ) {
    const message = await this.chatService.sendSupportReply(
      conversationId,
      body?.text,
    );
    await this.chatGateway.broadcastNewMessage(conversationId, message);
    return message;
  }

  /** POST /admin/support/conversations/:id/read */
  @Post('conversations/:id/read')
  @HttpCode(HttpStatus.OK)
  async markRead(@Param('id') conversationId: string) {
    const updated =
      await this.chatService.markSupportConversationRead(conversationId);
    return { success: true, markedSeen: updated };
  }
}
