import * as bcrypt from 'bcrypt';
import { AuthOtpPurpose, Role } from '@prisma/client';
import { AuthService } from './auth.service';

describe('AuthService — SMS OTP login/registration', () => {
  let repository: any;
  let jwtService: any;
  let config: any;
  let storageService: any;
  let smsOtp: any;
  let service: AuthService;

  const IP = '10.0.0.1';
  const PHONE_RAW = '03378372427';
  const PHONE_NORMALIZED = '+923378372427';

  const CLIENT_USER = {
    id: 'client-1',
    phone: PHONE_NORMALIZED,
    role: Role.CLIENT,
    isActive: true,
    deletedAt: null,
    passwordHash: null,
  };

  const WORKER_USER = {
    id: 'worker-1',
    phone: PHONE_NORMALIZED,
    role: Role.WORKER,
    isActive: true,
    deletedAt: null,
    passwordHash: 'hashed',
  };

  function activeOtpRecord(overrides: Partial<any> = {}) {
    return {
      id: 'otp-1',
      phone: PHONE_NORMALIZED,
      attempts: 0,
      otpHash: '$dummy$will-be-overridden-per-test',
      ...overrides,
    };
  }

  beforeEach(() => {
    repository = {
      countRecentAuthOtpByPhone: jest.fn().mockResolvedValue(0),
      countRecentAuthOtpByIp: jest.fn().mockResolvedValue(0),
      mostRecentAuthOtp: jest.fn().mockResolvedValue(null),
      invalidatePreviousAuthOtps: jest.fn().mockResolvedValue(undefined),
      createAuthOtp: jest.fn().mockResolvedValue(undefined),
      findActiveAuthOtp: jest.fn().mockResolvedValue(null),
      consumeAuthOtp: jest.fn().mockResolvedValue(undefined),
      incrementAuthOtpAttempts: jest.fn().mockResolvedValue(undefined),
      findUserByPhoneVariants: jest.fn().mockResolvedValue(null),
      findUserByPhone: jest.fn().mockResolvedValue(null),
      createUserWithProfile: jest.fn(),
      createRefreshToken: jest.fn().mockResolvedValue(undefined),
      findClientProfile: jest
        .fn()
        .mockResolvedValue({ firstName: 'Existing', lastName: 'Client' }),
      findWorkerProfile: jest.fn().mockResolvedValue({
        firstName: 'Existing',
        lastName: 'Worker',
        verificationStatus: 'VERIFIED',
      }),
      findUserByNormalizedPhone: jest.fn().mockResolvedValue(null),
      countRecentOtpRequests: jest.fn().mockResolvedValue(0),
      findMostRecentPasswordResetOtp: jest.fn().mockResolvedValue(null),
      invalidatePreviousOtps: jest.fn().mockResolvedValue(undefined),
      createPasswordResetOtp: jest.fn().mockResolvedValue(undefined),
      findActiveOtp: jest.fn().mockResolvedValue(null),
      incrementOtpAttempts: jest.fn().mockResolvedValue(undefined),
      consumeOtp: jest.fn().mockResolvedValue(undefined),
      consumeAllActiveOtps: jest.fn().mockResolvedValue(undefined),
      updatePassword: jest.fn().mockResolvedValue(undefined),
    };
    jwtService = { sign: jest.fn().mockReturnValue('signed.jwt.token') };
    config = {
      getOrThrow: jest.fn().mockReturnValue('15m'),
      get: jest.fn().mockReturnValue(undefined),
    };
    storageService = {};
    smsOtp = { isConfigured: false, sendOtp: jest.fn() };

    service = new AuthService(
      repository,
      jwtService,
      config,
      storageService,
      smsOtp,
    );

    process.env.NODE_ENV = 'test'; // non-production -> dev OTP log path
  });

  // ── requestOtp ───────────────────────────────────────────────────────────

  describe('requestOtp', () => {
    it('rejects an invalid phone number without touching the repository', async () => {
      await expect(
        service.requestOtp('123', AuthOtpPurpose.CLIENT_LOGIN_REGISTER, IP),
      ).rejects.toMatchObject({
        response: { error: 'INVALID_PHONE' },
      });
      expect(repository.createAuthOtp).not.toHaveBeenCalled();
    });

    it('enforces the phone rate limit (3 per 30 minutes)', async () => {
      repository.countRecentAuthOtpByPhone.mockResolvedValue(3);
      await expect(
        service.requestOtp(PHONE_RAW, AuthOtpPurpose.CLIENT_LOGIN_REGISTER, IP),
      ).rejects.toMatchObject({ response: { error: 'OTP_RATE_LIMITED' } });
    });

    it('enforces the IP rate limit', async () => {
      repository.countRecentAuthOtpByIp.mockResolvedValue(10);
      await expect(
        service.requestOtp(PHONE_RAW, AuthOtpPurpose.CLIENT_LOGIN_REGISTER, IP),
      ).rejects.toMatchObject({ response: { error: 'OTP_RATE_LIMITED' } });
    });

    it('enforces the 60-second resend cooldown', async () => {
      repository.mostRecentAuthOtp.mockResolvedValue({
        createdAt: new Date(Date.now() - 10_000), // 10s ago
      });
      await expect(
        service.requestOtp(PHONE_RAW, AuthOtpPurpose.CLIENT_LOGIN_REGISTER, IP),
      ).rejects.toMatchObject({ response: { error: 'OTP_RESEND_TOO_SOON' } });
    });

    it('allows resend once the cooldown has passed, invalidating the previous OTP first', async () => {
      repository.mostRecentAuthOtp.mockResolvedValue({
        createdAt: new Date(Date.now() - 61_000), // 61s ago
      });
      const result = await service.requestOtp(
        PHONE_RAW,
        AuthOtpPurpose.CLIENT_LOGIN_REGISTER,
        IP,
      );
      expect(repository.invalidatePreviousAuthOtps).toHaveBeenCalledWith(
        PHONE_NORMALIZED,
        AuthOtpPurpose.CLIENT_LOGIN_REGISTER,
      );
      expect(repository.createAuthOtp).toHaveBeenCalled();
      expect(result).toHaveProperty('expiresAt');
    });

    it('never returns or logs the OTP value in the response', async () => {
      const result = await service.requestOtp(
        PHONE_RAW,
        AuthOtpPurpose.CLIENT_LOGIN_REGISTER,
        IP,
      );
      expect(Object.keys(result)).toEqual(['expiresAt']);
    });

    it('stores the OTP against the normalized phone regardless of input format', async () => {
      await service.requestOtp(
        '923378372427',
        AuthOtpPurpose.WORKER_LOGIN,
        IP,
      );
      expect(repository.createAuthOtp).toHaveBeenCalledWith(
        expect.objectContaining({
          phone: PHONE_NORMALIZED,
          purpose: AuthOtpPurpose.WORKER_LOGIN,
        }),
      );
    });

    it('surfaces SMS send failure as a distinct error and does not silently succeed', async () => {
      smsOtp.isConfigured = true;
      smsOtp.sendOtp.mockResolvedValue(false);
      await expect(
        service.requestOtp(PHONE_RAW, AuthOtpPurpose.CLIENT_LOGIN_REGISTER, IP),
      ).rejects.toMatchObject({ response: { error: 'SMS_SEND_FAILED' } });
    });

    it('succeeds via SMS when the provider accepts the message', async () => {
      smsOtp.isConfigured = true;
      smsOtp.sendOtp.mockResolvedValue(true);
      const result = await service.requestOtp(
        PHONE_RAW,
        AuthOtpPurpose.CLIENT_LOGIN_REGISTER,
        IP,
      );
      expect(result).toHaveProperty('expiresAt');
    });
  });

  // ── OTP verification (attempts/expiry/purpose isolation) ────────────────

  describe('OTP verification (via workerOtpLogin as a representative caller)', () => {
    it('rejects when no active OTP exists (expired or never requested)', async () => {
      repository.findActiveAuthOtp.mockResolvedValue(null);
      await expect(
        service.workerOtpLogin(PHONE_RAW, '123456'),
      ).rejects.toMatchObject({ response: { error: 'OTP_EXPIRED' } });
    });

    it('rejects and consumes the OTP once attempts reach the limit', async () => {
      repository.findActiveAuthOtp.mockResolvedValue(
        activeOtpRecord({ attempts: 5 }),
      );
      await expect(
        service.workerOtpLogin(PHONE_RAW, '123456'),
      ).rejects.toMatchObject({ response: { error: 'OTP_ATTEMPTS_EXCEEDED' } });
      expect(repository.consumeAuthOtp).toHaveBeenCalledWith('otp-1');
    });

    it('increments attempts on a wrong code without consuming the OTP', async () => {
      const otpHash = await bcrypt.hash('999999', 10);
      repository.findActiveAuthOtp.mockResolvedValue(
        activeOtpRecord({ otpHash }),
      );
      await expect(
        service.workerOtpLogin(PHONE_RAW, '123456'),
      ).rejects.toMatchObject({ response: { error: 'OTP_INVALID' } });
      expect(repository.incrementAuthOtpAttempts).toHaveBeenCalledWith('otp-1');
      expect(repository.consumeAuthOtp).not.toHaveBeenCalled();
    });

    it('consumes the OTP on successful verification (prevents reuse)', async () => {
      const otpHash = await bcrypt.hash('123456', 10);
      repository.findActiveAuthOtp.mockResolvedValue(
        activeOtpRecord({ otpHash }),
      );
      repository.findUserByPhoneVariants.mockResolvedValue(WORKER_USER);
      await service.workerOtpLogin(PHONE_RAW, '123456');
      expect(repository.consumeAuthOtp).toHaveBeenCalledWith('otp-1');
    });

    it('looks up the OTP under the purpose-specific bucket (purpose isolation)', async () => {
      const otpHash = await bcrypt.hash('123456', 10);
      repository.findActiveAuthOtp.mockResolvedValue(
        activeOtpRecord({ otpHash }),
      );
      repository.findUserByPhoneVariants.mockResolvedValue(WORKER_USER);
      await service.workerOtpLogin(PHONE_RAW, '123456');
      expect(repository.findActiveAuthOtp).toHaveBeenCalledWith(
        PHONE_NORMALIZED,
        AuthOtpPurpose.WORKER_LOGIN,
      );
    });
  });

  // ── Client combined login/register ───────────────────────────────────────

  describe('clientOtpLoginOrRegister', () => {
    beforeEach(async () => {
      const otpHash = await bcrypt.hash('123456', 10);
      repository.findActiveAuthOtp.mockResolvedValue(
        activeOtpRecord({ otpHash }),
      );
    });

    it('logs in an existing CLIENT without touching their saved name', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(CLIENT_USER);
      const result = await service.clientOtpLoginOrRegister(
        'Different Typed Name',
        PHONE_RAW,
        '123456',
      );
      expect(repository.createUserWithProfile).not.toHaveBeenCalled();
      expect(result.user.firstName).toBe('Existing');
      expect(result.user.lastName).toBe('Client');
    });

    it('creates a new CLIENT (passwordless, normalized phone) when no account exists', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(null);
      repository.createUserWithProfile.mockResolvedValue({
        id: 'new-client',
        phone: PHONE_NORMALIZED,
        role: Role.CLIENT,
      });
      await service.clientOtpLoginOrRegister('Ali Khan', PHONE_RAW, '123456');
      expect(repository.createUserWithProfile).toHaveBeenCalledWith(
        expect.objectContaining({
          phone: PHONE_NORMALIZED,
          passwordHash: null,
          firstName: 'Ali',
          lastName: 'Khan',
          role: Role.CLIENT,
        }),
      );
    });

    it('rejects the Client flow when the phone already belongs to a WORKER', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(WORKER_USER);
      await expect(
        service.clientOtpLoginOrRegister('Ali Khan', PHONE_RAW, '123456'),
      ).rejects.toMatchObject({ response: { error: 'PHONE_IS_WORKER' } });
      expect(repository.createUserWithProfile).not.toHaveBeenCalled();
    });

    it('never creates an account when OTP verification fails', async () => {
      const otpHash = await bcrypt.hash('999999', 10);
      repository.findActiveAuthOtp.mockResolvedValue(
        activeOtpRecord({ otpHash }),
      );
      repository.findUserByPhoneVariants.mockResolvedValue(null);
      await expect(
        service.clientOtpLoginOrRegister('Ali Khan', PHONE_RAW, '123456'),
      ).rejects.toMatchObject({ response: { error: 'OTP_INVALID' } });
      expect(repository.createUserWithProfile).not.toHaveBeenCalled();
    });

    it('gracefully logs in instead of erroring when two concurrent registrations race (P2002)', async () => {
      repository.findUserByPhoneVariants
        .mockResolvedValueOnce(null) // initial lookup: no account yet
        .mockResolvedValueOnce(CLIENT_USER); // re-fetch after the race: winner's row
      const p2002 = Object.assign(new Error('Unique constraint failed'), {
        code: 'P2002',
        name: 'PrismaClientKnownRequestError',
      });
      Object.setPrototypeOf(
        p2002,
        require('@prisma/client').Prisma.PrismaClientKnownRequestError.prototype,
      );
      repository.createUserWithProfile.mockRejectedValue(p2002);

      const result = await service.clientOtpLoginOrRegister(
        'Ali Khan',
        PHONE_RAW,
        '123456',
      );
      expect(result.user.firstName).toBe('Existing');
      expect(repository.findUserByPhoneVariants).toHaveBeenCalledTimes(2);
    });
  });

  // ── Worker OTP registration ──────────────────────────────────────────────

  describe('workerOtpRegister', () => {
    beforeEach(async () => {
      const otpHash = await bcrypt.hash('123456', 10);
      repository.findActiveAuthOtp.mockResolvedValue(
        activeOtpRecord({ otpHash }),
      );
    });

    it('creates a WORKER with the given category and returns PENDING verification', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(null);
      repository.createUserWithProfile.mockResolvedValue({
        id: 'new-worker',
        phone: PHONE_NORMALIZED,
        role: Role.WORKER,
      });
      const result = await service.workerOtpRegister(
        'Muhammad Ali Khan',
        PHONE_RAW,
        '123456',
        'password123',
        'cat-1',
      );
      expect(repository.createUserWithProfile).toHaveBeenCalledWith(
        expect.objectContaining({
          role: Role.WORKER,
          categoryId: 'cat-1',
          firstName: 'Muhammad',
          lastName: 'Ali Khan',
        }),
      );
      expect(result.user.verificationStatus).toBe('PENDING');
    });

    it('rejects with PHONE_IS_WORKER when a Worker already owns the number', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(WORKER_USER);
      await expect(
        service.workerOtpRegister(
          'Ali Khan',
          PHONE_RAW,
          '123456',
          'password123',
          'cat-1',
        ),
      ).rejects.toMatchObject({ response: { error: 'PHONE_IS_WORKER' } });
    });

    it('rejects with PHONE_IS_CLIENT when a Client already owns the number', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(CLIENT_USER);
      await expect(
        service.workerOtpRegister(
          'Ali Khan',
          PHONE_RAW,
          '123456',
          'password123',
          'cat-1',
        ),
      ).rejects.toMatchObject({ response: { error: 'PHONE_IS_CLIENT' } });
    });
  });

  // ── Worker OTP login ─────────────────────────────────────────────────────

  describe('workerOtpLogin', () => {
    beforeEach(async () => {
      const otpHash = await bcrypt.hash('123456', 10);
      repository.findActiveAuthOtp.mockResolvedValue(
        activeOtpRecord({ otpHash }),
      );
    });

    it('logs in an existing WORKER', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(WORKER_USER);
      const result = await service.workerOtpLogin(PHONE_RAW, '123456');
      expect(result.user.role).toBe(Role.WORKER);
    });

    it('rejects when the phone has no account at all', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(null);
      await expect(
        service.workerOtpLogin(PHONE_RAW, '123456'),
      ).rejects.toMatchObject({ response: { error: 'WORKER_NOT_FOUND' } });
    });

    it('rejects when the phone belongs to a CLIENT, not a WORKER', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(CLIENT_USER);
      await expect(
        service.workerOtpLogin(PHONE_RAW, '123456'),
      ).rejects.toMatchObject({ response: { error: 'WORKER_NOT_FOUND' } });
    });
  });

  // ── Regression: existing password login is untouched ─────────────────────

  describe('existing password login (regression)', () => {
    it('still logs in a Worker by phone + password', async () => {
      const passwordHash = await bcrypt.hash('password123', 12);
      repository.findUserByPhone.mockResolvedValue({
        ...WORKER_USER,
        passwordHash,
      });
      const result = await service.login({
        phone: PHONE_RAW,
        password: 'password123',
      } as any);
      expect(result.user.role).toBe(Role.WORKER);
      expect(result.accessToken).toBe('signed.jwt.token');
    });
  });

  // ── Ustaad forgot-password (PasswordResetOtp — separate from AuthOtp) ────

  describe('forgotPasswordRequest', () => {
    it('sends via SmsOtpService and creates a 5-minute OTP for an existing WORKER', async () => {
      repository.findUserByNormalizedPhone.mockResolvedValue(WORKER_USER);
      smsOtp.isConfigured = true;
      smsOtp.sendOtp.mockResolvedValue(true);

      const before = Date.now();
      const result = await service.forgotPasswordRequest({
        phone: PHONE_RAW,
      } as any);
      const returnedExpiry = new Date(result.expiresAt).getTime();

      expect(smsOtp.sendOtp).toHaveBeenCalledWith(PHONE_NORMALIZED, expect.any(String));
      expect(repository.createPasswordResetOtp).toHaveBeenCalledWith(
        expect.objectContaining({ userId: WORKER_USER.id, phone: PHONE_NORMALIZED }),
      );
      const createdExpiry = repository.createPasswordResetOtp.mock.calls[0][0]
        .expiresAt as Date;
      expect(createdExpiry.getTime() - before).toBeGreaterThan(4.9 * 60 * 1000);
      expect(createdExpiry.getTime() - before).toBeLessThanOrEqual(5 * 60 * 1000 + 1000);
      expect(returnedExpiry).toBeGreaterThan(before);
    });

    it('never sends an OTP for a CLIENT phone, but returns the same safe response shape', async () => {
      repository.findUserByNormalizedPhone.mockResolvedValue(CLIENT_USER);
      const result = await service.forgotPasswordRequest({
        phone: PHONE_RAW,
      } as any);

      expect(repository.createPasswordResetOtp).not.toHaveBeenCalled();
      expect(smsOtp.sendOtp).not.toHaveBeenCalled();
      expect(result).toHaveProperty('message');
      expect(result).toHaveProperty('expiresAt');
    });

    it('never sends an OTP for an unregistered phone, but returns the same safe response shape', async () => {
      repository.findUserByNormalizedPhone.mockResolvedValue(null);
      const result = await service.forgotPasswordRequest({
        phone: PHONE_RAW,
      } as any);

      expect(repository.createPasswordResetOtp).not.toHaveBeenCalled();
      expect(smsOtp.sendOtp).not.toHaveBeenCalled();
      expect(result).toHaveProperty('expiresAt');
    });

    it('enforces the 60-second resend cooldown without sending another SMS', async () => {
      repository.findUserByNormalizedPhone.mockResolvedValue(WORKER_USER);
      const recentOtp = {
        id: 'prev-otp',
        createdAt: new Date(Date.now() - 10_000),
        expiresAt: new Date(Date.now() + 4 * 60 * 1000),
      };
      repository.findMostRecentPasswordResetOtp.mockResolvedValue(recentOtp);

      const result = await service.forgotPasswordRequest({
        phone: PHONE_RAW,
      } as any);

      expect(repository.createPasswordResetOtp).not.toHaveBeenCalled();
      expect(smsOtp.sendOtp).not.toHaveBeenCalled();
      expect(result.expiresAt).toBe(recentOtp.expiresAt.toISOString());
    });

    it('allows resend once the cooldown has passed', async () => {
      repository.findUserByNormalizedPhone.mockResolvedValue(WORKER_USER);
      repository.findMostRecentPasswordResetOtp.mockResolvedValue({
        id: 'prev-otp',
        createdAt: new Date(Date.now() - 61_000),
        expiresAt: new Date(Date.now() - 61_000 + 5 * 60 * 1000),
      });

      await service.forgotPasswordRequest({ phone: PHONE_RAW } as any);

      expect(repository.invalidatePreviousOtps).toHaveBeenCalledWith(
        WORKER_USER.id,
        PHONE_NORMALIZED,
      );
      expect(repository.createPasswordResetOtp).toHaveBeenCalledTimes(1);
    });

    it('rate-limits to 3 requests per 30 minutes without sending another SMS', async () => {
      repository.findUserByNormalizedPhone.mockResolvedValue(WORKER_USER);
      repository.countRecentOtpRequests.mockResolvedValue(3);

      await service.forgotPasswordRequest({ phone: PHONE_RAW } as any);

      expect(repository.createPasswordResetOtp).not.toHaveBeenCalled();
      expect(smsOtp.sendOtp).not.toHaveBeenCalled();
    });

    it('never returns or logs the OTP value in the response', async () => {
      repository.findUserByNormalizedPhone.mockResolvedValue(WORKER_USER);
      smsOtp.isConfigured = true;
      smsOtp.sendOtp.mockResolvedValue(true);

      const result = await service.forgotPasswordRequest({
        phone: PHONE_RAW,
      } as any);

      expect(Object.keys(result).sort()).toEqual(['expiresAt', 'message']);
    });

    it('falls back to a dev console log (not SMS) when SmsOtpService is not configured outside production', async () => {
      repository.findUserByNormalizedPhone.mockResolvedValue(WORKER_USER);
      smsOtp.isConfigured = false;

      await service.forgotPasswordRequest({ phone: PHONE_RAW } as any);

      expect(smsOtp.sendOtp).not.toHaveBeenCalled();
      expect(repository.createPasswordResetOtp).toHaveBeenCalledTimes(1);
    });
  });

  describe('forgotPasswordReset', () => {
    it('resets the password on a valid OTP and consumes it', async () => {
      repository.findUserByNormalizedPhone.mockResolvedValue(WORKER_USER);
      const otpHash = await bcrypt.hash('123456', 10);
      repository.findActiveOtp.mockResolvedValue({
        id: 'reset-otp-1',
        attempts: 0,
        otpHash,
      });

      const result = await service.forgotPasswordReset({
        phone: PHONE_RAW,
        otp: '123456',
        newPassword: 'newSecurePassword1',
      } as any);

      expect(repository.updatePassword).toHaveBeenCalledWith(
        WORKER_USER.id,
        expect.any(String),
      );
      expect(repository.consumeAllActiveOtps).toHaveBeenCalledWith(
        WORKER_USER.id,
        PHONE_NORMALIZED,
      );
      expect(result.message).toBeDefined();
    });

    it('locks out after 5 incorrect attempts', async () => {
      repository.findUserByNormalizedPhone.mockResolvedValue(WORKER_USER);
      repository.findActiveOtp.mockResolvedValue({
        id: 'reset-otp-1',
        attempts: 5,
        otpHash: 'irrelevant',
      });

      await expect(
        service.forgotPasswordReset({
          phone: PHONE_RAW,
          otp: '123456',
          newPassword: 'newSecurePassword1',
        } as any),
      ).rejects.toThrow('Invalid or expired reset code.');
      expect(repository.consumeOtp).toHaveBeenCalledWith('reset-otp-1');
      expect(repository.updatePassword).not.toHaveBeenCalled();
    });

    it('increments attempts on a wrong OTP without resetting the password', async () => {
      repository.findUserByNormalizedPhone.mockResolvedValue(WORKER_USER);
      const otpHash = await bcrypt.hash('999999', 10);
      repository.findActiveOtp.mockResolvedValue({
        id: 'reset-otp-1',
        attempts: 0,
        otpHash,
      });

      await expect(
        service.forgotPasswordReset({
          phone: PHONE_RAW,
          otp: '123456',
          newPassword: 'newSecurePassword1',
        } as any),
      ).rejects.toThrow('Invalid or expired reset code.');
      expect(repository.incrementOtpAttempts).toHaveBeenCalledWith('reset-otp-1');
      expect(repository.updatePassword).not.toHaveBeenCalled();
    });
  });
});
