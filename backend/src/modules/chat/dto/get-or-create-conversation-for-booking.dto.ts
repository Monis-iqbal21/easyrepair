import { IsString, IsNotEmpty } from 'class-validator';

/**
 * Sent by a WORKER to open (or retrieve) the conversation with the client
 * who posted a given booking — used so a worker can ask questions before
 * placing a bid. The service resolves the client's User.id internally and
 * enforces that the booking isn't already assigned to a different worker.
 */
export class GetOrCreateConversationForBookingDto {
  @IsString()
  @IsNotEmpty()
  bookingId: string;
}
