import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminStatsController } from './admin-stats.controller';
import { AdminClientAgreementsController } from './admin-client-agreements.controller';
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
import { StorageModule } from '../storage/storage.module';
import {
  AdminBookingOperationsController,
  AdminCommissionCollectionsController,
  AdminSettlementCasesController,
} from './admin-operations.controller';
import { AdminOperationsService } from './admin-operations.service';
import { AdminOperationsModule } from './admin-operations.module';
import {
  AdminOperationsScheduler,
  ADMIN_OPERATIONS_QUEUE_FACTORY,
  defaultAdminOperationsQueueFactory,
} from './admin-operations.processor';

@Module({
  imports: [
    AgreementsModule,
    NotificationsModule,
    StorageModule,
    AdminOperationsModule,
  ],
  controllers: [
    AdminController,
    AdminStatsController,
    AdminClientAgreementsController,
    AdminUsersController,
    AdminOtpController,
    AdminClientsController,
    AdminBookingOperationsController,
    AdminSettlementCasesController,
    AdminCommissionCollectionsController,
  ],
  providers: [
    AdminService,
    AdminRepository,
    AdminOtpService,
    AdminOtpRepository,
    AdminClientsService,
    AdminClientsRepository,
    AdminOperationsScheduler,
    {
      provide: ADMIN_OPERATIONS_QUEUE_FACTORY,
      useValue: defaultAdminOperationsQueueFactory,
    },
  ],
  exports: [AdminOperationsScheduler],
})
export class AdminModule {}
