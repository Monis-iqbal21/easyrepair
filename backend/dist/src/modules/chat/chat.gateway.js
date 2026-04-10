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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var ChatGateway_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChatGateway = void 0;
const websockets_1 = require("@nestjs/websockets");
const common_1 = require("@nestjs/common");
const jwt_1 = require("@nestjs/jwt");
const config_1 = require("@nestjs/config");
const socket_io_1 = require("socket.io");
const chat_repository_1 = require("./chat.repository");
let ChatGateway = ChatGateway_1 = class ChatGateway {
    constructor(chatRepository, jwtService, configService) {
        this.chatRepository = chatRepository;
        this.jwtService = jwtService;
        this.configService = configService;
        this.logger = new common_1.Logger(ChatGateway_1.name);
    }
    async handleConnection(socket) {
        try {
            const token = socket.handshake.auth?.token;
            if (!token) {
                socket.disconnect();
                return;
            }
            const payload = this.jwtService.verify(token, {
                secret: this.configService.getOrThrow('jwt.secret'),
            });
            socket.data.userId = payload.sub;
            socket.data.role = payload.role;
            await socket.join(`user:${payload.sub}`);
            this.logger.log(`[chat] connected userId=${payload.sub}`);
        }
        catch (err) {
            this.logger.warn(`[chat] auth failed: ${err?.message}`);
            socket.disconnect();
        }
    }
    handleDisconnect(socket) {
        const userId = socket.data?.userId ?? 'unknown';
        this.logger.log(`[chat] disconnected userId=${userId}`);
    }
    async handleJoinConversation(socket, payload) {
        try {
            const { userId } = socket.data;
            const conversation = await this.chatRepository.findConversationById(payload.conversationId);
            if (!conversation)
                return;
            const isParticipant = conversation.clientUserId === userId ||
                conversation.workerUserId === userId;
            if (!isParticipant)
                return;
            await socket.join(`conversation:${payload.conversationId}`);
        }
        catch (err) {
            this.logger.warn(`[chat] join_conversation failed: ${err?.message}`);
        }
    }
    async handleLeaveConversation(socket, payload) {
        await socket.leave(`conversation:${payload.conversationId}`);
    }
    async handleMarkSeen(socket, payload) {
        try {
            const { userId } = socket.data;
            const conversation = await this.chatRepository.findConversationById(payload.conversationId);
            if (!conversation)
                return;
            const isParticipant = conversation.clientUserId === userId ||
                conversation.workerUserId === userId;
            if (!isParticipant)
                return;
            const seenAt = new Date();
            await this.chatRepository.markMessageSeen(payload.messageId, userId, seenAt);
            this.server
                .to(`conversation:${payload.conversationId}`)
                .emit('message_seen', {
                messageId: payload.messageId,
                seenAt: seenAt.toISOString(),
            });
        }
        catch (err) {
            this.logger.warn(`[chat] mark_seen failed: ${err?.message}`);
        }
    }
    async broadcastNewMessage(conversationId, message) {
        try {
            this.server
                .to(`conversation:${conversationId}`)
                .emit('new_message', message);
            const participants = await this.chatRepository.findConversationParticipants(conversationId);
            if (!participants)
                return;
            const preview = message.text != null
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
        }
        catch (err) {
            this.logger.warn(`[chat] broadcastNewMessage failed: ${err?.message}`);
        }
    }
};
exports.ChatGateway = ChatGateway;
__decorate([
    (0, websockets_1.WebSocketServer)(),
    __metadata("design:type", socket_io_1.Server)
], ChatGateway.prototype, "server", void 0);
__decorate([
    (0, websockets_1.SubscribeMessage)('join_conversation'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __param(1, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], ChatGateway.prototype, "handleJoinConversation", null);
__decorate([
    (0, websockets_1.SubscribeMessage)('leave_conversation'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __param(1, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], ChatGateway.prototype, "handleLeaveConversation", null);
__decorate([
    (0, websockets_1.SubscribeMessage)('mark_seen'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __param(1, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], ChatGateway.prototype, "handleMarkSeen", null);
exports.ChatGateway = ChatGateway = ChatGateway_1 = __decorate([
    (0, websockets_1.WebSocketGateway)({ namespace: '/chat', cors: { origin: '*' } }),
    __metadata("design:paramtypes", [chat_repository_1.ChatRepository,
        jwt_1.JwtService,
        config_1.ConfigService])
], ChatGateway);
//# sourceMappingURL=chat.gateway.js.map