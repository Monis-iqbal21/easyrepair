import { IsString, IsUUID } from 'class-validator';

export class AssignWorkerDto {
  @IsString()
  @IsUUID()
  workerProfileId: string;
}
