import * as bcrypt from 'bcrypt';
import { Role } from '@prisma/client';
import { AuthService } from './auth.service';

/**
 * Pins the suspension-lock contract at the backend boundary: a SUSPENDED
 * Worker must still be able to authenticate (tokens issue normally), and
 * every auth response (login, /auth/me, refresh) must carry the CURRENT
 * WorkerStatus fresh off the WorkerProfile row — never cached — so the
 * app's central routing gate can react immediately to an admin flipping the
 * status in either direction.
 */
describe('AuthService — Worker suspension exposure', () => {
  let repository: any;
  let jwtService: any;
  let config: any;
  let service: AuthService;

  const PHONE_RAW = '03378372427';
  const PHONE_NORMALIZED = '+923378372427';

  function workerUser(overrides: Partial<any> = {}) {
    return {
      id: 'worker-1',
      phone: PHONE_NORMALIZED,
      role: Role.WORKER,
      isActive: true,
      deletedAt: null,
      passwordHash: 'hashed',
      ...overrides,
    };
  }

  function workerProfile(status: string) {
    return {
      firstName: 'Bilal',
      lastName: 'Ahmed',
      verificationStatus: 'VERIFIED',
      status,
    };
  }

  beforeEach(() => {
    repository = {
      findUserByPhoneVariants: jest.fn().mockResolvedValue(null),
      findUserByPhone: jest.fn().mockResolvedValue(null),
      findUserById: jest.fn().mockResolvedValue(null),
      findWorkerProfile: jest.fn().mockResolvedValue(workerProfile('ACTIVE')),
      findClientProfile: jest.fn().mockResolvedValue(null),
      markPhoneVerified: jest.fn().mockResolvedValue(undefined),
      findActiveAuthOtp: jest.fn().mockResolvedValue(null),
      consumeAuthOtp: jest.fn().mockResolvedValue(undefined),
      incrementAuthOtpAttempts: jest.fn().mockResolvedValue(undefined),
      rotateRefreshToken: jest.fn().mockResolvedValue(undefined),
      findRefreshToken: jest.fn().mockResolvedValue(null),
      createRefreshToken: jest.fn().mockResolvedValue(undefined),
    };
    jwtService = { sign: jest.fn().mockReturnValue('signed.jwt.token') };
    config = {
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

  describe('workerOtpLogin', () => {
    it('a SUSPENDED Worker still authenticates successfully — token issuance is never blocked', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(workerUser());
      repository.findActiveAuthOtp.mockResolvedValue({
        id: 'otp-1',
        attempts: 0,
        otpHash: await bcrypt.hash('123456', 10),
      });
      repository.findWorkerProfile.mockResolvedValue(workerProfile('SUSPENDED'));

      const result = await service.workerOtpLogin(PHONE_RAW, '123456');

      expect(result.accessToken).toBe('signed.jwt.token');
      expect(result.refreshToken).toEqual(expect.any(String));
    });

    it('the auth response carries workerStatus SUSPENDED for a suspended account', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(workerUser());
      repository.findActiveAuthOtp.mockResolvedValue({
        id: 'otp-1',
        attempts: 0,
        otpHash: await bcrypt.hash('123456', 10),
      });
      repository.findWorkerProfile.mockResolvedValue(workerProfile('SUSPENDED'));

      const result = await service.workerOtpLogin(PHONE_RAW, '123456');

      expect(result.user.workerStatus).toBe('SUSPENDED');
    });

    it('an ACTIVE Worker gets workerStatus ACTIVE — normal access', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(workerUser());
      repository.findActiveAuthOtp.mockResolvedValue({
        id: 'otp-1',
        attempts: 0,
        otpHash: await bcrypt.hash('123456', 10),
      });
      repository.findWorkerProfile.mockResolvedValue(workerProfile('ACTIVE'));

      const result = await service.workerOtpLogin(PHONE_RAW, '123456');

      expect(result.user.workerStatus).toBe('ACTIVE');
    });

    it('an INACTIVE Worker gets workerStatus INACTIVE — also normal access (only SUSPENDED locks the app)', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(workerUser());
      repository.findActiveAuthOtp.mockResolvedValue({
        id: 'otp-1',
        attempts: 0,
        otpHash: await bcrypt.hash('123456', 10),
      });
      repository.findWorkerProfile.mockResolvedValue(workerProfile('INACTIVE'));

      const result = await service.workerOtpLogin(PHONE_RAW, '123456');

      expect(result.user.workerStatus).toBe('INACTIVE');
    });
  });

  describe('getMe (/auth/me — session restore)', () => {
    it('surfaces the current workerStatus, including SUSPENDED', async () => {
      repository.findUserById.mockResolvedValue(workerUser());
      repository.findWorkerProfile.mockResolvedValue(workerProfile('SUSPENDED'));

      const result = await service.getMe('worker-1');

      expect(result.workerStatus).toBe('SUSPENDED');
    });

    it('a status change back to ACTIVE is reflected on the very next call — nothing is cached', async () => {
      repository.findUserById.mockResolvedValue(workerUser());
      repository.findWorkerProfile.mockResolvedValueOnce(
        workerProfile('SUSPENDED'),
      );
      const first = await service.getMe('worker-1');
      expect(first.workerStatus).toBe('SUSPENDED');

      // Admin flips the worker back to ACTIVE between these two calls.
      repository.findWorkerProfile.mockResolvedValueOnce(workerProfile('ACTIVE'));
      const second = await service.getMe('worker-1');
      expect(second.workerStatus).toBe('ACTIVE');
    });

    it('a status change to INACTIVE is reflected on the very next call too', async () => {
      repository.findUserById.mockResolvedValue(workerUser());
      repository.findWorkerProfile.mockResolvedValueOnce(
        workerProfile('SUSPENDED'),
      );
      const first = await service.getMe('worker-1');
      expect(first.workerStatus).toBe('SUSPENDED');

      repository.findWorkerProfile.mockResolvedValueOnce(
        workerProfile('INACTIVE'),
      );
      const second = await service.getMe('worker-1');
      expect(second.workerStatus).toBe('INACTIVE');
    });
  });

  describe('refreshTokens (silent session refresh)', () => {
    it('a currently-SUSPENDED worker still refreshes their access token, carrying the current status', async () => {
      repository.findRefreshToken.mockResolvedValue({
        id: 'rt-1',
        token: 'refresh-token-1',
        userId: 'worker-1',
        expiresAt: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000),
        replacedByToken: null,
        supersededAt: null,
      });
      repository.findUserById.mockResolvedValue(workerUser());
      repository.findWorkerProfile.mockResolvedValue(workerProfile('SUSPENDED'));

      const result = await service.refreshTokens({
        refreshToken: 'refresh-token-1',
      } as any);

      expect(result.accessToken).toBe('signed.jwt.token');
      expect(result.user.workerStatus).toBe('SUSPENDED');
    });
  });

  describe('CLIENT accounts never carry workerStatus', () => {
    it('workerStatus is undefined on a Client auth response', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue({
        id: 'client-1',
        phone: PHONE_NORMALIZED,
        role: Role.CLIENT,
        isActive: true,
        deletedAt: null,
        passwordHash: await bcrypt.hash('password123', 12),
      });

      const result = await service.clientPasswordLogin(PHONE_RAW, 'password123');

      expect(result.user.workerStatus).toBeUndefined();
    });
  });
});
