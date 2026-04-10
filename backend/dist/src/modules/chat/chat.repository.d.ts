import { MessageType, Prisma, Role } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
declare const CONVERSATION_INCLUDE: {
    clientUser: {
        select: {
            id: true;
            clientProfile: {
                select: {
                    firstName: true;
                    lastName: true;
                    avatarUrl: true;
                };
            };
        };
    };
    workerUser: {
        select: {
            id: true;
            workerProfile: {
                select: {
                    firstName: true;
                    lastName: true;
                    avatarUrl: true;
                    rating: true;
                };
            };
        };
    };
};
export type ConversationWithParticipants = Prisma.ConversationGetPayload<{
    include: typeof CONVERSATION_INCLUDE;
}>;
export declare class ChatRepository {
    private readonly prisma;
    constructor(prisma: PrismaService);
    findConversation(clientUserId: string, workerUserId: string): Promise<ConversationWithParticipants | null>;
    findConversationById(id: string): Promise<ConversationWithParticipants | null>;
    createConversation(data: {
        clientUserId: string;
        workerUserId: string;
        createdByUserId: string;
    }): Promise<ConversationWithParticipants>;
    findConversationsByUserId(userId: string, role: Role): Promise<ConversationWithParticipants[]>;
    createMessage(data: {
        conversationId: string;
        senderUserId: string;
        senderRole: Role;
        text: string;
    }): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        type: import(".prisma/client").$Enums.MessageType;
        bookingId: string | null;
        latitude: number | null;
        longitude: number | null;
        conversationId: string;
        senderUserId: string;
        senderRole: import(".prisma/client").$Enums.Role;
        text: string | null;
        mediaUrl: string | null;
        thumbnailUrl: string | null;
        replyToMessageId: string | null;
        editedAt: Date | null;
        deletedAt: Date | null;
        seenAt: Date | null;
    }>;
    createSystemMessage(data: {
        conversationId: string;
        senderUserId: string;
        text: string;
    }): Promise<void>;
    findMessages(conversationId: string, limit?: number, before?: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        type: import(".prisma/client").$Enums.MessageType;
        bookingId: string | null;
        latitude: number | null;
        longitude: number | null;
        conversationId: string;
        senderUserId: string;
        senderRole: import(".prisma/client").$Enums.Role;
        text: string | null;
        mediaUrl: string | null;
        thumbnailUrl: string | null;
        replyToMessageId: string | null;
        editedAt: Date | null;
        deletedAt: Date | null;
        seenAt: Date | null;
    }[]>;
    markMessageSeen(messageId: string, seenByUserId: string, seenAt: Date): Promise<void>;
    findConversationParticipants(conversationId: string): Promise<{
        clientUserId: string;
        workerUserId: string;
    } | null>;
    createMediaMessage(data: {
        conversationId: string;
        senderUserId: string;
        senderRole: Role;
        type: MessageType;
        mediaUrl: string;
    }): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        type: import(".prisma/client").$Enums.MessageType;
        bookingId: string | null;
        latitude: number | null;
        longitude: number | null;
        conversationId: string;
        senderUserId: string;
        senderRole: import(".prisma/client").$Enums.Role;
        text: string | null;
        mediaUrl: string | null;
        thumbnailUrl: string | null;
        replyToMessageId: string | null;
        editedAt: Date | null;
        deletedAt: Date | null;
        seenAt: Date | null;
    }>;
    createVoiceMessage(data: {
        conversationId: string;
        senderUserId: string;
        senderRole: Role;
        mediaUrl: string;
    }): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        type: import(".prisma/client").$Enums.MessageType;
        bookingId: string | null;
        latitude: number | null;
        longitude: number | null;
        conversationId: string;
        senderUserId: string;
        senderRole: import(".prisma/client").$Enums.Role;
        text: string | null;
        mediaUrl: string | null;
        thumbnailUrl: string | null;
        replyToMessageId: string | null;
        editedAt: Date | null;
        deletedAt: Date | null;
        seenAt: Date | null;
    }>;
    createLocationMessage(data: {
        conversationId: string;
        senderUserId: string;
        senderRole: Role;
        latitude: number;
        longitude: number;
    }): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        type: import(".prisma/client").$Enums.MessageType;
        bookingId: string | null;
        latitude: number | null;
        longitude: number | null;
        conversationId: string;
        senderUserId: string;
        senderRole: import(".prisma/client").$Enums.Role;
        text: string | null;
        mediaUrl: string | null;
        thumbnailUrl: string | null;
        replyToMessageId: string | null;
        editedAt: Date | null;
        deletedAt: Date | null;
        seenAt: Date | null;
    }>;
    findMessageById(messageId: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        type: import(".prisma/client").$Enums.MessageType;
        bookingId: string | null;
        latitude: number | null;
        longitude: number | null;
        conversationId: string;
        senderUserId: string;
        senderRole: import(".prisma/client").$Enums.Role;
        text: string | null;
        mediaUrl: string | null;
        thumbnailUrl: string | null;
        replyToMessageId: string | null;
        editedAt: Date | null;
        deletedAt: Date | null;
        seenAt: Date | null;
    } | null>;
    updateMessageText(messageId: string, text: string, editedAt: Date): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        type: import(".prisma/client").$Enums.MessageType;
        bookingId: string | null;
        latitude: number | null;
        longitude: number | null;
        conversationId: string;
        senderUserId: string;
        senderRole: import(".prisma/client").$Enums.Role;
        text: string | null;
        mediaUrl: string | null;
        thumbnailUrl: string | null;
        replyToMessageId: string | null;
        editedAt: Date | null;
        deletedAt: Date | null;
        seenAt: Date | null;
    }>;
    softDeleteMessage(messageId: string, deletedAt: Date): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        type: import(".prisma/client").$Enums.MessageType;
        bookingId: string | null;
        latitude: number | null;
        longitude: number | null;
        conversationId: string;
        senderUserId: string;
        senderRole: import(".prisma/client").$Enums.Role;
        text: string | null;
        mediaUrl: string | null;
        thumbnailUrl: string | null;
        replyToMessageId: string | null;
        editedAt: Date | null;
        deletedAt: Date | null;
        seenAt: Date | null;
    }>;
    findWorkerUserByProfileId(workerProfileId: string): Promise<{
        userId: string;
        firstName: string;
        lastName: string;
    } | null>;
    findClientProfileByUserId(userId: string): Promise<{
        firstName: string;
        lastName: string;
        avatarUrl: string | null;
    } | null>;
}
export {};
