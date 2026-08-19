import { IsOptional, IsString, Matches, MinLength } from 'class-validator';

export class ClientPasswordRegisterDto {
  @IsString()
  @MinLength(1, { message: 'fullName is required' })
  fullName: string;

  @IsString()
  @Matches(/^(\+92|0092|92|0)?[3][0-9]{9}$/, {
    message: 'phone must be a valid Pakistani mobile number',
  })
  phone: string;

  @IsString()
  @MinLength(8, { message: 'password must be at least 8 characters' })
  password: string;

  /**
   * The code sent to `phone`. Supplying it makes registration atomic: the
   * code is verified before anything is created, and the new account starts
   * with its phone already verified.
   *
   * Optional so an older app build that registers without one keeps its
   * existing (unverified) behaviour rather than breaking.
   */
  @IsOptional()
  @IsString()
  @Matches(/^[0-9]{6}$/, { message: 'otp must be 6 digits' })
  otp?: string;
}
