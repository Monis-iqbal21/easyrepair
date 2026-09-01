import { IsIn, IsOptional, IsString, MinLength } from 'class-validator';

export class SaveFcmTokenDto {
  @IsString()
  @MinLength(1)
  token: string;

  /** Optional for backward compatibility with already-installed clients. */
  @IsOptional()
  @IsString()
  @IsIn(['en', 'ur', 'ur_Latn'])
  locale?: string;
}
