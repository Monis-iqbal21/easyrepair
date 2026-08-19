import { IsString, Matches } from 'class-validator';

/**
 * POST /auth/worker/otp-verify — Step 2 of Ustaad registration.
 *
 * Verifies and consumes the registration code. Nothing is created; the
 * response is a short-lived token authorising the rest of the registration.
 */
export class WorkerOtpVerifyDto {
  @IsString()
  @Matches(/^(\+92|0092|92|0)?[3][0-9]{9}$/, {
    message: 'phone must be a valid Pakistani mobile number',
  })
  phone: string;

  @IsString()
  @Matches(/^[0-9]{6}$/, { message: 'otp must be 6 digits' })
  otp: string;
}
