import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminStatsController } from './admin-stats.controller';
import { AdminClientAgreementsController } from './admin-client-agreements.controller';
import { AdminBookingsController } from './admin-bookings.controller';
import { AdminUsersController } from './admin-users.controller';
import { AdminOtpController } from './admin-otp.controller';
import { AdminClientsController } from './admin-clients.controller';
import { AdminService } from './admin.service';
import { AdminRepository } from './admin.repository';
import { AdminOtpService } from './admin-otp.service';
import { AdminOtpRepository } from './admin-otp.repository';
import { AdminClientsService } from './admin-clients.service';
import { AdminClientsRepository } from './admin-clients.repository';
import { AgreementsModule } from '../agreements/agreements.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [AgreementsModule, NotificationsModule],
  controllers: [
    AdminController,
    AdminStatsController,
    AdminClientAgreementsController,
    AdminBookingsController,
    AdminUsersController,
    AdminOtpController,
    AdminClientsController,
  ],
  providers: [
    AdminService,
    AdminRepository,
    AdminOtpService,
    AdminOtpRepository,
    AdminClientsService,
    AdminClientsRepository,
  ],
})
export class AdminModule {}
