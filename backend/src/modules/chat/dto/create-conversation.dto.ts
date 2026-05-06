import { IsString, IsNotEmpty } from 'class-validator';

/**
 * Sent by a CLIENT to open (or retrieve) a conversation with a worker.
 * The workerProfileId is the WorkerProfile.id (as returned by the nearby-workers
 * and booking assignment endpoints).  The service resolves the corresponding
 * User.id internally.
 */
export class CreateConversationDto {
  @IsString()
  @IsNotEmpty()
  workerProfileId: string;
}
