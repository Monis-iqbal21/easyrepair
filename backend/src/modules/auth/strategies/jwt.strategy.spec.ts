import { UnauthorizedException } from '@nestjs/common';
import { JwtStrategy } from './jwt.strategy';

/**
 * A deleted/deactivated account's access token stays cryptographically
 * valid for its full lifetime unless something checks account state on
 * every authenticated request — this is that check. Account-status
 * (Worker SUSPENDED, Client AccountStatus.SUSPENDED) is deliberately NOT
 * enforced here; those remain app-level routing gates, same as before this
 * chunk.
 */
describe('JwtStrategy.validate', () => {
  let prisma: any;
  let config: any;
  let strategy: JwtStrategy;

  const PAYLOAD = { sub: 'user-1', phone: '+923001234567', role: 'CLIENT' };

  beforeEach(() => {
    prisma = { user: { findUnique: jest.fn() } };
    config = { getOrThrow: jest.fn().mockReturnValue('test-secret') };
    strategy = new JwtStrategy(config, prisma);
  });

  it('accepts an active, non-deleted account', async () => {
    prisma.user.findUnique.mockResolvedValue({
      isActive: true,
      deletedAt: null,
    });

    const result = await strategy.validate(PAYLOAD as any);

    expect(result).toEqual({
      id: 'user-1',
      phone: '+923001234567',
      role: 'CLIENT',
    });
  });

  it('rejects a soft-deleted account even with a still-valid access token', async () => {
    prisma.user.findUnique.mockResolvedValue({
      isActive: false,
      deletedAt: new Date(),
    });

    await expect(strategy.validate(PAYLOAD as any)).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('rejects a deactivated (isActive: false) account', async () => {
    prisma.user.findUnique.mockResolvedValue({
      isActive: false,
      deletedAt: null,
    });

    await expect(strategy.validate(PAYLOAD as any)).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('rejects a token whose user row no longer exists', async () => {
    prisma.user.findUnique.mockResolvedValue(null);

    await expect(strategy.validate(PAYLOAD as any)).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('a SUSPENDED Worker still authenticates — suspension is an app-level gate, not an API block', async () => {
    prisma.user.findUnique.mockResolvedValue({
      isActive: true,
      deletedAt: null,
    });

    await expect(
      strategy.validate({ ...PAYLOAD, role: 'WORKER' } as any),
    ).resolves.toEqual({
      id: 'user-1',
      phone: '+923001234567',
      role: 'WORKER',
    });
  });
});
