import { IsString, Matches } from 'class-validator';

/**
 * POST /auth/client/otp-login — Client LOGIN by one-time code.
 *
 * Authentication only: a phone and the code sent to it. There is deliberately
 * no `fullName` here. A name is registration data, and an endpoint that
 * accepts one on the login path is what forced the app to invent a value
 * (it was sending the phone number as the name) just to satisfy the contract.
 * Registration collects the name — see ClientPasswordRegisterDto.
 */
export class ClientOtpLoginDto {
  @IsString()
  @Matches(/^(\+92|0092|92|0)?[3][0-9]{9}$/, {
    message: 'phone must be a valid Pakistani mobile number',
  })
  phone: string;

  @IsString()
  @Matches(/^[0-9]{6}$/, { message: 'otp must be 6 digits' })
  otp: string;
}
