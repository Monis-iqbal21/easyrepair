import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: Redis | null = null;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    const url = this.configService.get<string>('redis.url');
    if (!url) {
      this.logger.warn(
        'REDIS_URL not set — Redis features will be unavailable',
      );
      return;
    }
    try {
      this.client = new Redis(url, {
        lazyConnect: false,
        enableOfflineQueue: false,
      });
      this.client.on('error', (err) =>
        this.logger.warn(`Redis error: ${err.message}`),
      );
      this.logger.log('Redis client created');
    } catch (err: any) {
      this.logger.warn(
        `Redis init failed — Redis features will be unavailable: ${err.message}`,
      );
    }
  }

  async onModuleDestroy() {
    if (this.client) await this.client.quit();
  }

  getClient(): Redis | null {
    return this.client;
  }

  async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
    if (!this.client) return;
    if (ttlSeconds) {
      await this.client.set(key, value, 'EX', ttlSeconds);
    } else {
      await this.client.set(key, value);
    }
  }

  async get(key: string): Promise<string | null> {
    if (!this.client) return null;
    return this.client.get(key);
  }

  async del(key: string): Promise<void> {
    if (!this.client) return;
    await this.client.del(key);
  }

  async exists(key: string): Promise<boolean> {
    if (!this.client) return false;
    const count = await this.client.exists(key);
    return count > 0;
  }

  /**
   * Atomic "claim this key for [ttlSeconds]" — returns true for the first
   * caller and false for everyone else until it expires. Used as a per-worker
   * cooldown so a frequent location heartbeat can't trigger re-matching on
   * every ping.
   *
   * When Redis is unavailable the naive fallback would be to return true
   * every time, which removes the throttle entirely — exactly when load is
   * least likely to be survivable. So it degrades to an in-process TTL map
   * with identical semantics instead (correct for a single instance, and
   * still strictly better than no throttle for several).
   */
  async tryAcquire(key: string, ttlSeconds: number): Promise<boolean> {
    if (!this.client) return this._tryAcquireInProcess(key, ttlSeconds);
    try {
      const res = await this.client.set(key, '1', 'EX', ttlSeconds, 'NX');
      return res === 'OK';
    } catch {
      return this._tryAcquireInProcess(key, ttlSeconds);
    }
  }

  private readonly _localCooldowns = new Map<string, number>();

  private _tryAcquireInProcess(key: string, ttlSeconds: number): boolean {
    const now = Date.now();
    const expiresAt = this._localCooldowns.get(key);
    if (expiresAt !== undefined && expiresAt > now) return false;
    this._localCooldowns.set(key, now + ttlSeconds * 1000);
    // Opportunistic sweep so the map can't grow without bound.
    if (this._localCooldowns.size > 5000) {
      for (const [k, exp] of this._localCooldowns) {
        if (exp <= now) this._localCooldowns.delete(k);
      }
    }
    return true;
  }

  async setJson(
    key: string,
    value: object,
    ttlSeconds?: number,
  ): Promise<void> {
    await this.set(key, JSON.stringify(value), ttlSeconds);
  }

  async getJson<T>(key: string): Promise<T | null> {
    const raw = await this.get(key);
    if (!raw) return null;
    return JSON.parse(raw) as T;
  }
}
