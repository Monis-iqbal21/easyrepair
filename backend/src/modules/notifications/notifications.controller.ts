import {
  Controller,
  Get,
  Patch,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { NotificationsService } from './notifications.service';
import { NotificationResponseDto } from './dto/notification-response.dto';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  /** GET /notifications — paginated list for the authenticated user */
  @Get()
  async getNotifications(
    @CurrentUser() user: { id: string },
  ): Promise<NotificationResponseDto[]> {
    const notifications = await this.notificationsService.getNotifications(
      user.id,
    );
    return notifications.map((n) => ({
      id: n.id,
      title: n.title,
      body: n.body,
      isRead: n.isRead,
      readAt: n.readAt?.toISOString() ?? null,
      eventKey: n.eventKey ?? null,
      bookingId: n.bookingId ?? null,
      route: n.route ?? null,
      payload: n.payload as Record<string, unknown> | null,
      createdAt: n.createdAt.toISOString(),
    }));
  }

  /** GET /notifications/unread-count */
  @Get('unread-count')
  async getUnreadCount(@CurrentUser() user: { id: string }) {
    const count = await this.notificationsService.getUnreadCount(user.id);
    return { count };
  }

  /** PATCH /notifications/:id/read */
  @Patch(':id/read')
  @HttpCode(HttpStatus.OK)
  async markRead(@Param('id') id: string) {
    await this.notificationsService.markRead(id);
    return { success: true };
  }

  /** PATCH /notifications/read-all */
  @Patch('read-all')
  @HttpCode(HttpStatus.OK)
  async markAllRead(@CurrentUser() user: { id: string }) {
    await this.notificationsService.markAllRead(user.id);
    return { success: true };
  }
}
