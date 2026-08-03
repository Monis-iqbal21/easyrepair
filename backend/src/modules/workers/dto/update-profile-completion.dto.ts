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

  /**
   * Father's name as per CNIC. Required — the Background Verification / EVS
   * Consent document has a "Walid ka naam" blank that cannot be generated
   * without it, so submission fails rather than sealing a document with a hole.
   */
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  fatherName?: string;

  /**
   * Date of birth as per CNIC, as an ISO calendar date (yyyy-MM-dd). Stored
   * as text so the value printed on the legal document is exactly the one the
   * Ustaad entered, with no timezone shifting it by a day.
   */
  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message: 'Date of birth must be in the format yyyy-MM-dd',
  })
  dateOfBirth?: string;

  /**
   * Optional "Name, +92…" emergency contact. Genuinely optional: the EVS
   * document prints a controlled "Not applicable" when it is absent.
   */
  @IsOptional()
  @IsString()
  @MaxLength(200)
  emergencyContact?: string;

  /** Reuses WorkerSkill.yearsExperience for the worker's single main skill. */
  @IsOptional()
  @IsInt()
  @Min(0)
  experienceYears?: number;

  /** "I confirm my legal name matches my CNIC." */
  @IsOptional()
  @IsBoolean()
  legalNameConfirmed?: boolean;

  // The old generalAgreementAccepted / tradeAgreementAccepted booleans are
  // deliberately gone. Acceptance is no longer a checkbox the app can PATCH:
  // it is per-document evidence submitted to
  // POST /workers/profile-completion/submit and validated against the exact
  // version, hash, locale and trade the server just loaded.
}
