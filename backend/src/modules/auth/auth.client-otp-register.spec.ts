import * as bcrypt from 'bcrypt';
import { Prisma } from '@prisma/client';

const { PrismaClientKnownRequestError } = Prisma;
import { AuthOtpPurpose, Role } from '@prisma/client';

import { AuthService } from './auth.service';

/**
 * Client registration OTP — "Verify & Create Account".
 *
 * Reported: the first tap appears to hang, the Client resends, the new SMS
 * arrives, and the NEWEST code is then also rejected.
 *
 * `clientPasswordRegister` differs from `workerOtpVerify` in one decisive way:
 * it verifies (and CONSUMES) the code BEFORE it checks whether the number
 * already has an account, and it CREATES the account and issues tokens in the
 * same call. So a single request that the app never sees the answer to leaves
 * behind a real account — and every later attempt on that number burns a fresh
 * code and is then refused for a reason the code can never fix.
 *
 * The existing auth specs mock `findActiveAuthOtp` to whatever they need, so
 * none of them can answer "which record does the second attempt hit?" or "what
 * does the third attempt see?". This file uses a small in-memory table whose
 * predicates mirror `AuthRepository`, so send / resend / verify run against
 * real service logic with real record selection and real state carried between
 * calls.
 *
 * No SMS is sent: `smsOtp.sendOtp` is a spy, and it is also how the test learns
 * the plaintext code — the column stores a bcrypt hash.
 */

const IP = '203.0.113.9';
const PHONE_LOCAL = '03273359444';
const PHONE_E164 = '+923273359444';
const PHONE_NO_PLUS = '923273359444';
const PHONE_NORMALIZED = '+923273359444';

const OTP_RESEND_COOLDOWN_MS = 60 * 1000;
const PURPOSE = AuthOtpPurpose.CLIENT_LOGIN_REGISTER;

type Row = {
  id: string;
  phone: string;
  purpose: AuthOtpPurpose;
  otpHash: string;
  attempts: number;
  expiresAt: Date;
  consumedAt: Date | null;
  createdAt: Date;
};

/** Mirrors the real Prisma queries in `auth.repository.ts`, in memory. */
class FakeOtpStore {
  rows: Row[] = [];
  private seq = 0;

  findActiveAuthOtp = jest.fn(
    async (phone: string, purpose: AuthOtpPurpose): Promise<Row | null> => {
      const now = new Date();
      return (
        this.rows
          .filter(
            (r) =>
              r.phone === phone &&
              r.purpose === purpose &&
              r.consumedAt === null &&
              r.expiresAt > now,
          )
          .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())[0] ??
        null
      );
    },
  );

  mostRecentAuthOtp = jest.fn(
    async (phone: string, purpose: AuthOtpPurpose): Promise<Row | null> =>
      this.rows
        .filter((r) => r.phone === phone && r.purpose === purpose)
        .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())[0] ??
      null,
  );

  invalidatePreviousAuthOtps = jest.fn(
    async (phone: string, purpose: AuthOtpPurpose): Promise<void> => {
      for (const r of this.rows) {
        if (r.phone === phone && r.purpose === purpose && r.consumedAt === null) {
          r.consumedAt = new Date();
        }
      }
    },
  );

  createAuthOtp = jest.fn(async (input: any): Promise<string> => {
    const id = `otp-${++this.seq}`;
    this.rows.push({
      id,
      phone: input.phone,
      purpose: input.purpose,
      otpHash: input.otpHash,
      attempts: 0,
      expiresAt: input.expiresAt,
      consumedAt: null,
      createdAt: new Date(),
    });
    return id;
  });

  consumeAuthOtp = jest.fn(async (id: string): Promise<void> => {
    const row = this.rows.find((r) => r.id === id);
    if (row) row.consumedAt = new Date();
  });

  incrementAuthOtpAttempts = jest.fn(async (id: string): Promise<void> => {
    const row = this.rows.find((r) => r.id === id);
    if (row) row.attempts += 1;
  });

  deleteAuthOtp = jest.fn(async (id: string): Promise<void> => {
    this.rows = this.rows.filter((r) => r.id !== id);
  });

  /** Models the Client waiting out the 60s resend cooldown. */
  rewindAll(ms: number) {
    for (const r of this.rows) {
      r.createdAt = new Date(r.createdAt.getTime() - ms);
    }
  }

  byId(id: string) {
    return this.rows.find((r) => r.id === id)!;
  }

  get active() {
    const now = new Date();
    return this.rows.filter((r) => r.consumedAt === null && r.expiresAt > now);
  }
}

