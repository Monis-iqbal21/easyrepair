import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import {
  ComplaintPriority,
  ComplaintSource,
  ComplaintStatus,
} from '@prisma/client';

export class ListComplaintsQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize = 20;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  search?: string;

  @IsOptional()
  @IsEnum(ComplaintStatus)
  status?: ComplaintStatus;

  @IsOptional()
  @IsEnum(ComplaintPriority)
  priority?: ComplaintPriority;

  @IsOptional()
  @IsEnum(ComplaintSource)
  source?: ComplaintSource;

  @IsOptional()
  @IsUUID('4')
  assignedToUserId?: string;

  @IsOptional()
  @Transform(({ value }) =>
    value === 'true' ? true : value === 'false' ? false : value,
  )
  @IsBoolean()
  humanRequested?: boolean;
}

export class ChangeComplaintStatusDto {
  @IsEnum(ComplaintStatus)
  status!: ComplaintStatus;
}

export class ChangeComplaintPriorityDto {
  @IsEnum(ComplaintPriority)
  priority!: ComplaintPriority;
}

export class AssignComplaintDto {
  @IsOptional()
  @IsUUID('4')
  assignedToUserId?: string | null;
}
