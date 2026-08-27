import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import {
  ClientComplaintsController,
  SupportComplaintsController,
} from './complaints.controller';
import { ComplaintsRepository } from './complaints.repository';
import { ComplaintsService } from './complaints.service';

@Module({
  imports: [NotificationsModule],
  controllers: [ClientComplaintsController, SupportComplaintsController],
  providers: [ComplaintsService, ComplaintsRepository],
  exports: [ComplaintsService],
})
export class ComplaintsModule {}
