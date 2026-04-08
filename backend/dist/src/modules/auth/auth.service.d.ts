import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { AuthRepository } from './auth.repository';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { AuthResponseDto } from './dto/auth-response.dto';
export declare class AuthService {
    private readonly authRepository;
    private readonly jwtService;
    private readonly config;
    constructor(authRepository: AuthRepository, jwtService: JwtService, config: ConfigService);
    register(dto: RegisterDto): Promise<AuthResponseDto>;
    login(dto: LoginDto): Promise<AuthResponseDto>;
    refreshTokens(dto: RefreshTokenDto): Promise<AuthResponseDto>;
    logout(userId: string, refreshToken?: string): Promise<void>;
    getMe(userId: string): Promise<AuthResponseDto['user']>;
    private _getProfileName;
    private _buildAuthResponse;
    saveFcmToken(userId: string, token: string): Promise<void>;
}
