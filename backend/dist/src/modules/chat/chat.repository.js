"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChatRepository = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const prisma_service_1 = require("../../prisma/prisma.service");
const CONVERSATION_INCLUDE = {
    clientUser: {
        select: {
            id: true,
            clientProfile: { select: { firstName: true, lastName: true, avatarUrl: true } },
        },
    },
    workerUser: {
        select: {
            id: true,
            workerProfile: { select: { firstName: true, lastName: true, avatarUrl: true, rating: true } },
        },
    },
};
let ChatRepository = class ChatRepository {
    constructor(prisma) {
        this.prisma = prisma;
    }
    async findConversation(clientUserId, workerUserId) {
        return this.prisma.conversation.findUnique({
            where: { clientUserId_workerUserId: { clientUserId, workerUserId } },
            include: CONVERSATION_INCLUDE,
        });
    }
    async findConversationById(id) {
        return this.prisma.conversation.findUnique({
            where: { id },
            include: CONVERSATION_INCLUDE,
        });
    }
    async createConversation(data) {
        return this.prisma.conversation.create({
            data: {
                clientUserId: data.clientUserId,
                workerUserId: data.workerUserId,
                createdByUserId: data.createdByUserId,
            },
            include: CONVERSATION_INCLUDE,
        });
    }
    async findConversationsByUserId(userId, role) {
        const where = role === client_1.Role.CLIENT
            ? { clientUserId: userId }
            : { workerUserId: userId };
        return this.prisma.conversation.findMany({
            where,
            include: CONVERSATION_INCLUDE,
            orderBy: [
                { lastMessageAt: { sort: 'desc', nulls: 'last' } },
                { createdAt: 'desc' },
            ],
        });
    }
    async createMessage(data) {
        const preview = data.text.length > 80 ? data.text.slice(0, 80) + '…' : data.text;
        const now = new Date();
        const [message] = await this.prisma.$transaction([
            this.prisma.message.create({
                data: {
                    conversationId: data.conversationId,
                    senderUserId: data.senderUserId,
                    senderRole: data.senderRole,
                    type: client_1.MessageType.TEXT,
                    text: data.text,
                },
            }),
            this.prisma.conversation.update({
                where: { id: data.conversationId },
                data: { lastMessageAt: now, lastMessagePreview: preview },
            }),
        ]);
        return message;
    }
    async createSystemMessage(data) {
        const preview = data.text.length > 80 ? data.text.slice(0, 80) + '…' : data.text;
        const now = new Date();
        await this.prisma.$transaction([
            this.prisma.message.create({
                data: {
                    conversationId: data.conversationId,
                    senderUserId: data.senderUserId,
                    senderRole: client_1.Role.CLIENT,
                    type: client_1.MessageType.SYSTEM,
                    text: data.text,
                },
            }),
            this.prisma.conversation.update({
                where: { id: data.conversationId },
                data: { lastMessageAt: now, lastMessagePreview: preview },
            }),
        ]);
    }
    async findMessages(conversationId, limit = 50, before) {
        return this.prisma.message.findMany({
            where: {
                conversationId,
                deletedAt: null,
                ...(before ? { createdAt: { lt: new Date(before) } } : {}),
            },
            orderBy: { createdAt: 'desc' },
            take: limit,
        });
    }
    async markMessageSeen(messageId, seenByUserId, seenAt) {
        await this.prisma.message.updateMany({
            where: {
                id: messageId,
                senderUserId: { not: seenByUserId },
                seenAt: null,
            },
            data: { seenAt },
        });
    }
    async findConversationParticipants(conversationId) {
        return this.prisma.conversation.findUnique({
            where: { id: conversationId },
            select: { clientUserId: true, workerUserId: true },
        });
    }
    async createMediaMessage(data) {
        const preview = data.type === client_1.MessageType.IMAGE ? '📷 Image' : '🎥 Video';
        const now = new Date();
        const [message] = await this.prisma.$transaction([
            this.prisma.message.create({
                data: {
                    conversationId: data.conversationId,
                    senderUserId: data.senderUserId,
                    senderRole: data.senderRole,
                    type: data.type,
                    mediaUrl: data.mediaUrl,
                },
            }),
            this.prisma.conversation.update({
                where: { id: data.conversationId },
                data: { lastMessageAt: now, lastMessagePreview: preview },
            }),
        ]);
        return message;
    }
    async createVoiceMessage(data) {
        const preview = '🎙️ Voice message';
        const now = new Date();
        const [message] = await this.prisma.$transaction([
            this.prisma.message.create({
                data: {
                    conversationId: data.conversationId,
                    senderUserId: data.senderUserId,
                    senderRole: data.senderRole,
                    type: client_1.MessageType.VOICE,
                    mediaUrl: data.mediaUrl,
                },
            }),
            this.prisma.conversation.update({
                where: { id: data.conversationId },
                data: { lastMessageAt: now, lastMessagePreview: preview },
            }),
        ]);
        return message;
    }
    async createLocationMessage(data) {
        const preview = '📍 Location';
        const now = new Date();
        const [message] = await this.prisma.$transaction([
            this.prisma.message.create({
                data: {
                    conversationId: data.conversationId,
                    senderUserId: data.senderUserId,
                    senderRole: data.senderRole,
                    type: client_1.MessageType.LOCATION,
                    latitude: data.latitude,
                    longitude: data.longitude,
                },
            }),
            this.prisma.conversation.update({
                where: { id: data.conversationId },
                data: { lastMessageAt: now, lastMessagePreview: preview },
            }),
        ]);
        return message;
    }
    async findMessageById(messageId) {
        return this.prisma.message.findUnique({ where: { id: messageId } });
    }
    async updateMessageText(messageId, text, editedAt) {
        return this.prisma.message.update({
            where: { id: messageId },
            data: { text, editedAt },
        });
    }
    async softDeleteMessage(messageId, deletedAt) {
        return this.prisma.message.update({
            where: { id: messageId },
            data: { deletedAt },
        });
    }
    async findWorkerUserByProfileId(workerProfileId) {
        const profile = await this.prisma.workerProfile.findUnique({
            where: { id: workerProfileId },
            select: { userId: true, firstName: true, lastName: true },
        });
        return profile ?? null;
    }
    async findClientProfileByUserId(userId) {
        return this.prisma.clientProfile.findUnique({
            where: { userId },
            select: { firstName: true, lastName: true, avatarUrl: true },
        });
    }
};
exports.ChatRepository = ChatRepository;
exports.ChatRepository = ChatRepository = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], ChatRepository);
//# sourceMappingURL=chat.repository.js.map