import { Role } from '@prisma/client';
import { ChatService } from './chat.service';
import { ChatGateway } from './chat.gateway';
import { CreateConversationDto } from './dto/create-conversation.dto';
import { SendMessageDto } from './dto/send-message.dto';
export declare class ChatController {
    private readonly chatService;
    private readonly chatGateway;
    constructor(chatService: ChatService, chatGateway: ChatGateway);
    getOrCreateConversation(user: {
        id: string;
        role: string;
    }, dto: CreateConversationDto): Promise<import("./dto/conversation-response.dto").ConversationResponseDto>;
    getMyConversations(user: {
        id: string;
        role: Role;
    }): Promise<import("./dto/conversation-response.dto").ConversationResponseDto[]>;
    getMessages(user: {
        id: string;
    }, id: string, limit?: string, before?: string): Promise<import("./dto/message-response.dto").MessageResponseDto[]>;
    sendMessage(user: {
        id: string;
        role: Role;
    }, id: string, dto: SendMessageDto): Promise<import("./dto/message-response.dto").MessageResponseDto>;
}
