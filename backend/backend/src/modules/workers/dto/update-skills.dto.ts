import { IsArray, IsUUID, ArrayMinSize } from 'class-validator';

export class UpdateSkillsDto {
  @IsArray()
  @ArrayMinSize(1)
  @IsUUID('4', { each: true })
  categoryIds: string[];
}
