import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

export class InspectionReportPartDto {
  @IsString()
  @MinLength(1)
  name: string;

  @IsInt()
  @Min(1)
  quantity: number;

  @IsNumber()
  @Min(0)
  unitPrice: number;

  @IsOptional()
  @IsString()
  warranty?: string;
}

export class CreateInspectionReportDto {
  // Either (issueFound & recommendedRepair) or a voice note is required — enforced
  // in the controller after DTO validation, since it needs to know if a voice file
  // was uploaded alongside this payload.
  @IsOptional()
  @IsString()
  issueFound?: string;

  @IsOptional()
  @IsString()
  recommendedRepair?: string;

  @IsNumber()
  @Min(0)
  labourCost: number;

  @IsBoolean()
  partsNeeded: boolean;

  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => InspectionReportPartDto)
  parts?: InspectionReportPartDto[];

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  voiceNoteDurationSeconds?: number;
}
