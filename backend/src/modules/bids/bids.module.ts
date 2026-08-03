import { Module } from '@nestjs/common';
import { BidsController } from './bids.controller';
import { BidsService } from './bids.service';
import { BidsRepository } from './bids.repository';
import { NotificationsModule } from '../notifications/notifications.module';
import { ChatModule } from '../chat/chat.module';
import { MatchingModule } from '../matching/matching.module';

@Module({
  imports: [NotificationsModule, ChatModule, MatchingModule],
  controllers: [BidsController],
  providers: [BidsService, BidsRepository],
  exports: [BidsService],
})
export class BidsModule {}