function makeService() {
  const store = new FakeOtpStore();
  const sentCodes: string[] = [];

  /** The `users` table, as far as this flow is concerned. */
  const users: {
    id: string;
    phone: string;
    role: Role;
    isActive: boolean;
    deletedAt: Date | null;
    passwordHash: string | null;
    accountStatus: string;
  }[] = [];
  let created = 0;

  const repository: any = {
    findActiveAuthOtp: store.findActiveAuthOtp,
    mostRecentAuthOtp: store.mostRecentAuthOtp,
    invalidatePreviousAuthOtps: store.invalidatePreviousAuthOtps,
    createAuthOtp: store.createAuthOtp,
    consumeAuthOtp: store.consumeAuthOtp,
    incrementAuthOtpAttempts: store.incrementAuthOtpAttempts,
    deleteAuthOtp: store.deleteAuthOtp,
    countRecentAuthOtpByPhone: jest.fn().mockResolvedValue(0),
    countRecentAuthOtpByIp: jest.fn().mockResolvedValue(0),
    markSmsDispatched: jest.fn().mockResolvedValue(undefined),

    // Whatever the register call has actually written so far — this is the
    // state that survives between attempts and makes the loop possible.
    findUserByPhoneVariants: jest.fn(async (variants: string[]) =>
      users.find((u) => variants.includes(u.phone)) ?? null,
    ),
    createUserWithProfile: jest.fn(async (input: any) => {
      created += 1;
      const user = {
        id: `user-${created}`,
        phone: input.phone,
        role: input.role,
        isActive: true,
        deletedAt: null,
        // The real column: whatever password the registration carried.
        passwordHash: input.passwordHash as string,
        accountStatus: 'ACTIVE',
      };
      users.push(user);
      return user;
    }),
    createRefreshToken: jest.fn().mockResolvedValue(undefined),
    findClientProfile: jest
      .fn()
      .mockResolvedValue({ firstName: 'Ayesha', lastName: 'Malik' }),
  };

  const jwtService = { sign: jest.fn(() => 'signed.jwt.token') };
  const config = {
    getOrThrow: jest.fn().mockReturnValue('15m'),
    get: jest.fn().mockReturnValue(undefined),
  };
  const smsOtp = {
    isConfigured: true,
    sendOtp: jest.fn(async (_phone: string, code: string) => {
      sentCodes.push(code);
      return true;
    }),
  };

  const service = new AuthService(
    repository as never,
    jwtService as never,
    config as never,
    {} as never,
    smsOtp as never,
    { ensureSupportConversation: jest.fn() } as never,
    { handleWorkerLogout: jest.fn() } as never,
  );

  return { service, store, repository, smsOtp, sentCodes, users };
}

/** Sends a CLIENT_LOGIN_REGISTER code and returns the plaintext received. */
async function sendCode(
  service: AuthService,
  sentCodes: string[],
  phone = PHONE_LOCAL,
) {
  await service.requestOtp(phone, PURPOSE, IP);
  return sentCodes[sentCodes.length - 1];
}

const PASSWORD = 'password123';

const register = (
  service: AuthService,
  otp: string,
  { phone = PHONE_LOCAL, password = PASSWORD }: {
    phone?: string;
    password?: string;
  } = {},
) => service.clientPasswordRegister('Ayesha Malik', phone, password, otp);

