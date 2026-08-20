import * as bcrypt from 'bcrypt';
import { Role } from '@prisma/client';
import { AuthService } from './auth.service';

/**
 * The Ustaad password login must find an existing account whatever shape the
 * number arrives in.
 *
 * This is a regression guard, not a nicety. `login()` was the one auth path
 * that looked the number up EXACTLY as the app sent it, while every other path
 * normalized first. That was invisible while the login field asked for
 * `03XXXXXXXXX` and stored exactly that. The redesigned field shows `+92` as a
 * fixed prefix and asks for `3XX XXX XXXX`, so the app began sending the bare
 * national number — and a long-standing Ustaad whose row reads `+923378372427`
 * was told "Yeh number registered nahi hai" while holding a perfectly good
 * account.
 *
 * The tests below therefore fix the STORED format and vary the TYPED one, in
 * both directions, since accounts already exist in several historical shapes.
 */
describe('AuthService.login — Ustaad phone formats', () => {
  let repository: any;
  let service: AuthService;

  const PASSWORD = 'password123';
  let passwordHash: string;

  beforeAll(async () => {
    passwordHash = await bcrypt.hash(PASSWORD, 10);
  });

  function workerUser(storedPhone: string, overrides: Partial<any> = {}) {
    return {
      id: 'worker-1',
      phone: storedPhone,
      role: Role.WORKER,
      isActive: true,
      deletedAt: null,
      passwordHash,
      ...overrides,
    };
  }

  beforeEach(() => {
    repository = {
      findUserByPhoneVariants: jest.fn().mockResolvedValue(null),
      findUserByPhone: jest.fn().mockResolvedValue(null),
      findWorkerProfile: jest.fn().mockResolvedValue({
        firstName: 'Bilal',
        lastName: 'Ahmed',
        verificationStatus: 'VERIFIED',
        status: 'ACTIVE',
      }),
      findClientProfile: jest.fn().mockResolvedValue(null),
      createRefreshToken: jest.fn().mockResolvedValue(undefined),
    };
    const jwtService = { sign: jest.fn().mockReturnValue('signed.jwt.token') };
    const config = {
      getOrThrow: jest.fn((key: string) =>
        key === 'jwt.accessExpires'
          ? '15m'
          : key === 'jwt.refreshExpires'
            ? '30d'
            : 'unused',
      ),
      get: jest.fn().mockReturnValue(undefined),
    };
    service = new AuthService(
      repository,
      jwtService as any,
      config as any,
      {} as any,
      {} as any,
      { ensureSupportConversation: jest.fn() } as any,
      { handleWorkerLogout: jest.fn().mockResolvedValue(undefined) } as any,
    );
  });

  // Every shape the redesigned field, the old field, an autofill entry or a
  // pasted contact can produce.
  const TYPED: ReadonlyArray<readonly [string, string]> = [
    ['the bare national number the redesigned +92 field sends', '3378372427'],
    ['the classic leading-zero form', '03378372427'],
    ['E.164', '+923378372427'],
    ['a country code without the plus', '923378372427'],
    ['the international dialling prefix', '00923378372427'],
    ['a number with spaces, as pasted from contacts', '0337 837 2427'],
  ];

  // Every shape an account can already be stored in.
  const STORED = ['+923378372427', '03378372427', '923378372427'];

  describe.each(STORED)('an Ustaad stored as %s', (stored) => {
    it.each(TYPED)('logs in when they type %s', async (_label, typed) => {
      repository.findUserByPhoneVariants.mockImplementation(
        async (variants: string[]) =>
          variants.includes(stored) ? workerUser(stored) : null,
      );

      const result = await service.login({
        phone: typed,
        password: PASSWORD,
      } as any);

      expect(result.user.id).toBe('worker-1');
      expect(result.accessToken).toBeTruthy();
      // The exact-match lookup is what caused the regression; it must not be
      // how this path finds the account.
      expect(repository.findUserByPhone).not.toHaveBeenCalled();
    });
  });

  it('passes every historical variant to the repository, not just the typed string', async () => {
    repository.findUserByPhoneVariants.mockResolvedValue(
      workerUser('+923378372427'),
    );

    await service.login({ phone: '3378372427', password: PASSWORD } as any);

    const variants = repository.findUserByPhoneVariants.mock.calls[0][0];
    expect(variants).toEqual(
      expect.arrayContaining([
        '+923378372427',
        '03378372427',
        '923378372427',
        '00923378372427',
      ]),
    );
  });

  describe('what must still be refused', () => {
    it('a number with no account', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(null);
      await expect(
        service.login({ phone: '03378372427', password: PASSWORD } as any),
      ).rejects.toThrow();
    });

    it('a malformed number fails exactly like an unknown one, so the two stay indistinguishable', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(null);

      const unknown = await service
        .login({ phone: '03378372427', password: PASSWORD } as any)
        .catch((e) => e);
      const malformed = await service
        .login({ phone: 'not-a-number', password: PASSWORD } as any)
        .catch((e) => e);

      expect(malformed.constructor).toBe(unknown.constructor);
      expect(malformed.getResponse?.()).toEqual(unknown.getResponse?.());
    });

    it('a CLIENT-owned number is rejected exactly like an unknown one — this endpoint must never reveal which role owns a number', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(null);
      const unknown = await service
        .login({ phone: '03378372427', password: PASSWORD } as any)
        .catch((e) => e);

      repository.findUserByPhoneVariants.mockResolvedValue(
        workerUser('+923378372427', { role: Role.CLIENT }),
      );
      const client = await service
        .login({ phone: '03378372427', password: PASSWORD } as any)
        .catch((e) => e);

      expect(client.constructor).toBe(unknown.constructor);
      expect(client.getResponse?.()).toEqual(unknown.getResponse?.());
    });

    it('a soft-deleted account', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(
        workerUser('+923378372427', { deletedAt: new Date() }),
      );
      await expect(
        service.login({ phone: '03378372427', password: PASSWORD } as any),
      ).rejects.toThrow();
    });

    it('a deactivated account', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(
        workerUser('+923378372427', { isActive: false }),
      );
      await expect(
        service.login({ phone: '03378372427', password: PASSWORD } as any),
      ).rejects.toThrow();
    });

    it('the wrong password', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(
        workerUser('+923378372427'),
      );
      await expect(
        service.login({
          phone: '03378372427',
          password: 'wrongpassword',
        } as any),
      ).rejects.toThrow();
    });
  });

  describe('onboarding state never blocks the login itself', () => {
    // An Ustaad mid-registration, awaiting review or sent back for changes must
    // still get in — the app routes them by status AFTER authenticating. Only
    // the account-level flags above are a hard stop.
    it.each(['DRAFT', 'SUBMITTED_FOR_REVIEW', 'CHANGES_REQUIRED', 'APPROVED'])(
      'onboarding status %s still logs in',
      async (onboardingStatus) => {
        repository.findUserByPhoneVariants.mockResolvedValue(
          workerUser('+923378372427'),
        );
        repository.findWorkerProfile.mockResolvedValue({
          firstName: 'Bilal',
          lastName: 'Ahmed',
          verificationStatus: 'PENDING',
          status: 'ACTIVE',
          onboardingStatus,
        });

        const result = await service.login({
          phone: '3378372427',
          password: PASSWORD,
        } as any);
        expect(result.user.id).toBe('worker-1');
      },
    );

    it('a legacy Ustaad with no WorkerProfile row at all still logs in', async () => {
      repository.findUserByPhoneVariants.mockResolvedValue(
        workerUser('03378372427'),
      );
      repository.findWorkerProfile.mockResolvedValue(null);

      const result = await service.login({
        phone: '3378372427',
        password: PASSWORD,
      } as any);
      expect(result.user.id).toBe('worker-1');
    });
  });
});
