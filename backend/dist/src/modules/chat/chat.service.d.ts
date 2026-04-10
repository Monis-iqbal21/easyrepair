import { Role } from '@prisma/client';
import { ChatRepository } from './chat.repository';
import { ConversationResponseDto } from './dto/conversation-response.dto';
import { MessageResponseDto } from './dto/message-response.dto';
import { StorageService } from '../storage/storage.service';
export declare class ChatService {
    private readonly chatRepository;
    private readonly storageService;
    private readonly logger;
    constructor(chatRepository: ChatRepository, storageService: StorageService);
    getOrCreateConversation(clientUserId: string, workerProfileId: string): Promise<ConversationResponseDto>;
    ensureConversationForBooking(clientUserId: string, workerUserId: string): Promise<void>;
    getMyConversations(userId: string, role: Role): Promise<ConversationResponseDto[]>;
    getMessages(userId: string, conversationId: string, limit?: number, before?: string): Promise<MessageResponseDto[]>;
    sendMessage(userId: string, role: Role, conversationId: string, text: string): Promise<MessageResponseDto>;
    sendMediaMessage(userId: string, role: Role, conversationId: string, buffer: Buffer, originalName: string, mimeType: string): Promise<MessageResponseDto>;
    sendVoiceMessage(userId: string, role: Role, conversationId: string, buffer: Buffer, originalName: string): Promise<MessageResponseDto>;
    sendLocationMessage(userId: string, role: Role, conversationId: string, latitude: number, longitude: number): Promise<MessageResponseDto>;
    editMessage(userId: string, conversationId: string, messageId: string, text: string): Promise<MessageResponseDto>;
    deleteMessage(userId: string, conversationId: string, messageId: string): Promise<MessageResponseDto>;
    private _assertParticipant;
    private _toConversationDto;
    private _toMessageDto;
}
