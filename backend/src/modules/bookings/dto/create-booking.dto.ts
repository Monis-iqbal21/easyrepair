import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsEnum,
  IsNumber,
  IsISO8601,
  MaxLength,
  Min,
  Max,
} from 'class-validator';
import { Transform } from 'class-transformer';
import { BookingUrgency, TimeSlot } from '@prisma/client';

export class CreateBookingDto {
  @IsString()
  @IsNotEmpty()
  serviceCategory: string;

  // Accept 'URGENT'/'NORMAL' or 'urgent'/'normal' from the client.
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(BookingUrgency)
  urgency: BookingUrgency;

  // Accept 'MORNING'/'morning'/'Morning' etc.
  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(TimeSlot)
  timeSlot?: TimeSlot;

  @IsOptional()
  @IsISO8601()
  scheduledAt?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  title?: string;

  // Description is optional — the form field is labelled "optional".
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @IsString()
  @IsNotEmpty()
  addressLine: string;

  @IsOptional()
  @IsString()
  city?: string;

  // Required — every booking must carry a real GPS fix.
  // Service layer additionally rejects 0,0.
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude: number;
}
