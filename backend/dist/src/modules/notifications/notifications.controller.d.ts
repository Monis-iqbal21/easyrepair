import { NotificationsService } from './notifications.service';
import { NotificationResponseDto } from './dto/notification-response.dto';
export declare class NotificationsController {
    private readonly notificationsService;
    constructor(notificationsService: NotificationsService);
    getNotifications(user: {
        id: string;
    }): Promise<NotificationResponseDto[]>;
    getUnreadCount(user: {
        id: string;
    }): Promise<{
        count: number;
    }>;
    markRead(id: string): Promise<{
        success: boolean;
    }>;
    markAllRead(user: {
        id: string;
    }): Promise<{
        success: boolean;
    }>;
}
