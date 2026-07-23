import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsInt,
  IsBoolean,
  Min,
  MaxLength,
  Matches,
  Length,
} from 'class-validator';

/**
 * Partial update for the Ustaad profile-completion form. All fields are
 * optional so the Flutter form can PATCH whatever the worker has filled in
 * so far; POST /workers/profile-completion/submit is what actually enforces
 * everything being present before allowing SUBMITTED_FOR_REVIEW.
 */
export class UpdateProfileCompletionDto {
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  fullLegalName?: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  residentialAddress?: string;

  /** Pakistani CNIC — format 12345-1234567-1 (exactly 15 characters). */
  @IsOptional()
  @IsString()
  @Length(15, 15, {
    message: 'CNIC number must be exactly 15 characters, e.g. 12345-1234567-1',
  })
  @Matches(/^\d{5}-\d{7}-\d{1}$/, {
    message: 'CNIC number must be in the format 12345-1234567-1',
  })
  cnicNumber?: string;

  /** Reuses WorkerSkill.yearsExperience for the worker's single main skill. */
  @IsOptional()
  @IsInt()
  @Min(0)
  experienceYears?: number;

  /** "I confirm my legal name matches my CNIC." */
  @IsOptional()
  @IsBoolean()
  legalNameConfirmed?: boolean;

  @IsOptional()
  @IsBoolean()
  generalAgreementAccepted?: boolean;

  @IsOptional()
  @IsBoolean()
  tradeAgreementAccepted?: boolean;
}
