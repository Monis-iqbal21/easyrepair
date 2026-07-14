import { Module, forwardRef } from '@nestjs/common';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { NotificationsRepository } from './notifications.repository';
import { ChatModule } from '../chat/chat.module';

@Module({
  // forwardRef: ChatModule imports NotificationsModule (chat messages send
  // push notifications), and NotificationsService needs ChatGateway to emit
  // in-app banners — forwardRef on both sides breaks the resulting cycle.
  imports: [forwardRef(() => ChatModule)],
  controllers: [NotificationsController],
  providers: [NotificationsService, NotificationsRepository],
  exports: [NotificationsService],
})
export class NotificationsModule {}
