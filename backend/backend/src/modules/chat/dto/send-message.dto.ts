import { IsString, IsNotEmpty, MaxLength } from 'class-validator';

/**
 * Phase 1: text-only messages.
 * Future phases will add type, mediaUrl, location, replyToMessageId, etc.
 */
export class SendMessageDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(4000)
  text: string;
}
