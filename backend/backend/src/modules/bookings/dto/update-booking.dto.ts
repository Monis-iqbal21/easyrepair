import {
  IsString,
  IsOptional,
  IsEnum,
  IsNumber,
  IsDateString,
  MaxLength,
  Min,
  Max,
} from 'class-validator';
import { Transform } from 'class-transformer';
import { BookingUrgency, TimeSlot } from '@prisma/client';

export class UpdateBookingDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  serviceCategory?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? (value.toUpperCase() as BookingUrgency) : value,
  )
  @IsEnum(BookingUrgency)
  urgency?: BookingUrgency;

  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? (value.toUpperCase() as TimeSlot) : value,
  )
  @IsEnum(TimeSlot)
  timeSlot?: TimeSlot;

  @IsOptional()
  @IsDateString()
  scheduledAt?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  addressLine?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  city?: string;

  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;
}
