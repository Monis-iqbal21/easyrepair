import { Module } from '@nestjs/common';
import { WorkersController } from './workers.controller';
import { WorkersService } from './workers.service';
import { WorkersRepository } from './workers.repository';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [WorkersController],
  providers: [WorkersService, WorkersRepository],
  exports: [WorkersService],
})
export class WorkersModule {}
