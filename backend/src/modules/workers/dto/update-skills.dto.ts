import {
  IsArray,
  IsUUID,
  ArrayMinSize,
  ArrayMaxSize,
  IsInt,
  IsOptional,
  Min,
} from 'class-validator';

/**
 * A worker may have exactly one main skill/category for now (product rule:
 * start with one strongest skill; multi-skill may return post-approval
 * later). ArrayMaxSize(1) is defense-in-depth — WorkersService.updateSkills
 * throws the user-facing "Only one main skill is allowed." message before
 * this would ever surface.
 */
export class UpdateSkillsDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(1)
  @IsUUID('4', { each: true })
  categoryIds: string[];

  /**
   * Years of experience in the main skill. Reuses the existing
   * WorkerSkill.yearsExperience column (previously never written by any
   * endpoint) rather than adding a duplicate field on WorkerProfile — this
   * is also the "Experience in Years" field on the profile-completion form.
   */
  @IsOptional()
  @IsInt()
  @Min(0)
  yearsExperience?: number;
}
