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
var ChatService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChatService = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const chat_repository_1 = require("./chat.repository");
const storage_service_1 = require("../storage/storage.service");
let ChatService = ChatService_1 = class ChatService {
    constructor(chatRepository, storageService) {
        this.chatRepository = chatRepository;
        this.storageService = storageService;
        this.logger = new common_1.Logger(ChatService_1.name);
    }
    async getOrCreateConversation(clientUserId, workerProfileId) {
        const worker = await this.chatRepository.findWorkerUserByProfileId(workerProfileId);
        if (!worker)
            throw new common_1.NotFoundException('Worker not found');
        const workerUserId = worker.userId;
        const existing = await this.chatRepository.findConversation(clientUserId, workerUserId);
        if (existing) {
            return this._toConversationDto(existing, clientUserId, client_1.Role.CLIENT);
        }
        const created = await this.chatRepository.createConversation({
            clientUserId,
            workerUserId,
            createdByUserId: clientUserId,
        });
        return this._toConversationDto(created, clientUserId, client_1.Role.CLIENT);
    }
    async ensureConversationForBooking(clientUserId, workerUserId) {
        try {
            const existing = await this.chatRepository.findConversation(clientUserId, workerUserId);
            if (existing)
                return;
            const created = await this.chatRepository.createConversation({
                clientUserId,
                workerUserId,
                createdByUserId: clientUserId,
            });
            await this.chatRepository.createSystemMessage({
                conversationId: created.id,
                senderUserId: clientUserId,
                text: 'Worker assigned to your booking',
            });
        }
        catch (err) {
            this.logger.warn(`[ensureConversationForBooking] failed for client=${clientUserId} worker=${workerUserId}: ${err?.message}`);
        }
    }
    async getMyConversations(userId, role) {
        const conversations = await this.chatRepository.findConversationsByUserId(userId, role);
        return conversations.map((c) => this._toConversationDto(c, userId, role));
    }
    async getMessages(userId, conversationId, limit = 50, before) {
        const conversation = await this.chatRepository.findConversationById(conversationId);
        if (!conversation)
            throw new common_1.NotFoundException('Conversation not found');
        this._assertParticipant(conversation, userId);
        const messages = await this.chatRepository.findMessages(conversationId, limit, before);
        return messages.map((m) => this._toMessageDto(m));
    }
    async sendMessage(userId, role, conversationId, text) {
        const conversation = await this.chatRepository.findConversationById(conversationId);
        if (!conversation)
            throw new common_1.NotFoundException('Conversation not found');
        this._assertParticipant(conversation, userId);
        const message = await this.chatRepository.createMessage({
            conversationId,
            senderUserId: userId,
            senderRole: role,
            text,
        });
        return this._toMessageDto(message);
    }
    async sendMediaMessage(userId, role, conversationId, buffer, originalName, mimeType) {
        const conversation = await this.chatRepository.findConversationById(conversationId);
        if (!conversation)
            throw new common_1.NotFoundException('Conversation not found');
        this._assertParticipant(conversation, userId);
        const isVideo = mimeType.startsWith('video/');
        const folder = isVideo ? 'chat-videos' : 'chat-images';
        const mediaUrl = await this.storageService.upload(buffer, originalName, mimeType, folder);
        const message = await this.chatRepository.createMediaMessage({
            conversationId,
            senderUserId: userId,
            senderRole: role,
            type: isVideo ? client_1.MessageType.VIDEO : client_1.MessageType.IMAGE,
            mediaUrl,
        });
        return this._toMessageDto(message);
    }
    async sendVoiceMessage(userId, role, conversationId, buffer, originalName) {
        const conversation = await this.chatRepository.findConversationById(conversationId);
        if (!conversation)
            throw new common_1.NotFoundException('Conversation not found');
        this._assertParticipant(conversation, userId);
        const mediaUrl = await this.storageService.upload(buffer, originalName, 'audio/m4a', 'chat-voice');
        const message = await this.chatRepository.createVoiceMessage({
            conversationId,
            senderUserId: userId,
            senderRole: role,
            mediaUrl,
        });
        return this._toMessageDto(message);
    }
    async sendLocationMessage(userId, role, conversationId, latitude, longitude) {
        const conversation = await this.chatRepository.findConversationById(conversationId);
        if (!conversation)
            throw new common_1.NotFoundException('Conversation not found');
        this._assertParticipant(conversation, userId);
        const message = await this.chatRepository.createLocationMessage({
            conversationId,
            senderUserId: userId,
            senderRole: role,
            latitude,
            longitude,
        });
        return this._toMessageDto(message);
    }
    async editMessage(userId, conversationId, messageId, text) {
        const conversation = await this.chatRepository.findConversationById(conversationId);
        if (!conversation)
            throw new common_1.NotFoundException('Conversation not found');
        this._assertParticipant(conversation, userId);
        const message = await this.chatRepository.findMessageById(messageId);
        if (!message)
            throw new common_1.NotFoundException('Message not found');
        if (message.conversationId !== conversationId)
            throw new common_1.ForbiddenException('Message not in this conversation');
        if (message.senderUserId !== userId)
            throw new common_1.ForbiddenException("Cannot edit another user's message");
        if (message.type !== client_1.MessageType.TEXT)
            throw new common_1.BadRequestException('Only text messages can be edited');
        if (message.deletedAt)
            throw new common_1.BadRequestException('Cannot edit a deleted message');
        const ageMs = Date.now() - message.createdAt.getTime();
        if (ageMs > 5 * 60 * 1000)
            throw new common_1.BadRequestException('Edit window has expired (5 minutes)');
        const updated = await this.chatRepository.updateMessageText(messageId, text, new Date());
        return this._toMessageDto(updated);
    }
    async deleteMessage(userId, conversationId, messageId) {
        const conversation = await this.chatRepository.findConversationById(conversationId);
        if (!conversation)
            throw new common_1.NotFoundException('Conversation not found');
        this._assertParticipant(conversation, userId);
        const message = await this.chatRepository.findMessageById(messageId);
        if (!message)
            throw new common_1.NotFoundException('Message not found');
        if (message.conversationId !== conversationId)
            throw new common_1.ForbiddenException('Message not in this conversation');
        if (message.senderUserId !== userId)
            throw new common_1.ForbiddenException("Cannot delete another user's message");
        if (message.deletedAt)
            throw new common_1.BadRequestException('Message already deleted');
        const ageMs = Date.now() - message.createdAt.getTime();
        if (ageMs > 5 * 60 * 1000)
            throw new common_1.BadRequestException('Delete window has expired (5 minutes)');
        const updated = await this.chatRepository.softDeleteMessage(messageId, new Date());
        return this._toMessageDto(updated);
    }
    _assertParticipant(conversation, userId) {
        const isParticipant = conversation.clientUserId === userId ||
            conversation.workerUserId === userId;
        if (!isParticipant)
            throw new common_1.ForbiddenException('Not a conversation participant');
    }
    _toConversationDto(c, callerId, callerRole) {
        const otherParticipant = callerRole === client_1.Role.CLIENT
            ? {
                userId: c.workerUserId,
                firstName: c.workerUser.workerProfile?.firstName ?? '',
                lastName: c.workerUser.workerProfile?.lastName ?? '',
                avatarUrl: c.workerUser.workerProfile?.avatarUrl ?? null,
                rating: c.workerUser.workerProfile?.rating ?? null,
            }
            : {
                userId: c.clientUserId,
                firstName: c.clientUser.clientProfile?.firstName ?? '',
                lastName: c.clientUser.clientProfile?.lastName ?? '',
                avatarUrl: c.clientUser.clientProfile?.avatarUrl ?? null,
                rating: null,
            };
        return {
            id: c.id,
            clientUserId: c.clientUserId,
            workerUserId: c.workerUserId,
            createdByUserId: c.createdByUserId,
            lastMessageAt: c.lastMessageAt?.toISOString() ?? null,
            lastMessagePreview: c.lastMessagePreview ?? null,
            createdAt: c.createdAt.toISOString(),
            updatedAt: c.updatedAt.toISOString(),
            otherParticipant,
        };
    }
    _toMessageDto(m) {
        return {
            id: m.id,
            conversationId: m.conversationId,
            senderUserId: m.senderUserId,
            senderRole: m.senderRole,
            type: m.type,
            text: m.text,
            mediaUrl: m.mediaUrl,
            thumbnailUrl: m.thumbnailUrl,
            latitude: m.latitude,
            longitude: m.longitude,
            bookingId: m.bookingId,
            replyToMessageId: m.replyToMessageId,
            editedAt: m.editedAt?.toISOString() ?? null,
            deletedAt: m.deletedAt?.toISOString() ?? null,
            seenAt: m.seenAt?.toISOString() ?? null,
            createdAt: m.createdAt.toISOString(),
            updatedAt: m.updatedAt.toISOString(),
        };
    }
};
exports.ChatService = ChatService;
exports.ChatService = ChatService = ChatService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [chat_repository_1.ChatRepository,
        storage_service_1.StorageService])
], ChatService);
//# sourceMappingURL=chat.service.js.map