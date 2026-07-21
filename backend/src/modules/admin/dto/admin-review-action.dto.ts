import { IsString, IsNotEmpty, MaxLength, IsEnum } from 'class-validator';
import { FaceMatchStatus, TrainingStatus } from '@prisma/client';

export class RejectWorkerDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  reason: string;
}

export class RequestChangesDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  reason: string;
}

export class UpdateFaceMatchStatusDto {
  @IsEnum(FaceMatchStatus)
  status: FaceMatchStatus;
}

export class UpdateTrainingStatusDto {
  @IsEnum(TrainingStatus)
  status: TrainingStatus;
}
