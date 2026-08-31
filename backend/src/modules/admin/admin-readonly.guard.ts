import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { createHash, timingSafeEqual } from 'crypto';
import { Request } from 'express';
import { RedisService } from '../../redis/redis.service';
import {
  ADMIN_READONLY_SCOPES_KEY,
  AdminReadonlyScope,
} from './admin-readonly.constants';

export interface AdminReadonlyRequest extends Request {
  adminReadonlyCredential?: {
    clientId: string;
    scopes: AdminReadonlyScope[];
  };
}

interface LocalRateWindow {
  count: number;
  expiresAt: number;
}

/**
 * Authenticates one deliberately narrow machine credential. The raw key is
 * never stored by the application: deployment configuration contains only a
 * SHA-256 digest, an expiry timestamp, and an explicit scope allowlist.
 */
@Injectable()
export class AdminReadonlyGuard implements CanActivate {
  private readonly logger = new Logger(AdminReadonlyGuard.name);
  private readonly localRateWindows = new Map<string, LocalRateWindow>();

  constructor(
    private readonly reflector: Reflector,
    private readonly config: ConfigService,
    private readonly redis: RedisService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AdminReadonlyRequest>();
    const requiredScopes =
      this.reflector.getAllAndOverride<AdminReadonlyScope[]>(
        ADMIN_READONLY_SCOPES_KEY,
        [context.getHandler(), context.getClass()],
      ) ?? [];
    const clientId = this.cleanLogValue(
      this.config.get<string>('adminReadonly.clientId') ?? 'admin-readonly',
    );

    const token = this.extractBearerToken(request.headers.authorization);
    const configuredDigest = (
      this.config.get<string>('adminReadonly.apiKeySha256') ?? ''
    ).trim();
    if (!token || !this.matchesDigest(token, configuredDigest)) {
      this.logDenied(request, clientId, 'invalid_credential');
      throw new UnauthorizedException('Invalid read-only API credential');
    }

    const expiresAt = this.config.get<string>('adminReadonly.expiresAt');
    const expiryTime = expiresAt ? Date.parse(expiresAt) : Number.NaN;
    if (Number.isNaN(expiryTime) || expiryTime <= Date.now()) {
      this.logDenied(request, clientId, 'expired_credential');
      throw new UnauthorizedException('Read-only API credential expired');
    }

    const grantedScopes = this.configuredScopes();
    if (!requiredScopes.every((scope) => grantedScopes.includes(scope))) {
      this.logDenied(request, clientId, 'insufficient_scope');
      throw new ForbiddenException('Read-only API scope not granted');
    }

    await this.enforceRateLimit(clientId);
    request.adminReadonlyCredential = { clientId, scopes: grantedScopes };
    return true;
  }

  private extractBearerToken(header: string | undefined): string | null {
    if (!header) return null;
    const match = /^Bearer\s+([^\s]+)$/i.exec(header.trim());
    if (!match || match[1].length < 32) return null;
    return match[1];
  }

  private matchesDigest(token: string, configuredDigest: string): boolean {
    if (!/^[a-f\d]{64}$/i.test(configuredDigest)) return false;
    const presented = Buffer.from(
      createHash('sha256').update(token, 'utf8').digest('hex'),
      'hex',
    );
    const expected = Buffer.from(configuredDigest, 'hex');
    return timingSafeEqual(presented, expected);
  }

  private configuredScopes(): AdminReadonlyScope[] {
    const raw = this.config.get<string>('adminReadonly.scopes') ?? '';
    return raw
      .split(',')
      .map((scope) => scope.trim())
      .filter((scope): scope is AdminReadonlyScope => scope.length > 0);
  }

  private async enforceRateLimit(clientId: string): Promise<void> {
    const configured = this.config.get<number>(
      'adminReadonly.rateLimitPerMinute',
    );
    const limit =
      Number.isInteger(configured) && (configured as number) > 0
        ? (configured as number)
        : 120;
    const now = Date.now();
    const window = Math.floor(now / 60_000);
    const clientHash = createHash('sha256')
      .update(clientId, 'utf8')
      .digest('hex')
      .slice(0, 24);
    const key = `admin-readonly:rate:${clientHash}:${window}`;

    let count: number;
    const redisClient = this.redis.getClient();
    if (redisClient) {
      try {
        const result = await redisClient
          .multi()
          .incr(key)
          .expire(key, 120)
          .exec();
        count = Number(result?.[0]?.[1] ?? 0);
      } catch {
        count = this.incrementLocalWindow(key, now);
      }
    } else {
      count = this.incrementLocalWindow(key, now);
    }

    if (count > limit) {
      this.logger.warn(
        `admin_readonly denied client=${this.cleanLogValue(clientId)} reason=rate_limit_exceeded`,
      );
      throw new HttpException(
        'Read-only API rate limit exceeded',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  private incrementLocalWindow(key: string, now: number): number {
    const existing = this.localRateWindows.get(key);
    if (!existing || existing.expiresAt <= now) {
      this.localRateWindows.set(key, { count: 1, expiresAt: now + 120_000 });
      this.sweepLocalWindows(now);
      return 1;
    }
    existing.count += 1;
    return existing.count;
  }

  private sweepLocalWindows(now: number): void {
    if (this.localRateWindows.size < 100) return;
    for (const [key, value] of this.localRateWindows) {
      if (value.expiresAt <= now) this.localRateWindows.delete(key);
    }
  }

  private logDenied(
    request: AdminReadonlyRequest,
    clientId: string,
    reason: string,
  ): void {
    this.logger.warn(
      `admin_readonly denied client=${clientId} method=${request.method} path=${this.cleanLogValue(request.path)} ip=${this.cleanLogValue(request.ip)} reason=${reason}`,
    );
  }

  private cleanLogValue(value: string | undefined): string {
    return (value ?? '-').replace(/[^\x20-\x7E]/g, '').slice(0, 160);
  }
}
