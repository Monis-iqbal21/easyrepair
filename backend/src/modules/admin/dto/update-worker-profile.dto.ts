import {
  IsString,
  IsNotEmpty,
  IsOptional,
  MaxLength,
  Matches,
  Length,
} from 'class-validator';

/**
 * PATCH /admin/workers/:id — admin-editable operational profile fields only.
 * Deliberately excludes: phone (auth identity, see AdminService doc comment),
 * CNIC/selfie images, agreement/acceptance evidence, onboarding/verification
 * status (owned by the existing Pending Ustaads review workflow), and every
 * database id/timestamp. All fields optional so the admin UI can PATCH only
 * what changed.
 */
export class UpdateWorkerProfileDto {
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  firstName?: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  lastName?: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  fullLegalName?: string;

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

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  residentialAddress?: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  fatherName?: string;

  /** ISO calendar date (yyyy-MM-dd), same format the profile-completion form uses. */
  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message: 'Date of birth must be in the format yyyy-MM-dd',
  })
  dateOfBirth?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  emergencyContact?: string;
}
