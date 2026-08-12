export interface ApiSuccessResponse<T = unknown> {
  success: true;
  data: T;
  message: string;
}

export interface ApiErrorResponse {
  success: false;
  error: string;
  message: string;
  statusCode: number;
  timestamp: string;
  path: string;
  /**
   * Seconds until the caller may safely retry — currently only set on
   * OTP_RESEND_TOO_SOON, so Flutter can restore its countdown from the
   * backend's own cooldown clock instead of guessing. Omitted everywhere
   * else.
   */
  retryAfterSeconds?: number;
}
