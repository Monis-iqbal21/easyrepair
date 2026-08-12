export class AuthUserDto {
  id: string;
  phone: string;
  role: string;
  firstName: string;
  lastName: string;
  /** Only present for WORKER accounts. Values: 'PENDING' | 'VERIFIED' | 'REJECTED' */
  verificationStatus?: string;
  /**
   * Only present for WORKER accounts. Values: 'ACTIVE' | 'INACTIVE' | 'SUSPENDED'.
   * The app's central routing gate reads this on every login/session-restore
   * to decide whether the Worker app is reachable — see
   * `resolveWorkerSuspendedRedirect` in the Flutter router.
   */
  workerStatus?: string;
  /**
   * Values: 'ACTIVE' | 'SUSPENDED'. Only meaningfully restrictive for CLIENT
   * accounts — the app's central routing gate reads this on every
   * login/session-restore to decide whether the Client app is reachable.
   * Always present (defaults to 'ACTIVE'), unlike workerStatus.
   */
  accountStatus: string;
}

export class AuthResponseDto {
  accessToken: string;
  refreshToken: string;
  user: AuthUserDto;
}
