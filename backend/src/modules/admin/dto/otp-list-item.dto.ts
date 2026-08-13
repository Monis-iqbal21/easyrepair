import { AuthOtpPurpose } from '@prisma/client';

export type OtpLifecycleStatus = 'ACTIVE' | 'CONSUMED' | 'EXPIRED';
export type OtpSmsStatus = 'DISPATCHED' | 'NOT_SENT';

/**
 * One row of GET /admin/otp. Deliberately excludes otpHash and every
 * encryption field (otpCiphertext/otpCipherIv/otpCipherTag) — the plaintext
 * OTP is never part of the list response, only POST /admin/otp/:id/reveal.
 */
export class OtpListItemDto {
  id: string;
  phone: string;
  purpose: AuthOtpPurpose;
  createdAt: Date;
  expiresAt: Date;
  attempts: number;
  consumedAt: Date | null;
  /** Derived from consumedAt/expiresAt — not a stored column. */
  status: OtpLifecycleStatus;
  /** Whether SmsOtpService actually dispatched this code — "Dispatched" is
   *  provider acceptance, never a delivery guarantee. */
  smsStatus: OtpSmsStatus;
  requestIp: string | null;
  /** true only when status === 'ACTIVE' AND an encrypted copy exists. */
  revealable: boolean;
}

export class OtpPaginationMetaDto {
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}

export class PaginatedOtpDto {
  items: OtpListItemDto[];
  meta: OtpPaginationMetaDto;
}
