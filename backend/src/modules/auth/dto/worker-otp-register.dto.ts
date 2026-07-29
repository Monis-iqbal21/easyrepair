import { IsString, IsUUID, Matches, MinLength } from 'class-validator';

export class WorkerOtpRegisterDto {
  @IsString()
  @MinLength(1, { message: 'fullName is required' })
  fullName: string;

  @IsString()
  @Matches(/^(\+92|0092|92|0)?[3][0-9]{9}$/, {
    message: 'phone must be a valid Pakistani mobile number',
  })
  phone: string;

  @IsString()
  @Matches(/^[0-9]{6}$/, { message: 'otp must be 6 digits' })
  otp: string;

  @IsString()
  @MinLength(8, { message: 'password must be at least 8 characters' })
  password: string;

  @IsUUID('4', { message: 'categoryId must be a valid main skill category' })
  categoryId: string;
}
