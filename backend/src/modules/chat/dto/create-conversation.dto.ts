import { IsString, IsNotEmpty } from 'class-validator';

/**
 * Sent by a CLIENT to open (or retrieve) a conversation with a worker.
 * The workerProfileId is the WorkerProfile.id (as returned by the nearby-workers
 * and booking assignment endpoints).  The service resolves the corresponding
 * User.id internally.
 *
 * bookingId identifies which booking this chat belongs to — required so the
 * backend can verify the client owns the booking and the worker is actually
 * eligible for it (assigned/completed worker, the inspecting worker, or a
 * genuinely available/bidding candidate) before creating a brand-new
 * conversation. Not needed to reopen an already-existing conversation.
 */
export class CreateConversationDto {
  @IsString()
  @IsNotEmpty()
  workerProfileId: string;

  @IsString()
  @IsNotEmpty()
  bookingId: string;
}
