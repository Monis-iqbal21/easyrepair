import { IsEnum, IsNumber, IsOptional, Max, Min } from 'class-validator';
import { AvailabilityStatus } from '@prisma/client';

export class UpdateAvailabilityDto {
  @IsEnum(AvailabilityStatus)
  status: AvailabilityStatus;

  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  lat?: number;

  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  lng?: number;
}
