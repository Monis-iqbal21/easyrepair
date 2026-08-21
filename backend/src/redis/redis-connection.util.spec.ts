import {
  createRedisOptions,
  describeRedisEndpoint,
  formatRedisEndpoint,
} from './redis-connection.util';

describe('Redis connection configuration', () => {
  it('enables verified TLS for a rediss URL without exposing credentials', () => {
    const url = 'rediss://default:p%40ssword@private-db.example.com:25061/2';

    expect(createRedisOptions(url)).toEqual({
      host: 'private-db.example.com',
      port: 25061,
      db: 2,
      username: 'default',
      password: 'p@ssword',
      tls: { servername: 'private-db.example.com' },
    });
    expect(formatRedisEndpoint(describeRedisEndpoint(url))).toBe(
      'protocol=rediss hostname=private-db.example.com port=25061 tls=yes',
    );
  });

  it('keeps local redis URLs non-TLS', () => {
    expect(createRedisOptions('redis://localhost:6379')).toEqual({
      host: 'localhost',
      port: 6379,
      db: 0,
    });
  });

  it('rejects unsupported protocols and invalid database paths', () => {
    expect(() => createRedisOptions('http://localhost:6379')).toThrow(
      'protocol must be redis:// or rediss://',
    );
    expect(() => createRedisOptions('redis://localhost/not-a-db')).toThrow(
      'database must be a non-negative integer',
    );
  });
});
