import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { MatchingRepository } from './matching.repository';
import { JobBroadcastService } from './job-broadcast.service';
import { JobCompletionNotifierService } from './job-completion-notifier.service';

/**
 * Deliberately a LEAF module: it imports only Notifications and Redis, never
 * Bookings / Workers / Bids.
 *
 * Broadcast fan-out and completion notifications are needed by BookingsService,
 * WorkersService AND BidsService. Putting them in any one of those and
 * injecting it into the others would create a cycle (Bookings ↔ Workers).
 * Hosting them here keeps the dependency graph acyclic — consumers import
 * MatchingModule, and nothing here imports them back.
 *
 * RedisModule is @Global, so RedisService needs no explicit import.
 */
@Module({
  imports: [NotificationsModule],
  providers: [
    MatchingRepository,
    JobBroadcastService,
    JobCompletionNotifierService,
  ],
  exports: [JobBroadcastService, JobCompletionNotifierService],
})
export class MatchingModule {}
