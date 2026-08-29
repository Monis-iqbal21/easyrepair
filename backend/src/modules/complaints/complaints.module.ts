import { Module } from '@nestjs/common';
import { ChatModule } from '../chat/chat.module';
import { NotificationsModule } from '../notifications/notifications.module';
import {
  ClientComplaintsController,
  SupportComplaintsController,
} from './complaints.controller';
import { ComplaintsRepository } from './complaints.repository';
import { ComplaintsService } from './complaints.service';

@Module({
  // ChatModule supplies the ONE permanent HandyGo Support conversation per
  // user (get-or-create) that a new complaint is announced into.
  imports: [NotificationsModule, ChatModule],
  controllers: [ClientComplaintsController, SupportComplaintsController],
  providers: [ComplaintsService, ComplaintsRepository],
  exports: [ComplaintsService],
})
export class ComplaintsModule {}
