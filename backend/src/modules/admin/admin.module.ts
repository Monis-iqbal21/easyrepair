import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminStatsController } from './admin-stats.controller';
import { AdminService } from './admin.service';
import { AdminRepository } from './admin.repository';
import { AgreementsModule } from '../agreements/agreements.module';

@Module({
  imports: [AgreementsModule],
  controllers: [AdminController, AdminStatsController],
  providers: [AdminService, AdminRepository],
})
export class AdminModule {}
