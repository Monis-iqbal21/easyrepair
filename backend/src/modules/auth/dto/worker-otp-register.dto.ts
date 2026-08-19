import {
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MinLength,
  ValidateIf,
} from 'class-validator';

export class WorkerOtpRegisterDto {
  @IsString()
  @MinLength(1, { message: 'fullName is required' })
  fullName: string;

  @IsString()
  @Matches(/^(\+92|0092|92|0)?[3][0-9]{9}$/, {
    message: 'phone must be a valid Pakistani mobile number',
  })
  phone: string;

  /**
   * Proof that the number belongs to the caller. Exactly one of [otp] and
   * [registrationToken] must be present:
   *
   *  * [registrationToken] is what the 4-step Ustaad registration sends — the
   *    code was already verified and consumed at Step 2, so it cannot expire
   *    while the Ustaad fills in their profile.
   *  * [otp] is the original single-call path, still accepted so an older app
   *    build keeps working.
   */
  @ValidateIf((dto: WorkerOtpRegisterDto) => dto.registrationToken === undefined)
  @IsString()
  @Matches(/^[0-9]{6}$/, { message: 'otp must be 6 digits' })
  otp?: string;

  @IsOptional()
  @IsString()
  @MinLength(1, { message: 'registrationToken must not be empty' })
  registrationToken?: string;

  @IsString()
  @MinLength(8, { message: 'password must be at least 8 characters' })
  password: string;

  @IsUUID('4', { message: 'categoryId must be a valid main skill category' })
  categoryId: string;
}
