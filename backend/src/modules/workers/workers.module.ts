import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bull';
import { WorkersController } from './workers.controller';
import { WorkersService } from './workers.service';
import { WorkersRepository } from './workers.repository';
import { WorkersProcessor, WORKERS_QUEUE } from './workers.processor';
import { NotificationsModule } from '../notifications/notifications.module';
import { BidsModule } from '../bids/bids.module';
import { StorageModule } from '../storage/storage.module';
import { AgreementsModule } from '../agreements/agreements.module';
import { MatchingModule } from '../matching/matching.module';
import { AdminOperationsModule } from '../admin/admin-operations.module';

@Module({
  imports: [
    NotificationsModule,
    MatchingModule,
    // Ustaad short-payment reporting reuses the shared settlement service.
    AdminOperationsModule,
    BidsModule,
    StorageModule,
    AgreementsModule,
    BullModule.registerQueue({ name: WORKERS_QUEUE }),
  ],
  controllers: [WorkersController],
  providers: [WorkersService, WorkersRepository, WorkersProcessor],
  exports: [WorkersService],
})
export class WorkersModule {}
