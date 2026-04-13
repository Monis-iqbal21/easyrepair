import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
  UseInterceptors,
  UploadedFile,
  ParseFilePipe,
  MaxFileSizeValidator,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Role } from '@prisma/client';
import { ChatService } from './chat.service';
import { ChatGateway } from './chat.gateway';
import { CreateConversationDto } from './dto/create-conversation.dto';
import { SendMessageDto } from './dto/send-message.dto';
import { EditMessageDto } from './dto/edit-message.dto';
import { SendLocationMessageDto } from './dto/send-location-message.dto';
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
   * Both CLIENT and WORKER — send a text message.
   * After saving, broadcasts to the conversation room via ChatGateway.
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
    void this.chatGateway.broadcastNewMessage(id, message);
    return message;
  }

  /**
   * POST /chat/conversations/:id/messages/media
   * Both CLIENT and WORKER — multipart file upload (image or video).
   * Field name: "file". Max size: 50 MB.
   */
  @Post('conversations/:id/messages/media')
  @UseInterceptors(FileInterceptor('file'))
  @HttpCode(HttpStatus.CREATED)
  async sendMediaMessage(
    @CurrentUser() user: { id: string; role: Role },
    @Param('id') id: string,
    @UploadedFile(
      new ParseFilePipe({
        validators: [new MaxFileSizeValidator({ maxSize: 50 * 1024 * 1024 })],
      }),
    )
    file: Express.Multer.File,
  ) {
    const message = await this.chatService.sendMediaMessage(
      user.id,
      user.role,
      id,
      file.buffer,
      file.originalname,
      file.mimetype,
    );
    void this.chatGateway.broadcastNewMessage(id, message);
    return message;
  }

  /**
   * POST /chat/conversations/:id/messages/voice
   * Both CLIENT and WORKER — multipart audio upload.
   * Field name: "file". Max size: 10 MB.
   */
  @Post('conversations/:id/messages/voice')
  @UseInterceptors(FileInterceptor('file'))
  @HttpCode(HttpStatus.CREATED)
  async sendVoiceMessage(
    @CurrentUser() user: { id: string; role: Role },
    @Param('id') id: string,
    @UploadedFile(
      new ParseFilePipe({
        validators: [new MaxFileSizeValidator({ maxSize: 10 * 1024 * 1024 })],
      }),
    )
    file: Express.Multer.File,
  ) {
    const message = await this.chatService.sendVoiceMessage(
      user.id,
      user.role,
      id,
      file.buffer,
      file.originalname,
    );
    void this.chatGateway.broadcastNewMessage(id, message);
    return message;
  }

  /**
   * POST /chat/conversations/:id/messages/location
   * Both CLIENT and WORKER — send a location coordinate message.
   * Body: { latitude, longitude }
   */
  @Post('conversations/:id/messages/location')
  @HttpCode(HttpStatus.CREATED)
  async sendLocationMessage(
    @CurrentUser() user: { id: string; role: Role },
    @Param('id') id: string,
    @Body() dto: SendLocationMessageDto,
  ) {
    const message = await this.chatService.sendLocationMessage(
      user.id,
      user.role,
      id,
      dto.latitude,
      dto.longitude,
    );
    void this.chatGateway.broadcastNewMessage(id, message);
    return message;
  }

  /**
   * PUT /chat/conversations/:id/messages/:messageId
   * Edit own TEXT message within the 5-minute window.
   * Body: { text }
   * Broadcasts message_edited to the conversation room.
   */
  @Put('conversations/:id/messages/:messageId')
  async editMessage(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Param('messageId') messageId: string,
    @Body() dto: EditMessageDto,
  ) {
    const message = await this.chatService.editMessage(
      user.id,
      id,
      messageId,
      dto.text,
    );
    void this.chatGateway.broadcastMessageEdited(id, message);
    return message;
  }

  /**
   * DELETE /chat/conversations/:id/messages/:messageId
   * Soft-delete own message within the 5-minute window.
   * Any message type can be deleted; only TEXT messages can be edited.
   * Broadcasts message_deleted to the conversation room.
   */
  @Delete('conversations/:id/messages/:messageId')
  async deleteMessage(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Param('messageId') messageId: string,
  ) {
    const message = await this.chatService.deleteMessage(user.id, id, messageId);
    void this.chatGateway.broadcastMessageDeleted(id, {
      messageId: message.id,
      deletedAt: message.deletedAt!,
    });
    return message;
  }
}
