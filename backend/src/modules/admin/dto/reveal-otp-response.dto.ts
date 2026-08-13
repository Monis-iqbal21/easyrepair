/**
 * POST /admin/otp/:id/reveal response. Only these two fields — no id,
 * phone, purpose, or anything else, to keep the sensitive response body as
 * small/scoped as possible.
 */
export class RevealOtpResponseDto {
  otp: string;
  expiresAt: Date;
}
