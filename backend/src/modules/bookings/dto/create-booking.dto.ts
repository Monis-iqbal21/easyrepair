import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsEnum,
  IsNumber,
  IsISO8601,
  IsBoolean,
  IsUUID,
  IsArray,
  ArrayMinSize,
  MaxLength,
  Min,
  Max,
} from 'class-validator';
import { Transform } from 'class-transformer';
import {
  BookingLane,
  BookingUrgency,
  TimeSlot,
  UrgentWindow,
} from '@prisma/client';

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

  // True when the client wants an inspection visit first instead of
  // describing the issue upfront. Defaults to false when omitted.
  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value === 'true' : value,
  )
  @IsBoolean()
  inspection?: boolean;

  // Client-selected urgent arrival window (only meaningful when urgency is
  // URGENT). Nullable/omitted for scheduled bookings.
  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(UrgentWindow)
  urgentWindow?: UrgentWindow;

  // Booking lane: STANDARD (fixed-price catalog), INSPECTION (fixed fee), or
  // BIDDING (open bidding — the existing known-problem flow). Optional for
  // backward compatibility with older app builds that don't send it; the
  // service layer defaults missing/omitted lane to BIDDING.
  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(BookingLane)
  lane?: BookingLane;

  // Legacy single-service field — kept for backward compatibility with older
  // app builds. When standardServiceIds is also sent, standardServiceIds
  // takes precedence; the service layer treats this as a 1-item list.
  @IsOptional()
  @IsString()
  @IsUUID()
  standardServiceId?: string;

  // Multi-select STANDARD-lane services (e.g. AC General Service + AC
  // Dismounting). Preferred over standardServiceId for new app builds.
  // The service layer validates each id belongs to the selected category.
  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @IsUUID('4', { each: true })
  standardServiceIds?: string[];
}
