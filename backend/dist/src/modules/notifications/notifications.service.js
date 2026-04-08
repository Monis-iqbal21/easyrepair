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
var NotificationsService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotificationsService = void 0;
const common_1 = require("@nestjs/common");
const firebase_service_1 = require("../../firebase/firebase.service");
const notifications_repository_1 = require("./notifications.repository");
let NotificationsService = NotificationsService_1 = class NotificationsService {
    constructor(notificationsRepository, firebase) {
        this.notificationsRepository = notificationsRepository;
        this.firebase = firebase;
        this.logger = new common_1.Logger(NotificationsService_1.name);
    }
    async notify(options) {
        const { userId, title, body, eventKey, bookingId, route, actorUserId, actorRole, entityType, entityId, payload, } = options;
        const data = {
            userId,
            title,
            body,
            eventKey,
            entityType: entityType ?? (bookingId ? 'booking' : undefined),
            entityId: entityId ?? bookingId,
            bookingId,
            actorUserId,
            actorRole,
            route,
            payload,
        };
        try {
            await this.notificationsRepository.create(data);
        }
        catch (err) {
            this.logger.warn(`Failed to persist notification for userId=${userId}: ${err}`);
        }
        void this._sendPush(userId, title, body, {
            eventKey: eventKey ?? '',
            entityType: entityType ?? (bookingId ? 'booking' : ''),
            entityId: entityId ?? bookingId ?? '',
            bookingId: bookingId ?? '',
            route: route ?? '',
            actorUserId: actorUserId ?? '',
            actorRole: actorRole ?? '',
        });
    }
    async _sendPush(userId, title, body, data) {
        try {
            const fcmToken = await this.notificationsRepository.findUserFcmToken(userId);
            if (!fcmToken) {
                this.logger.debug(`No FCM token for userId=${userId}`);
                return;
            }
            await this.firebase.sendPush(fcmToken, title, body, data);
            this.logger.debug(`Push sent to userId=${userId} eventKey=${data.eventKey}`);
        }
        catch (err) {
            this.logger.warn(`FCM push failed for userId=${userId}: ${err}`);
        }
    }
    async getNotifications(userId) {
        return this.notificationsRepository.findByUserId(userId);
    }
    async markRead(id) {
        return this.notificationsRepository.markRead(id);
    }
    async markAllRead(userId) {
        return this.notificationsRepository.markAllRead(userId);
    }
    async getUnreadCount(userId) {
        return this.notificationsRepository.countUnread(userId);
    }
};
exports.NotificationsService = NotificationsService;
exports.NotificationsService = NotificationsService = NotificationsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [notifications_repository_1.NotificationsRepository,
        firebase_service_1.FirebaseService])
], NotificationsService);
//# sourceMappingURL=notifications.service.js.map