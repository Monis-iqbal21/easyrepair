import { SetMetadata } from '@nestjs/common';

export const BYPASS_CLIENT_SUSPENSION_KEY = 'bypassClientSuspension';

/**
 * Marks an endpoint as reachable by an authenticated CLIENT whose
 * AccountStatus is SUSPENDED — the minimal whitelist a restricted account
 * needs to identify itself and clean up its session (GET /auth/me,
 * POST /auth/logout). Never applies to WORKER/ADMIN requests, which
 * JwtAuthGuard's suspension check already ignores entirely regardless of
 * this decorator.
 */
export const BypassClientSuspension = () =>
  SetMetadata(BYPASS_CLIENT_SUSPENSION_KEY, true);