/** Seeds an account that already exists, the way the DB would hold it. */
async function seedUser(
  users: any[],
  {
    role = Role.CLIENT as Role,
    password = PASSWORD,
    isActive = true,
    deletedAt = null as Date | null,
  } = {},
) {
  users.push({
    id: 'existing-1',
    phone: PHONE_NORMALIZED,
    role,
    isActive,
    deletedAt,
    passwordHash: await bcrypt.hash(password, 10),
    accountStatus: 'ACTIVE',
  });
  return users[users.length - 1];
}

beforeEach(() => {
  process.env.NODE_ENV = 'test';
});

// ── 1. Fresh unregistered Client ────────────────────────────────────────────

describe('1 — a fresh number registers in one call', () => {
  it('verifies, consumes the code, creates the account and issues tokens', async () => {
    const { service, store, sentCodes, repository, users } = makeService();
    const code = await sendCode(service, sentCodes);

    const result = await register(service, code);

    expect(result.accessToken).toBeTruthy();
    expect(result.refreshToken).toBeTruthy();
    expect(result.user.role).toBe(Role.CLIENT);
    expect(users).toHaveLength(1);
    expect(store.active).toHaveLength(0);
    expect(repository.createUserWithProfile).toHaveBeenCalledWith(
      expect.objectContaining({ phoneVerified: true }),
    );
  });
});

// ── 2. Wrong OTP ────────────────────────────────────────────────────────────

describe('2 — a wrong code creates nothing', () => {
  it('rejects with OTP_INVALID and leaves the code live', async () => {
    const { service, store, sentCodes, repository } = makeService();
    const code = await sendCode(service, sentCodes);
    const wrong = code === '111111' ? '222222' : '111111';

    await expect(register(service, wrong)).rejects.toMatchObject({
      response: { error: 'OTP_INVALID' },
    });

    expect(repository.createUserWithProfile).not.toHaveBeenCalled();
    expect(store.active).toHaveLength(1);
    expect(store.active[0].attempts).toBe(1);
    await expect(register(service, code)).resolves.toBeDefined();
  });
});

// ── 3. Resend ───────────────────────────────────────────────────────────────

describe('3 — after a resend only the newest code works', () => {
  it('rejects A and accepts B', async () => {
    const { service, store, sentCodes } = makeService();
    const codeA = await sendCode(service, sentCodes);

    store.rewindAll(OTP_RESEND_COOLDOWN_MS + 1000);
    const codeB = await sendCode(service, sentCodes);

    expect(codeB).not.toBe(codeA);
    expect(store.active).toHaveLength(1);

    await expect(register(service, codeA)).rejects.toMatchObject({
      response: { error: 'OTP_INVALID' },
    });
    await expect(register(service, codeB)).resolves.toBeDefined();
  });

  it('send / resend / verify all resolve to one identity across phone shapes', async () => {
    const { service, store, sentCodes } = makeService();
    await sendCode(service, sentCodes, PHONE_LOCAL);
    expect(store.rows[0].phone).toBe(PHONE_NORMALIZED);

    store.rewindAll(OTP_RESEND_COOLDOWN_MS + 1000);
    const codeB = await sendCode(service, sentCodes, PHONE_E164);

    expect(store.active).toHaveLength(1);
    await expect(
      register(service, codeB, { phone: PHONE_NO_PLUS }),
    ).resolves.toBeDefined();
  });
});

// ── 4-6. An already-registered number ───────────────────────────────────────

describe('4 — an existing CLIENT with the SAME password recovers', () => {
  it('is handed a session for the account that already exists, and no second '
    + 'account is created', async () => {
    const { service, store, sentCodes, users, repository } = makeService();
    await seedUser(users);

    const code = await sendCode(service, sentCodes);
    const result = await register(service, code);

    expect(result.accessToken).toBeTruthy();
    expect(result.user.id).toBe('existing-1');
    expect(result.user.role).toBe(Role.CLIENT);
    expect(repository.createUserWithProfile).not.toHaveBeenCalled();
    expect(users).toHaveLength(1);
    expect(store.active).toHaveLength(0); // the code is still spent exactly once
  });
});

