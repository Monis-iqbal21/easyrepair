import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bull';
import { BookingsService } from './bookings.service';
import { BookingsController } from './bookings.controller';
import { BookingsRepository } from './bookings.repository';
import { BookingsProcessor, BOOKINGS_QUEUE } from './bookings.processor';
import { StorageModule } from '../storage/storage.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { ChatModule } from '../chat/chat.module';

@Module({
  imports: [
    StorageModule,
    NotificationsModule,
    ChatModule,
    BullModule.registerQueue({ name: BOOKINGS_QUEUE }),
  ],
  controllers: [BookingsController],
  providers: [BookingsService, BookingsRepository, BookingsProcessor],
  exports: [BookingsService],
})
export class BookingsModule {}
