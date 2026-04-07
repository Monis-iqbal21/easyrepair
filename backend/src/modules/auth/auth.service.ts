import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  ForbiddenException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { v4 as uuidv4 } from 'uuid';
import { Role } from '@prisma/client';
import { AuthRepository } from './auth.repository';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { AuthResponseDto } from './dto/auth-response.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly authRepository: AuthRepository,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
  ) {}

  async register(dto: RegisterDto): Promise<AuthResponseDto> {
    const existing = await this.authRepository.findUserByPhone(dto.phone);
    if (existing) {
      throw new ConflictException('Phone number is already registered');
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);

    const user = await this.authRepository.createUserWithProfile({
      phone: dto.phone,
      passwordHash,
      firstName: dto.firstName,
      lastName: dto.lastName,
      role: dto.role as Role,
    });

    // New workers always start as PENDING verification
    const verificationStatus =
      (dto.role as Role) === Role.WORKER ? 'PENDING' : undefined;
    return this._buildAuthResponse(
      user.id,
      user.phone,
      user.role,
      dto.firstName,
      dto.lastName,
      verificationStatus,
    );
  }

  async login(dto: LoginDto): Promise<AuthResponseDto> {
    const user = await this.authRepository.findUserByPhone(dto.phone);
    if (!user) {
      throw new UnauthorizedException('Invalid phone number or password');
    }

    if (!user.isActive) {
      throw new ForbiddenException('Account is deactivated');
    }

    const passwordMatch = await bcrypt.compare(
      dto.password,
      user.passwordHash ?? '',
    );
    if (!passwordMatch) {
      throw new UnauthorizedException('Invalid phone number or password');
    }

    const profile = await this._getProfileName(user.id, user.role);

    return this._buildAuthResponse(
      user.id,
      user.phone,
      user.role,
      profile.firstName,
      profile.lastName,
      profile.verificationStatus,
    );
  }

  async refreshTokens(dto: RefreshTokenDto): Promise<AuthResponseDto> {
    const stored = await this.authRepository.findRefreshToken(dto.refreshToken);
    if (!stored || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const user = await this.authRepository.findUserById(stored.userId);
    if (!user || !user.isActive) {
      throw new UnauthorizedException('User not found or inactive');
    }

    await this.authRepository.deleteRefreshToken(dto.refreshToken);

    const profile = await this._getProfileName(user.id, user.role);

    return this._buildAuthResponse(
      user.id,
      user.phone,
      user.role,
      profile.firstName,
      profile.lastName,
      profile.verificationStatus,
    );
  }

  async logout(userId: string, refreshToken?: string): Promise<void> {
    if (refreshToken) {
      await this.authRepository
        .deleteRefreshToken(refreshToken)
        .catch(() => {});
    } else {
      await this.authRepository.deleteAllRefreshTokens(userId);
    }
  }

  async getMe(userId: string): Promise<AuthResponseDto['user']> {
    const user = await this.authRepository.findUserById(userId);
    if (!user) {
      throw new UnauthorizedException('User not found');
    }
    const profile = await this._getProfileName(user.id, user.role);
    return {
      id: user.id,
      phone: user.phone,
      role: user.role,
      firstName: profile.firstName,
      lastName: profile.lastName,
      verificationStatus: profile.verificationStatus,
    };
  }

  private async _getProfileName(
    userId: string,
    role: Role,
  ): Promise<{
    firstName: string;
    lastName: string;
    verificationStatus?: string;
  }> {
    if (role === Role.CLIENT) {
      const p = await this.authRepository.findClientProfile(userId);
      return p ?? { firstName: '', lastName: '' };
    } else {
      const p = await this.authRepository.findWorkerProfile(userId);
      if (!p) return { firstName: '', lastName: '' };
      return {
        firstName: p.firstName,
        lastName: p.lastName,
        verificationStatus: p.verificationStatus,
      };
    }
  }

  private async _buildAuthResponse(
    userId: string,
    phone: string,
    role: Role,
    firstName: string,
    lastName: string,
    verificationStatus?: string,
  ): Promise<AuthResponseDto> {
    const accessToken = this.jwtService.sign(
      { sub: userId, phone, role } as object,
      {
        expiresIn: this.config.getOrThrow<string>('jwt.accessExpires') as
          | `${number}${'s' | 'm' | 'h' | 'd' | 'w' | 'y'}`
          | number,
      },
    );

    const refreshToken = uuidv4();
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);

    await this.authRepository.createRefreshToken(
      userId,
      refreshToken,
      expiresAt,
    );

    return {
      accessToken,
      refreshToken,
      user: {
        id: userId,
        phone,
        role,
        firstName,
        lastName,
        verificationStatus,
      },
    };
  }
}
