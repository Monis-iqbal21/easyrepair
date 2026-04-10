import { OnGatewayConnection, OnGatewayDisconnect } from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Server, Socket } from 'socket.io';
import { ChatRepository } from './chat.repository';
import { MessageResponseDto } from './dto/message-response.dto';
type AuthSocket = Socket & {
    data: {
        userId: string;
        role: string;
    };
};
export declare class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
    private readonly chatRepository;
    private readonly jwtService;
    private readonly configService;
    server: Server;
    private readonly logger;
    constructor(chatRepository: ChatRepository, jwtService: JwtService, configService: ConfigService);
    handleConnection(socket: Socket): Promise<void>;
    handleDisconnect(socket: Socket): void;
    handleJoinConversation(socket: AuthSocket, payload: {
        conversationId: string;
    }): Promise<void>;
    handleLeaveConversation(socket: AuthSocket, payload: {
        conversationId: string;
    }): Promise<void>;
    handleMarkSeen(socket: AuthSocket, payload: {
        conversationId: string;
        messageId: string;
    }): Promise<void>;
    broadcastNewMessage(conversationId: string, message: MessageResponseDto): Promise<void>;
}
export {};
