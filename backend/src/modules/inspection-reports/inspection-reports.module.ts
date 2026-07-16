import { Module } from '@nestjs/common';
import { InspectionReportsController } from './inspection-reports.controller';
import { InspectionReportsService } from './inspection-reports.service';
import { InspectionReportsRepository } from './inspection-reports.repository';
import { StorageModule } from '../storage/storage.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { BookingsModule } from '../bookings/bookings.module';

@Module({
  imports: [StorageModule, NotificationsModule, BookingsModule],
  controllers: [InspectionReportsController],
  providers: [InspectionReportsService, InspectionReportsRepository],
})
export class InspectionReportsModule {}
