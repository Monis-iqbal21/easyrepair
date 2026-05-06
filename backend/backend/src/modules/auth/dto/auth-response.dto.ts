export class AuthUserDto {
  id: string;
  phone: string;
  role: string;
  firstName: string;
  lastName: string;
  /** Only present for WORKER accounts. Values: 'PENDING' | 'VERIFIED' | 'REJECTED' */
  verificationStatus?: string;
}

export class AuthResponseDto {
  accessToken: string;
  refreshToken: string;
  user: AuthUserDto;
}
