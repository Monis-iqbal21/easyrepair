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
exports.NotificationsRepository = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../../prisma/prisma.service");
let NotificationsRepository = class NotificationsRepository {
    constructor(prisma) {
        this.prisma = prisma;
    }
    async create(data) {
        return this.prisma.notification.create({
            data: {
                userId: data.userId,
                title: data.title,
                body: data.body,
                eventKey: data.eventKey,
                entityType: data.entityType,
                entityId: data.entityId,
                bookingId: data.bookingId,
                actorUserId: data.actorUserId,
                actorRole: data.actorRole,
                route: data.route,
                payload: data.payload
                    ? data.payload
                    : undefined,
            },
        });
    }
    async findByUserId(userId, limit = 50) {
        return this.prisma.notification.findMany({
            where: { userId },
            orderBy: { createdAt: 'desc' },
            take: limit,
        });
    }
    async markRead(id) {
        return this.prisma.notification.update({
            where: { id },
            data: { isRead: true, readAt: new Date() },
        });
    }
    async markAllRead(userId) {
        return this.prisma.notification.updateMany({
            where: { userId, isRead: false },
            data: { isRead: true, readAt: new Date() },
        });
    }
    async countUnread(userId) {
        return this.prisma.notification.count({
            where: { userId, isRead: false },
        });
    }
    async findUserFcmToken(userId) {
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            select: { fcmToken: true },
        });
        return user?.fcmToken ?? null;
    }
};
exports.NotificationsRepository = NotificationsRepository;
exports.NotificationsRepository = NotificationsRepository = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], NotificationsRepository);
//# sourceMappingURL=notifications.repository.js.map