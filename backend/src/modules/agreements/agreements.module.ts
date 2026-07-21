import { Module } from '@nestjs/common';
import { AgreementsService } from './agreements.service';
import { AgreementsRepository } from './agreements.repository';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [StorageModule],
  providers: [AgreementsService, AgreementsRepository],
  exports: [AgreementsService],
})
export class AgreementsModule {}
