import { Module } from '@nestjs/common';
import { AdminOperationsRepository } from './admin-operations.repository';
import { AdminOperationsService } from './admin-operations.service';

/** Shared authoritative settlement operations for Admin and Client routes. */
@Module({
  providers: [AdminOperationsService, AdminOperationsRepository],
  exports: [AdminOperationsService],
})
export class AdminOperationsModule {}
