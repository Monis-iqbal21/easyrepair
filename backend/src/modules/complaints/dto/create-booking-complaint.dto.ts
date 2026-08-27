import { Transform } from 'class-transformer';
import {
  ArrayNotEmpty,
  ArrayUnique,
  IsArray,
  IsEnum,
  IsNotEmpty,
  IsString,
  MaxLength,
  ValidateIf,
} from 'class-validator';
import { ComplaintIssueType } from '@prisma/client';

export class CreateBookingComplaintDto {
  @IsArray()
  @ArrayNotEmpty()
  @ArrayUnique()
  @IsEnum(ComplaintIssueType, { each: true })
  issueTypes!: ComplaintIssueType[];

  @ValidateIf(
    (value: CreateBookingComplaintDto) =>
      value.otherText !== undefined ||
      value.issueTypes?.includes(ComplaintIssueType.OTHER),
  )
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @IsNotEmpty()
  @MaxLength(2000)
  otherText?: string;
}
