import { IsString, IsNotEmpty, MaxLength } from 'class-validator';

export class WorkerCancelBookingDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  reason: string;
}
