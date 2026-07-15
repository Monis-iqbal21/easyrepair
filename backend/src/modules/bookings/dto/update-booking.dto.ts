import {
  IsString,
  IsOptional,
  IsEnum,
  IsNumber,
  IsDateString,
  IsBoolean,
  IsArray,
  IsUUID,
  MaxLength,
  Min,
  Max,
} from 'class-validator';
import { Transform } from 'class-transformer';
import { BookingUrgency, TimeSlot, UrgentWindow } from '@prisma/client';

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

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? value === 'true' : value))
  @IsBoolean()
  inspection?: boolean;

  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? (value.toUpperCase() as UrgentWindow) : value,
  )
  @IsEnum(UrgentWindow)
  urgentWindow?: UrgentWindow;

  // Replace the STANDARD-lane sub-service selection. Only valid when the
  // booking's lane is already STANDARD — the service layer rejects this on
  // any other lane (lane itself is never editable via this DTO).
  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  standardServiceIds?: string[];
}
