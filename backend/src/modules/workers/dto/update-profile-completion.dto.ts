import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsInt,
  IsBoolean,
  Min,
  MaxLength,
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
