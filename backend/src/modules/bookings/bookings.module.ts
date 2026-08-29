import { Module, forwardRef } from '@nestjs/common';
import { BullModule } from '@nestjs/bull';
import { BookingsService } from './bookings.service';
import { BookingsController } from './bookings.controller';
import { BookingsRepository } from './bookings.repository';
import { BookingsProcessor, BOOKINGS_QUEUE } from './bookings.processor';
import { BookingExpiryService } from './booking-expiry.service';
import { BookingExpiryScheduler } from './booking-expiry.scheduler';
import { StorageModule } from '../storage/storage.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { ChatModule } from '../chat/chat.module';
import { MatchingModule } from '../matching/matching.module';
import { AdminOperationsModule } from '../admin/admin-operations.module';

@Module({
  imports: [
    StorageModule,
    NotificationsModule,
    MatchingModule,
    AdminOperationsModule,
    // forwardRef: ChatService now also needs BookingsService's shared
    // chat-eligibility check — forwardRef on both sides breaks that cycle.
    forwardRef(() => ChatModule),
    BullModule.registerQueue({ name: BOOKINGS_QUEUE }),
  ],
  controllers: [BookingsController],
  providers: [
    BookingsService,
    BookingsRepository,
    BookingsProcessor,
    BookingExpiryService,
    BookingExpiryScheduler,
  ],
  exports: [BookingsService, BookingExpiryScheduler],
})
export class BookingsModule {}
