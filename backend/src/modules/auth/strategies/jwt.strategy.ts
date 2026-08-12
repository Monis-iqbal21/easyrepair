import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { TokenPayload } from '../entities/token-payload.entity';
import { Role } from '../../../common/enums/role.enum';
import { PrismaService } from '../../../prisma/prisma.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.getOrThrow<string>('jwt.secret'),
    });
  }

  /**
   * A deleted/deactivated account must immediately lose authenticated API
   * access — not just on its next token refresh — since the access token
   * itself stays cryptographically valid for its full lifetime otherwise.
   * This lightweight lookup (a few indexed-PK columns) runs on every
   * authenticated request.
   *
   * `accountStatus` is fetched here (one query, no extra DB round trip) and
   * attached to the validated user so JwtAuthGuard can enforce Client
   * suspension — but this method deliberately never REJECTS on it. Worker
   * suspension and Client AccountStatus.SUSPENDED both stay soft here so
   * that GET /auth/me and POST /auth/logout keep working for a suspended
   * account (see JwtAuthGuard + BypassClientSuspension); JwtAuthGuard is
   * where the actual 403 for normal business endpoints happens.
   */
  async validate(payload: TokenPayload) {
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: { isActive: true, deletedAt: true, accountStatus: true },
    });
    if (!user || !user.isActive || user.deletedAt !== null) {
      throw new UnauthorizedException();
    }
    return {
      id: payload.sub,
      phone: payload.phone,
      role: payload.role,
      accountStatus: user.accountStatus,
    };
  }
}