describe('6 — an existing CLIENT with a WRONG password', () => {
  it('is refused, is not authenticated, and its password is untouched', async () => {
    const { service, sentCodes, users, repository } = makeService();
    const existing = await seedUser(users, { password: 'the-real-password' });
    const originalHash = existing.passwordHash;

    const code = await sendCode(service, sentCodes);

    await expect(
      register(service, code, { password: 'a-guess' }),
    ).rejects.toMatchObject({ response: { error: 'PHONE_ALREADY_REGISTERED' } });

    expect(repository.createUserWithProfile).not.toHaveBeenCalled();
    expect(users[0].passwordHash).toBe(originalHash);
    expect(users).toHaveLength(1);
  });

  it('a deactivated or deleted account is refused the same way', async () => {
    for (const overrides of [
      { isActive: false },
      { deletedAt: new Date('2026-01-01T00:00:00.000Z') },
    ]) {
      const { service, sentCodes, users } = makeService();
      await seedUser(users, overrides);
      const code = await sendCode(service, sentCodes);

      await expect(register(service, code)).rejects.toMatchObject({
        response: { error: 'PHONE_ALREADY_REGISTERED' },
      });
    }
  });
});

describe('7 — an existing WORKER on the same number', () => {
  it('is NEVER authenticated as a Client, even with the right password and a '
    + 'valid code', async () => {
    const { service, sentCodes, users, repository } = makeService();
    await seedUser(users, { role: Role.WORKER });

    const code = await sendCode(service, sentCodes);

    await expect(register(service, code)).rejects.toMatchObject({
      response: { error: 'PHONE_ALREADY_REGISTERED' },
    });
    expect(repository.createUserWithProfile).not.toHaveBeenCalled();
    expect(users).toHaveLength(1);
  });

  it('is refused with the SAME error as a wrong password, so registration '
    + 'still never reveals which role owns a number', async () => {
    const worker = makeService();
    await seedUser(worker.users, { role: Role.WORKER });
    const workerCode = await sendCode(worker.service, worker.sentCodes);
    const workerError = await register(worker.service, workerCode).catch(
      (e) => e,
    );

    const client = makeService();
    await seedUser(client.users, { password: 'different' });
    const clientCode = await sendCode(client.service, client.sentCodes);
    const clientError = await register(client.service, clientCode).catch(
      (e) => e,
    );

    expect(workerError.response).toEqual(clientError.response);
    expect(workerError.getStatus()).toBe(clientError.getStatus());
  });
});

describe('8 — an invalid code can never reach the recovery path', () => {
  it('a wrong code is rejected before the account is even looked up', async () => {
    const { service, sentCodes, users, repository } = makeService();
    await seedUser(users);

    const code = await sendCode(service, sentCodes);
    const wrong = code === '111111' ? '222222' : '111111';

    await expect(register(service, wrong)).rejects.toMatchObject({
      response: { error: 'OTP_INVALID' },
    });
    expect(repository.findUserByPhoneVariants).not.toHaveBeenCalled();
    expect(repository.createRefreshToken).not.toHaveBeenCalled();
  });

  it('an expired/spent code cannot authenticate an existing account', async () => {
    const { service, sentCodes, users, repository } = makeService();
    await seedUser(users);

    const code = await sendCode(service, sentCodes);
    await register(service, code); // recovers, spending the code
    repository.createRefreshToken.mockClear();

    await expect(register(service, code)).rejects.toMatchObject({
      response: { error: 'OTP_EXPIRED' },
    });
    expect(repository.createRefreshToken).not.toHaveBeenCalled();
  });
});

// ── 5. The reported sequence: a success the app never saw ───────────────────

