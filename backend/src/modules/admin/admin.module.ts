import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminStatsController } from './admin-stats.controller';
import { AdminClientAgreementsController } from './admin-client-agreements.controller';
import { AdminBookingsController } from './admin-bookings.controller';
import { AdminService } from './admin.service';
import { AdminRepository } from './admin.repository';
import { AgreementsModule } from '../agreements/agreements.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [AgreementsModule, NotificationsModule],
  controllers: [
    AdminController,
    AdminStatsController,
    AdminClientAgreementsController,
    AdminBookingsController,
  ],
  providers: [AdminService, AdminRepository],
})
export class AdminModule {}
