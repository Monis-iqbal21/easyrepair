import { Transform } from 'class-transformer';
import {
  ArrayNotEmpty,
  ArrayUnique,
  IsArray,
  IsEnum,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { ComplaintIssueType } from '@prisma/client';

/**
 * Shortest complaint text Support can actually act on.
 *
 * A ticked box alone ("Work quality") tells Support nothing they can call the
 * client about, and a one-character `otherText` passed the old
 * `@IsNotEmpty()` just as easily as a real sentence did. Ten characters is the
 * smallest bar that rules out "a", "-", "ok" and an accidental space while
 * still accepting a genuinely terse Roman-Urdu report like "kaam adhura".
 *
 * The Flutter form enforces exactly the same rule client-side (see
 * ReportProblemPage) so the user is stopped before the request is sent — this
 * is the server's own guarantee, not a duplicate of the app's.
 */
export const COMPLAINT_DETAILS_MIN_LENGTH = 10;
export const COMPLAINT_DETAILS_MAX_LENGTH = 2000;

export class CreateBookingComplaintDto {
  @IsArray()
  @ArrayNotEmpty()
  @ArrayUnique()
  @IsEnum(ComplaintIssueType, { each: true })
  issueTypes!: ComplaintIssueType[];

  /**
   * What actually happened, in the reporter's own words. Required for EVERY
   * complaint, not only for OTHER: the issue-type checkboxes are a category,
   * never the report itself.
   *
   * Trimmed before validation so whitespace can never satisfy the minimum.
   */
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @MinLength(COMPLAINT_DETAILS_MIN_LENGTH, {
    message: `Please describe the problem in at least ${COMPLAINT_DETAILS_MIN_LENGTH} characters`,
  })
  @MaxLength(COMPLAINT_DETAILS_MAX_LENGTH)
  otherText!: string;
}