describe('5 — a successful registration whose response never reached the app', () => {
  it('recovers on the next attempt instead of locking the number out', async () => {
    const { service, store, sentCodes, users, repository } = makeService();

    // Tap 1. The backend completes: code consumed, account created, tokens
    // issued, 201 returned. The app never sees it (receive timeout /
    // backgrounded) and stays on the OTP page showing an error.
    const codeA = await sendCode(service, sentCodes);
    const lostResponse = await register(service, codeA);
    expect(lostResponse.accessToken).toBeTruthy();
    expect(users).toHaveLength(1);

    // Tap 2 — the Client retries the same digits. The code really is spent,
    // and that is still refused: recovery never resurrects a used code.
    await expect(register(service, codeA)).rejects.toMatchObject({
      response: { error: 'OTP_EXPIRED' },
    });

    // The Client resends; a new SMS genuinely arrives.
    store.rewindAll(OTP_RESEND_COOLDOWN_MS + 1000);
    const codeB = await sendCode(service, sentCodes);
    expect(codeB).not.toBe(codeA);

    // THE FIX: the newest code now recovers the account the invisible first
    // call created, rather than being refused by it.
    const recovered = await register(service, codeB);
    expect(recovered.accessToken).toBeTruthy();
    expect(recovered.user.id).toBe('user-1');
    expect(recovered.user.role).toBe(Role.CLIENT);

    // Exactly one account, ever.
    expect(users).toHaveLength(1);
    expect(repository.createUserWithProfile).toHaveBeenCalledTimes(1);
    expect(store.active).toHaveLength(0);
  });

  it('recovery still costs one code per attempt — nothing about OTP handling '
    + 'was loosened', async () => {
    const { service, store, sentCodes } = makeService();
    const codeA = await sendCode(service, sentCodes);
    await register(service, codeA);

    store.rewindAll(OTP_RESEND_COOLDOWN_MS + 1000);
    const codeB = await sendCode(service, sentCodes);
    await register(service, codeB);

    // Both records consumed, none left live, no code reusable.
    expect(store.rows).toHaveLength(2);
    expect(store.rows.every((r) => r.consumedAt !== null)).toBe(true);
    await expect(register(service, codeB)).rejects.toMatchObject({
      response: { error: 'OTP_EXPIRED' },
    });
  });
});

// ── 9. Concurrent / repeated requests ───────────────────────────────────────

describe('9 — a repeated or concurrent registration', () => {
  it('never produces a duplicate Client', async () => {
    const { service, store, sentCodes, users, repository } = makeService();

    const codeA = await sendCode(service, sentCodes);
    await register(service, codeA);

    store.rewindAll(OTP_RESEND_COOLDOWN_MS + 1000);
    const codeB = await sendCode(service, sentCodes);
    await register(service, codeB);

    store.rewindAll(OTP_RESEND_COOLDOWN_MS + 1000);
    const codeC = await sendCode(service, sentCodes);
    await register(service, codeC);

    expect(users).toHaveLength(1);
    expect(repository.createUserWithProfile).toHaveBeenCalledTimes(1);
  });

  it('the loser of a unique-insert race recovers into the winner — but only '
    + 'on the winning account password', async () => {
    const { service, store, sentCodes, users, repository } = makeService();

    // The insert loses the race: the winning row appears between the
    // pre-check and the insert.
    repository.createUserWithProfile.mockImplementationOnce(async () => {
      users.push({
        id: 'winner-1',
        phone: PHONE_NORMALIZED,
        role: Role.CLIENT,
        isActive: true,
        deletedAt: null,
        passwordHash: await bcrypt.hash(PASSWORD, 10),
        accountStatus: 'ACTIVE',
      });
      const err: any = new Error('unique constraint');
      err.constructor = { name: 'PrismaClientKnownRequestError' };
      Object.setPrototypeOf(err, PrismaClientKnownRequestError.prototype);
      err.code = 'P2002';
      throw err;
    });

    const code = await sendCode(service, sentCodes);
    const result = await register(service, code);

    expect(result.user.id).toBe('winner-1');
    expect(users).toHaveLength(1);
    expect(store.active).toHaveLength(0);
  });

  it('and the race loser is refused when its password does not match the '
    + 'winning account', async () => {
    const { service, sentCodes, users, repository } = makeService();

    repository.createUserWithProfile.mockImplementationOnce(async () => {
      users.push({
        id: 'winner-1',
        phone: PHONE_NORMALIZED,
        role: Role.CLIENT,
        isActive: true,
        deletedAt: null,
        passwordHash: await bcrypt.hash('somebody-elses-password', 10),
        accountStatus: 'ACTIVE',
      });
      const err: any = new Error('unique constraint');
      Object.setPrototypeOf(err, PrismaClientKnownRequestError.prototype);
      err.code = 'P2002';
      throw err;
    });

    const code = await sendCode(service, sentCodes);
    await expect(register(service, code)).rejects.toMatchObject({
      response: { error: 'PHONE_ALREADY_REGISTERED' },
    });
    expect(users).toHaveLength(1);
  });
});

