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
 * PATCH /admin/workers/:id/skills — mirrors the worker-facing UpdateSkillsDto
 * (workers/dto/update-skills.dto.ts): exactly one main skill for now, same
 * product rule, so admin edits can never put a profile in a state the
 * worker's own app doesn't already support.
 */
export class UpdateWorkerSkillsDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(1)
  @IsUUID('4', { each: true })
  categoryIds: string[];

  @IsOptional()
  @IsInt()
  @Min(0)
  yearsExperience?: number;
}
