import { IsEnum, IsString, Matches } from 'class-validator';
import { AuthOtpPurpose } from '@prisma/client';

export class RequestOtpDto {
  @IsString()
  @Matches(/^(\+92|0092|92|0)?[3][0-9]{9}$/, {
    message: 'phone must be a valid Pakistani mobile number',
  })
  phone: string;

  @IsEnum(AuthOtpPurpose, { message: 'purpose must be a valid OTP purpose' })
  purpose: AuthOtpPurpose;
}
