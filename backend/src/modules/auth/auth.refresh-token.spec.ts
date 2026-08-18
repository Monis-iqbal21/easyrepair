import { Role } from '@prisma/client';
import { AuthService } from './auth.service';

/**
 * Covers the refresh-token lifecycle: rotation, config-driven expiry, and
 * the grace-window recovery for a client that crashed/was killed between
 * the backend committing a rotation and Flutter persisting the new pair
 * locally (see AuthService.refreshTokens).
 */
describe('AuthService — refresh token rotation', () => {
  let repository: any;
  let jwtService: any;
  let config: any;
  let service: AuthService;

  const USER = {
    id: 'user-1',
    phone: '+923001234567',
    role: Role.CLIENT,
    isActive: true,
    deletedAt: null,
    passwordHash: null,
  };

  function storedToken(overrides: Partial<any> = {}) {
    return {
      id: 'rt-1',
      token: 'old-refresh-token',
      userId: USER.id,
      expiresAt: new Date(Date.now() + 60 * 24 * 60 * 60 * 1000),
      createdAt: new Date(),
      replacedByToken: null,
      supersededAt: null,
      ...overrides,
    };
  }

  beforeEach(() => {
    repository = {
      findRefreshToken: jest.fn(),
      rotateRefreshToken: jest.fn().mockResolvedValue(undefined),
      deleteRefreshToken: jest.fn().mockResolvedValue(undefined),
      deleteAllRefreshTokens: jest.fn().mockResolvedValue(undefined),
      createRefreshToken: jest.fn().mockResolvedValue(undefined),
      findUserById: jest.fn().mockResolvedValue(USER),
      findClientProfile: jest
        .fn()
        .mockResolvedValue({ firstName: 'Ali', lastName: 'Khan' }),
      findWorkerProfile: jest.fn().mockResolvedValue({
        firstName: 'Ali',
        lastName: 'Khan',
        verificationStatus: 'VERIFIED',
      }),
    };
    jwtService = { sign: jest.fn().mockReturnValue('signed.jwt.token') };
    config = {
      // jwt.accessExpires -> '15m', jwt.refreshExpires -> '30d' by default;
      // individual tests override via mockImplementation for a specific key.
      getOrThrow: jest.fn((key: string) => {
        if (key === 'jwt.accessExpires') return '15m';
        if (key === 'jwt.refreshExpires') return '30d';
        return 'unused';
      }),
      get: jest.fn().mockReturnValue(undefined),
    };
    const chatService = { ensureSupportConversation: jest.fn() };
    service = new AuthService(
      repository,
      jwtService,
      config,
      {} as any,
      {} as any,
      chatService as any,
      { handleWorkerLogout: jest.fn().mockResolvedValue(undefined) } as any,
    );
  });

  describe('normal rotation', () => {
    it('rotates via the transactional repository method, never plain delete+create', async () => {
      repository.findRefreshToken.mockResolvedValue(storedToken());

      const result = await service.refreshTokens({
        refreshToken: 'old-refresh-token',
      } as any);

      expect(repository.rotateRefreshToken).toHaveBeenCalledWith(
        'old-refresh-token',
        expect.any(String),
        USER.id,
        expect.any(Date),
      );
      expect(repository.deleteRefreshToken).not.toHaveBeenCalled();
      expect(repository.createRefreshToken).not.toHaveBeenCalled();
      expect(result.accessToken).toBe('signed.jwt.token');
      expect(result.refreshToken).toEqual(expect.any(String));
      expect(result.refreshToken).not.toBe('old-refresh-token');
    });

    it('computes the new refresh token expiry from JWT_REFRESH_EXPIRES, not a hardcoded 30 days', async () => {
      repository.findRefreshToken.mockResolvedValue(storedToken());
      config.getOrThrow.mockImplementation((key: string) => {
        if (key === 'jwt.accessExpires') return '15m';
        if (key === 'jwt.refreshExpires') return '7d';
        return 'unused';
      });

      const before = Date.now();
      await service.refreshTokens({ refreshToken: 'old-refresh-token' } as any);

      const [, , , expiresAt] = repository.rotateRefreshToken.mock.calls[0];
      const deltaMs = (expiresAt as Date).getTime() - before;
      // ~7 days, generous tolerance for test execution time.
      expect(deltaMs).toBeGreaterThan(6.9 * 24 * 60 * 60 * 1000);
      expect(deltaMs).toBeLessThan(7.1 * 24 * 60 * 60 * 1000);
    });

    it('an unknown token is a definite rejection', async () => {
      repository.findRefreshToken.mockResolvedValue(null);

      await expect(
        service.refreshTokens({ refreshToken: 'nonexistent' } as any),
      ).rejects.toMatchObject({ status: 401 });
    });

    it('a naturally expired (never-rotated) token is a definite rejection', async () => {
      repository.findRefreshToken.mockResolvedValue(
        storedToken({ expiresAt: new Date(Date.now() - 1000) }),
      );

      await expect(
        service.refreshTokens({ refreshToken: 'old-refresh-token' } as any),
      ).rejects.toMatchObject({ status: 401 });
      expect(repository.rotateRefreshToken).not.toHaveBeenCalled();
    });

    it('an inactive account is rejected even with a structurally valid token', async () => {
      repository.findRefreshToken.mockResolvedValue(storedToken());
      repository.findUserById.mockResolvedValue({ ...USER, isActive: false });

      await expect(
        service.refreshTokens({ refreshToken: 'old-refresh-token' } as any),
      ).rejects.toMatchObject({ status: 401 });
    });
  });

  describe('grace-window recovery (crash-safe rotation)', () => {
    it('re-resolves to the existing replacement when the old token is presented again within the grace window', async () => {
      repository.findRefreshToken.mockImplementation((token: string) => {
        if (token === 'old-refresh-token') {
          return Promise.resolve(
            storedToken({
              replacedByToken: 'new-refresh-token',
              supersededAt: new Date(Date.now() - 5000), // 5s ago
            }),
          );
        }
        if (token === 'new-refresh-token') {
          return Promise.resolve(
            storedToken({
              token: 'new-refresh-token',
              replacedByToken: null,
              supersededAt: null,
            }),
          );
        }
        return Promise.resolve(null);
      });

      const result = await service.refreshTokens({
        refreshToken: 'old-refresh-token',
      } as any);

      // Recovers the SAME replacement token — never rotates again from a
      // stale presentation.
      expect(result.refreshToken).toBe('new-refresh-token');
      expect(result.accessToken).toBe('signed.jwt.token');
      expect(repository.rotateRefreshToken).not.toHaveBeenCalled();
    });

    it('rejects the old token once the grace window has passed', async () => {
      repository.findRefreshToken.mockResolvedValue(
        storedToken({
          replacedByToken: 'new-refresh-token',
          supersededAt: new Date(Date.now() - 5 * 60 * 1000), // 5 minutes ago
        }),
      );

      await expect(
        service.refreshTokens({ refreshToken: 'old-refresh-token' } as any),
      ).rejects.toMatchObject({ status: 401 });
    });

    it('rejects if the replacement token itself has since expired', async () => {
      repository.findRefreshToken.mockImplementation((token: string) => {
        if (token === 'old-refresh-token') {
          return Promise.resolve(
            storedToken({
              replacedByToken: 'new-refresh-token',
              supersededAt: new Date(Date.now() - 1000),
            }),
          );
        }
        return Promise.resolve(
          storedToken({
            token: 'new-refresh-token',
            expiresAt: new Date(Date.now() - 1000),
          }),
        );
      });

      await expect(
        service.refreshTokens({ refreshToken: 'old-refresh-token' } as any),
      ).rejects.toMatchObject({ status: 401 });
    });

    it('never issues a second-generation refresh token from a grace-window retry (no unbounded chain)', async () => {
      repository.findRefreshToken.mockImplementation((token: string) => {
        if (token === 'old-refresh-token') {
          return Promise.resolve(
            storedToken({
              replacedByToken: 'new-refresh-token',
              supersededAt: new Date(Date.now() - 1000),
            }),
          );
        }
        return Promise.resolve(
          storedToken({ token: 'new-refresh-token' }),
        );
      });

      await service.refreshTokens({ refreshToken: 'old-refresh-token' } as any);

      expect(repository.rotateRefreshToken).not.toHaveBeenCalled();
      expect(repository.createRefreshToken).not.toHaveBeenCalled();
    });
  });

  /**
   * Pins the absolute requirement: an active user is never logged out merely
   * because rotation occurs. Every successful refresh extends the refresh
   * token's expiry from the moment of that refresh (sliding window), so
   * JWT_REFRESH_EXPIRES (30d) behaves as an inactivity timeout, not a fixed
   * session lifetime — a user who keeps using the app stays logged in
   * indefinitely, and only genuine inactivity (or logout/disable/revoke/
   * reinstall) ever forces a fresh login.
   */
  describe('sliding expiry — 30d is an inactivity timeout, not a session cap', () => {
    it(
      'repeated app usage across more than 30 calendar days remains logged in, ' +
        'because each refresh extends expiry another 30 days from the moment it happens',
      async () => {
        // Models a user who opens the app roughly every 10 days for 40 days
        // straight — well past the 30-day window measured from their very
        // first login — and never once has a gap long enough to expire.
        let currentToken = 'gen-0-refresh-token';
        let now = Date.now();

        repository.findRefreshToken.mockImplementation((token: string) =>
          Promise.resolve(
            token === currentToken
              ? storedToken({
                  token: currentToken,
                  // Expiry set by whichever step last rotated it.
                  expiresAt: new Date(now + 30 * 24 * 60 * 60 * 1000),
                })
              : null,
          ),
        );

        const dayMs = 24 * 60 * 60 * 1000;
        // `jest.useFakeTimers` (unlike a bare `jest.spyOn(Date, 'now')`)
        // replaces the engine's clock wholesale, so both `Date.now()` (used
        // by `_refreshTokenExpiresAt`) and bare `new Date()` (used by the
        // `stored.expiresAt < new Date()` liveness check) advance together —
        // required here since both are load-bearing for this assertion.
        jest.useFakeTimers({ now });
        try {
          const usageGapDays = [10, 10, 10, 10]; // 40 days total elapsed
          for (const gapDays of usageGapDays) {
            now += gapDays * dayMs;
            jest.setSystemTime(now);

            repository.rotateRefreshToken.mockImplementationOnce(
              async (_old: string, newToken: string) => {
                currentToken = newToken;
              },
            );
            // uuidv4 output is opaque to the test; only observe that
            // rotation succeeds and the stored token moves forward each
            // time.
            const result = await service.refreshTokens({
              refreshToken: currentToken,
            } as any);
            expect(result.accessToken).toBe('signed.jwt.token');
          }
        } finally {
          jest.useRealTimers();
        }

        // 4 successful rotations spanning 40 days — never once rejected —
        // because each one re-measured 30 days forward from its own "now",
        // not from the original login 40 days ago.
        expect(repository.rotateRefreshToken).toHaveBeenCalledTimes(4);
      },
    );

    it(
      '29 days of inactivity followed by one successful refresh extends the ' +
        'session another 30 days from now, not from the original login',
      async () => {
        const originalLoginMs = Date.now() - 29 * 24 * 60 * 60 * 1000;
        repository.findRefreshToken.mockResolvedValue(
          storedToken({
            // Issued 29 days ago with the standard 30-day lifetime — 1 day
            // of slack left, proving this is cutting it close on purpose.
            expiresAt: new Date(originalLoginMs + 30 * 24 * 60 * 60 * 1000),
          }),
        );

        const before = Date.now();
        await service.refreshTokens({ refreshToken: 'old-refresh-token' } as any);

        const [, , , newExpiresAt] = repository.rotateRefreshToken.mock.calls[0];
        const deltaFromNow = (newExpiresAt as Date).getTime() - before;
        // ~30 days from NOW, not ~1 day (what would remain if it merely kept
        // the original token's expiry) and not ~59 days (from original login).
        expect(deltaFromNow).toBeGreaterThan(29.9 * 24 * 60 * 60 * 1000);
        expect(deltaFromNow).toBeLessThan(30.1 * 24 * 60 * 60 * 1000);
      },
    );

    it(
      'genuine inactivity past the full 30-day window is a definite rejection ' +
        '— the user must log in again, with no way to refresh past it',
      async () => {
        const loginMs = Date.now() - 31 * 24 * 60 * 60 * 1000;
        repository.findRefreshToken.mockResolvedValue(
          storedToken({
            // Never rotated in 31 days — genuinely unused past the window.
            expiresAt: new Date(loginMs + 30 * 24 * 60 * 60 * 1000),
            replacedByToken: null,
          }),
        );

        await expect(
          service.refreshTokens({ refreshToken: 'old-refresh-token' } as any),
        ).rejects.toMatchObject({ status: 401 });
        expect(repository.rotateRefreshToken).not.toHaveBeenCalled();
      },
    );

    it(
      'concurrent refresh calls presenting the same not-yet-rotated token ' +
        'both succeed independently — a race never manifests as a logout',
      async () => {
        // Both concurrent callers see the token before either has rotated it
        // — exactly what two near-simultaneous requests (e.g. a retried
        // request racing a background refresh) observe in practice. Neither
        // must be rejected: the service has no "someone else is already
        // rotating this" guard, so each independently produces a valid new
        // token/session rather than one of them reading as a stale/invalid
        // presentation.
        repository.findRefreshToken.mockResolvedValue(storedToken());

        const [first, second] = await Promise.all([
          service.refreshTokens({ refreshToken: 'old-refresh-token' } as any),
          service.refreshTokens({ refreshToken: 'old-refresh-token' } as any),
        ]);

        expect(first.accessToken).toBe('signed.jwt.token');
        expect(second.accessToken).toBe('signed.jwt.token');
        expect(first.refreshToken).toEqual(expect.any(String));
        expect(second.refreshToken).toEqual(expect.any(String));
        // Neither call raised — a concurrent refresh race must never itself
        // invalidate the session at the service layer (the DB transaction,
        // not this service, is what serializes the actual row updates).
        expect(repository.rotateRefreshToken).toHaveBeenCalledTimes(2);
      },
    );

    it(
      'a temporary refresh failure (simulated by the repository throwing, ' +
        'e.g. a DB timeout) never deletes or otherwise revokes stored tokens',
      async () => {
        repository.findRefreshToken.mockResolvedValue(storedToken());
        repository.rotateRefreshToken.mockRejectedValueOnce(
          new Error('ETIMEDOUT'),
        );

        await expect(
          service.refreshTokens({ refreshToken: 'old-refresh-token' } as any),
        ).rejects.toThrow('ETIMEDOUT');

        // A transient failure must never reach for revocation — only a
        // definite auth rejection (unknown/expired/inactive) does that, and
        // none of those paths were hit here.
        expect(repository.deleteRefreshToken).not.toHaveBeenCalled();
        expect(repository.deleteAllRefreshTokens).not.toHaveBeenCalled();
      },
    );
  });
});
