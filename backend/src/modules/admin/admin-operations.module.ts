import { Module, forwardRef } from '@nestjs/common';
import { AdminOperationsRepository } from './admin-operations.repository';
import { AdminOperationsService } from './admin-operations.service';
import { NotificationsModule } from '../notifications/notifications.module';

/**
 * Shared authoritative settlement operations for the Admin, Client and Ustaad
 * routes.
 *
 * forwardRef: recording a settlement now notifies the Ustaad, and
 * NotificationsModule reaches back here through Chat → Bookings → this module.
 */
@Module({
  imports: [forwardRef(() => NotificationsModule)],
  providers: [AdminOperationsService, AdminOperationsRepository],
  exports: [AdminOperationsService],
})
export class AdminOperationsModule {}