// ── 6. Verify + resend race ─────────────────────────────────────────────────

describe('6 — an old verify still in flight when the resend lands', () => {
  it('the stale attempt hits the NEW record and burns one of its attempts', async () => {
    const { service, store, sentCodes } = makeService();
    const codeA = await sendCode(service, sentCodes);

    store.rewindAll(OTP_RESEND_COOLDOWN_MS + 1000);
    const codeB = await sendCode(service, sentCodes);
    const recordB = store.active[0];

    // The hung request for A finally arrives.
    await expect(register(service, codeA)).rejects.toMatchObject({
      response: { error: 'OTP_INVALID' },
    });
    expect(store.byId(recordB.id).attempts).toBe(1);

    // B must still work.
    await expect(register(service, codeB)).resolves.toBeDefined();
  });
});

// ── 7. Multiple retries ─────────────────────────────────────────────────────

describe('7 — repeated rejected attempts', () => {
  it('five of them consume the newest record, after which the CORRECT newest '
    + 'code is refused', async () => {
    const { service, store, sentCodes } = makeService();
    await sendCode(service, sentCodes);

    store.rewindAll(OTP_RESEND_COOLDOWN_MS + 1000);
    const codeB = await sendCode(service, sentCodes);
    const recordB = store.active[0];
    const wrong = codeB === '111111' ? '222222' : '111111';

    for (let i = 0; i < 5; i++) {
      await expect(register(service, wrong)).rejects.toMatchObject({
        response: { error: 'OTP_INVALID' },
      });
    }
    expect(store.byId(recordB.id).attempts).toBe(5);

    await expect(register(service, codeB)).rejects.toMatchObject({
      response: { error: 'OTP_ATTEMPTS_EXCEEDED' },
    });
    expect(store.byId(recordB.id).consumedAt).not.toBeNull();

    await expect(register(service, codeB)).rejects.toMatchObject({
      response: { error: 'OTP_EXPIRED' },
    });
  });
});

// ── Purpose scoping ─────────────────────────────────────────────────────────

describe('purpose scoping', () => {
  it('registration verifies against CLIENT_LOGIN_REGISTER, the purpose the '
    + 'app requests under', async () => {
    const { service, store, sentCodes } = makeService();
    const code = await sendCode(service, sentCodes);

    expect(store.rows[0].purpose).toBe(AuthOtpPurpose.CLIENT_LOGIN_REGISTER);
    await expect(register(service, code)).resolves.toBeDefined();
  });

  it('a WORKER_REGISTER code is invisible to Client registration', async () => {
    const { service, sentCodes } = makeService();
    await service.requestOtp(PHONE_LOCAL, AuthOtpPurpose.WORKER_REGISTER, IP);
    const workerCode = sentCodes[sentCodes.length - 1];

    await expect(register(service, workerCode)).rejects.toMatchObject({
      response: { error: 'OTP_EXPIRED' },
    });
  });
});
