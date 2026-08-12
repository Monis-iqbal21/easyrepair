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
}

export class AuthResponseDto {
  accessToken: string;
  refreshToken: string;
  user: AuthUserDto;
}
