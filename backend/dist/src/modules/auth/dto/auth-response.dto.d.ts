export declare class AuthUserDto {
    id: string;
    phone: string;
    role: string;
    firstName: string;
    lastName: string;
    verificationStatus?: string;
}
export declare class AuthResponseDto {
    accessToken: string;
    refreshToken: string;
    user: AuthUserDto;
}
