import type { RedisOptions } from 'ioredis';

export interface SafeRedisEndpoint {
  protocol: 'redis' | 'rediss';
  hostname: string;
  port: number;
  tlsEnabled: boolean;
}

function parseUrl(redisUrl: string): URL {
  const parsed = new URL(redisUrl);
  if (parsed.protocol !== 'redis:' && parsed.protocol !== 'rediss:') {
    throw new Error('REDIS_URL protocol must be redis:// or rediss://');
  }
  if (!parsed.hostname) throw new Error('REDIS_URL hostname is missing');
  return parsed;
}

/** Returns connection options without ever logging or returning the full URL. */
export function createRedisOptions(redisUrl: string): RedisOptions {
  const parsed = parseUrl(redisUrl);
  const databasePath = parsed.pathname.replace(/^\//, '');
  const database = databasePath === '' ? 0 : Number(databasePath);
  if (!Number.isInteger(database) || database < 0) {
    throw new Error('REDIS_URL database must be a non-negative integer');
  }

  return {
    host: parsed.hostname,
    port: parsed.port ? Number(parsed.port) : 6379,
    db: database,
    ...(parsed.username
      ? { username: decodeURIComponent(parsed.username) }
      : {}),
    ...(parsed.password
      ? { password: decodeURIComponent(parsed.password) }
      : {}),
    // Bull 4.x discards the rediss scheme when it parses a URL. Supplying an
    // options object with TLS explicit keeps every Bull client encrypted.
    ...(parsed.protocol === 'rediss:'
      ? { tls: { servername: parsed.hostname } }
      : {}),
  };
}

export function describeRedisEndpoint(redisUrl: string): SafeRedisEndpoint {
  const parsed = parseUrl(redisUrl);
  return {
    protocol: parsed.protocol.slice(0, -1) as 'redis' | 'rediss',
    hostname: parsed.hostname,
    port: parsed.port ? Number(parsed.port) : 6379,
    tlsEnabled: parsed.protocol === 'rediss:',
  };
}

export function formatRedisEndpoint(endpoint: SafeRedisEndpoint): string {
  return `protocol=${endpoint.protocol} hostname=${endpoint.hostname} port=${endpoint.port} tls=${endpoint.tlsEnabled ? 'yes' : 'no'}`;
}
