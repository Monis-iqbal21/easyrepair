import { ServiceAvailabilityStatus } from '@prisma/client';
import { IsEnum } from 'class-validator';

export class UpdateServiceCategoryAvailabilityDto {
  @IsEnum(ServiceAvailabilityStatus)
  status: ServiceAvailabilityStatus;
}
