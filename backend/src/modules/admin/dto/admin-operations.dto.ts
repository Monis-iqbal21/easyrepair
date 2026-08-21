import { Type } from 'class-transformer';
import {
  IsDateString,
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
  BookingLane,
  BookingStatus,
  CommissionCollectionStatus,
  ContactChannel,
  ContactOutcome,
  SettlementCasePriority,
  SettlementCaseStatus,
  SettlementCaseType,
  SettlementSource,
} from '@prisma/client';

export class PageQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page = 1;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) pageSize = 20;
}

export class ListAdminBookingsQueryDto extends PageQueryDto {
  @IsOptional() @IsString() @MaxLength(100) search?: string;
  @IsOptional() @IsEnum(BookingStatus) status?: BookingStatus;
  @IsOptional() @IsEnum(BookingLane) lane?: BookingLane;
  @IsOptional() @IsUUID('4') workerProfileId?: string;
  @IsOptional() @IsDateString() from?: string;
  @IsOptional() @IsDateString() to?: string;
}

export class CreateSettlementDto {
  @Type(() => Number) @IsInt() @Min(0) received: number;
  @IsEnum(SettlementSource) source: SettlementSource;
  @IsOptional() @IsString() @MaxLength(2000) note?: string;
}

export class CorrectSettlementDto extends CreateSettlementDto {
  @IsUUID('4') supersedesId: string;
}

export class ListSettlementCasesQueryDto extends PageQueryDto {
  @IsOptional() @IsEnum(SettlementCaseStatus) status?: SettlementCaseStatus;
  @IsOptional() @IsEnum(SettlementCaseType) type?: SettlementCaseType;
  @IsOptional()
  @IsEnum(SettlementCasePriority)
  priority?: SettlementCasePriority;
  @IsOptional() @IsUUID('4') assignedToUserId?: string;
  @IsOptional() @IsUUID('4') workerProfileId?: string;
}

export class UpdateSettlementCaseDto {
  @IsOptional() @IsEnum(SettlementCaseStatus) status?: SettlementCaseStatus;
  @IsOptional()
  @IsEnum(SettlementCasePriority)
  priority?: SettlementCasePriority;
  @IsOptional() @IsUUID('4') assignedToUserId?: string;
}

export class AddSettlementCaseNoteDto {
  @IsString() @MaxLength(4000) body: string;
}

export class AddContactAttemptDto {
  @IsEnum(ContactChannel) channel: ContactChannel;
  @IsEnum(ContactOutcome) outcome: ContactOutcome;
  @IsOptional() @IsString() @MaxLength(2000) note?: string;
  @IsOptional() @IsDateString() followUpAt?: string;
}

export class RunNightlyCollectionDto {
  @IsOptional() @IsDateString() collectionDate?: string;
}

export class UpdateCollectionDto {
  @IsEnum(CommissionCollectionStatus) status: CommissionCollectionStatus;
  @IsOptional() @IsString() @MaxLength(1000) failureReason?: string;
}

export class ListCollectionsQueryDto extends PageQueryDto {
  @IsOptional()
  @IsEnum(CommissionCollectionStatus)
  status?: CommissionCollectionStatus;
  @IsOptional() @IsUUID('4') workerProfileId?: string;
  @IsOptional() @IsDateString() collectionDate?: string;
}
