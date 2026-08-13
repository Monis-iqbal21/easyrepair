import * as bcrypt from 'bcrypt';
import { AuthOtpPurpose, Role } from '@prisma/client';
import { AuthService } from './auth.service';
import { otpMessage, OTP_VALIDITY_MINUTES } from './sms-otp.service';

/**
 * OTP delivery must not depend on which handset asked.
 *
 * The production failure this pins: `@Ip()` behind a load balancer returns the
 * proxy's address, identical for every user, so the per-IP abuse cap counted
 * the whole platform into one bucket. The first phone to ask got its code and
 * everyone after it was rate-limited — indistinguishable, from the user's
 * side, from "OTP only works on one device".
 *
 * The second half covers the amplifier: a code the provider never accepted
 * used to stay in the table, burning the caller's resend cooldown and their
 * five-per-30-minutes quota over SMS they never received.
 */
describe('OTP delivery is device-independent', () => {
  let repository: any;
  let smsOtp: any;
  let service: AuthService;

  const WORKER_PHONE = '03378372427';
  const WORKER_NORMALIZED = '+923378372427';
  const CLIENT_PHONE = '03001234567';

  /** Two handsets on two different networks, both legitimate. */
  const PHONE_A_IP = '203.0.113.9';
  const PHONE_B_IP = '198.51.100.4';
  /** What every request looks like when the proxy is not trusted. */
  const PROXY_IP = '10.0.0.1';

  beforeEach(() => {
    repository = {
      countRecentAuthOtpByPhone: jest.fn().mockResolvedValue(0),
      countRecentAuthOtpByIp: jest.fn().mockResolvedValue(0),
      mostRecentAuthOtp: jest.fn().mockResolvedValue(null),
      invalidatePreviousAuthOtps: jest.fn().mockResolvedValue(undefined),
      createAuthOtp: jest.fn().mockResolvedValue('otp-row-1'),
      deleteAuthOtp: jest.fn().mockResolvedValue(undefined),
      markSmsDispatched: jest.fn().mockResolvedValue(undefined),
      findUserByPhoneVariants: jest.fn().mockResolvedValue(null),
    };
    smsOtp = { isConfigured: true, sendOtp: jest.fn().mockResolvedValue(true) };

    service = new AuthService(
      repository,
      { sign: jest.fn().mockReturnValue('signed.jwt') } as any,
      { get: jest.fn().mockReturnValue(undefined), getOrThrow: jest.fn() } as any,
      {} as any,
      smsOtp,
      { ensureSupportConversation: jest.fn().mockResolvedValue(null) } as any,
    );
    process.env.NODE_ENV = 'test';
  });

  // ── The reported symptom ──────────────────────────────────────────────────

  it('sends a Worker OTP to a second handset on a different network', async () => {
    await service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PHONE_A_IP);
    await service.requestOtp('03009998877', AuthOtpPurpose.WORKER_LOGIN, PHONE_B_IP);

    expect(smsOtp.sendOtp).toHaveBeenCalledTimes(2);
  });

  it('sends a Client OTP to a second handset on a different network', async () => {
    await service.requestOtp(
      CLIENT_PHONE,
      AuthOtpPurpose.CLIENT_LOGIN_REGISTER,
      PHONE_A_IP,
    );
    await service.requestOtp(
      '03011112222',
      AuthOtpPurpose.CLIENT_LOGIN_REGISTER,
      PHONE_B_IP,
    );

    expect(smsOtp.sendOtp).toHaveBeenCalledTimes(2);
  });

  it('does not bucket every caller together when the address is the proxy', async () => {
    // The pre-fix failure: with an untrusted proxy every request carried the
    // same private address, so one shared counter gated the whole platform.
    // Even at a saturated count, a private address must not gate anyone.
    repository.countRecentAuthOtpByIp.mockResolvedValue(9999);

    await expect(
      service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PROXY_IP),
    ).resolves.toEqual(expect.objectContaining({ expiresAt: expect.any(String) }));

    expect(repository.countRecentAuthOtpByIp).not.toHaveBeenCalled();
    expect(smsOtp.sendOtp).toHaveBeenCalledTimes(1);
    // A row that cannot identify a caller is not stored as if it could.
    expect(repository.createAuthOtp).toHaveBeenCalledWith(
      expect.objectContaining({ requestIp: null }),
    );
  });

  it('still counts real client addresses against the abuse cap', async () => {
    repository.countRecentAuthOtpByIp.mockResolvedValue(60);

    await expect(
      service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PHONE_A_IP),
    ).rejects.toMatchObject({ response: { error: 'OTP_RATE_LIMITED' } });
  });

  // ── Registration state must not matter ────────────────────────────────────

  it('issues an OTP for a number that has never registered', async () => {
    repository.findUserByPhoneVariants.mockResolvedValue(null);

    await service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_REGISTER, PHONE_B_IP);

    expect(smsOtp.sendOtp).toHaveBeenCalledTimes(1);
    // Nothing about issuing a code depends on an existing account.
    expect(repository.createAuthOtp).toHaveBeenCalledWith(
      expect.objectContaining({ phone: WORKER_NORMALIZED }),
    );
  });

  it('issues an OTP for an already-registered number from a new handset', async () => {
    repository.findUserByPhoneVariants.mockResolvedValue({
      id: 'u1',
      role: Role.WORKER,
      phone: WORKER_NORMALIZED,
    });

    await service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PHONE_B_IP);

    expect(smsOtp.sendOtp).toHaveBeenCalledTimes(1);
  });

  it('scopes the active code to phone + purpose, never to a device', async () => {
    await service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PHONE_A_IP);

    expect(repository.invalidatePreviousAuthOtps).toHaveBeenCalledWith(
      WORKER_NORMALIZED,
      AuthOtpPurpose.WORKER_LOGIN,
    );
    const [[created]] = repository.createAuthOtp.mock.calls;
    expect(Object.keys(created).sort()).toEqual(
      [
        'expiresAt',
        'otpHash',
        'phone',
        'purpose',
        'requestIp',
        'otpCiphertext',
        'otpCipherIv',
        'otpCipherTag',
      ].sort(),
    );
    // No admin-reveal encryption key configured in this test's config mock —
    // the OTP is still issued normally, it simply isn't admin-revealable.
    expect(created.otpCiphertext).toBeNull();
    expect(created.otpCipherIv).toBeNull();
    expect(created.otpCipherTag).toBeNull();
  });

  // #11 normal bcrypt verification still works — the admin-reveal encryption
  // addition is a parallel, additive copy and never touches otpHash.
  it('still stores a bcrypt hash of the real code, verifiable independently of the new encryption fields', async () => {
    await service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PHONE_A_IP);

    const [[created]] = repository.createAuthOtp.mock.calls;
    const [, sentOtp] = smsOtp.sendOtp.mock.calls[0];
    await expect(bcrypt.compare(sentOtp, created.otpHash)).resolves.toBe(true);
  });

  // ── Provider failure must not punish the caller ───────────────────────────

  it('returns a controlled error when the provider rejects the message', async () => {
    smsOtp.sendOtp.mockResolvedValue(false);

    await expect(
      service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PHONE_B_IP),
    ).rejects.toMatchObject({ response: { error: 'SMS_SEND_FAILED' } });
  });

  it('does not spend the resend quota on a code that was never delivered', async () => {
    smsOtp.sendOtp.mockResolvedValue(false);

    await expect(
      service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PHONE_B_IP),
    ).rejects.toMatchObject({ response: { error: 'SMS_SEND_FAILED' } });

    // Otherwise repeated provider hiccups lock a real Ustaad out for 30 minutes.
    expect(repository.deleteAuthOtp).toHaveBeenCalledWith('otp-row-1');
  });

  it('surfaces a provider timeout as the same controlled error, not a hang', async () => {
    // SmsOtpService aborts at 10s and resolves false; it never throws and
    // never leaves the request open.
    smsOtp.sendOtp.mockImplementation(
      () => new Promise((resolve) => setImmediate(() => resolve(false))),
    );

    await expect(
      service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PHONE_B_IP),
    ).rejects.toMatchObject({ response: { error: 'SMS_SEND_FAILED' } });
    expect(repository.deleteAuthOtp).toHaveBeenCalled();
  });

  it('keeps the 60-second resend cooldown deterministic', async () => {
    repository.mostRecentAuthOtp.mockResolvedValue({
      createdAt: new Date(Date.now() - 10_000),
    });

    await expect(
      service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PHONE_B_IP),
    ).rejects.toMatchObject({ response: { error: 'OTP_RESEND_TOO_SOON' } });
    // A cooldown is an answer, not silence — and no SMS is spent on it.
    expect(smsOtp.sendOtp).not.toHaveBeenCalled();
  });

  it('keeps the per-phone cap independent of the handset', async () => {
    repository.countRecentAuthOtpByPhone.mockResolvedValue(5);

    await expect(
      service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PHONE_B_IP),
    ).rejects.toMatchObject({ response: { error: 'OTP_RATE_LIMITED' } });
  });

  // ── Per-phone window sequencing ───────────────────────────────────────────

  it('allows exactly five requests in the window, then blocks the sixth', async () => {
    // Each call's own count reflects how many prior requests already landed
    // in the 30-minute window, mirroring what the DB would report.
    repository.countRecentAuthOtpByPhone
      .mockResolvedValueOnce(0)
      .mockResolvedValueOnce(1)
      .mockResolvedValueOnce(2)
      .mockResolvedValueOnce(3)
      .mockResolvedValueOnce(4)
      .mockResolvedValueOnce(5);

    for (let i = 0; i < 5; i++) {
      await service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PHONE_A_IP);
    }
    expect(smsOtp.sendOtp).toHaveBeenCalledTimes(5);

    await expect(
      service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PHONE_A_IP),
    ).rejects.toMatchObject({ response: { error: 'OTP_RATE_LIMITED' } });
    expect(smsOtp.sendOtp).toHaveBeenCalledTimes(5);
  });

  it('allows a request again once the 30-minute window has rolled past', async () => {
    // The next attempt lands after the count query's own `since` cutoff has
    // moved past the earlier five — same phone, same purpose, but the
    // repository now reports zero because those rows fell outside the
    // window it was asked about.
    repository.countRecentAuthOtpByPhone
      .mockResolvedValueOnce(5) // blocked
      .mockResolvedValueOnce(0); // window has rolled past

    await expect(
      service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PHONE_A_IP),
    ).rejects.toMatchObject({ response: { error: 'OTP_RATE_LIMITED' } });

    await service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PHONE_A_IP);
    expect(smsOtp.sendOtp).toHaveBeenCalledTimes(1);
  });

  it('includes retryAfterSeconds so the client can restore its countdown', async () => {
    repository.mostRecentAuthOtp.mockResolvedValue({
      createdAt: new Date(Date.now() - 23_000), // 37s remain of the 60s cooldown
    });

    await expect(
      service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PHONE_B_IP),
    ).rejects.toMatchObject({
      response: { error: 'OTP_RESEND_TOO_SOON', retryAfterSeconds: 37 },
    });
  });

  // ── Canonical phone identity ────────────────────────────────────────────

  it('shares one quota/cooldown bucket across every raw format of the same phone', async () => {
    // A resend attempt one second after the first, but typed in a different
    // raw shape (+92 vs bare 0-prefixed) — must still hit the same cooldown,
    // not a fresh bucket.
    repository.mostRecentAuthOtp.mockResolvedValue({
      createdAt: new Date(Date.now() - 1_000),
    });

    await expect(
      service.requestOtp('+923378372427', AuthOtpPurpose.WORKER_LOGIN, PHONE_A_IP),
    ).rejects.toMatchObject({ response: { error: 'OTP_RESEND_TOO_SOON' } });

    expect(repository.mostRecentAuthOtp).toHaveBeenCalledWith(
      WORKER_NORMALIZED,
      AuthOtpPurpose.WORKER_LOGIN,
    );
    expect(repository.countRecentAuthOtpByPhone).toHaveBeenCalledWith(
      WORKER_NORMALIZED,
      AuthOtpPurpose.WORKER_LOGIN,
      expect.any(Date),
    );
  });

  it('keeps two different phone numbers on independent quota/cooldown buckets', async () => {
    // A saturated cooldown for one Ustaad's number must never bleed into an
    // unrelated number's ability to request a code.
    repository.mostRecentAuthOtp.mockImplementation(async (phone: string) =>
      phone === WORKER_NORMALIZED
        ? { createdAt: new Date() } // just requested, mid-cooldown
        : null,
    );

    await expect(
      service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PHONE_A_IP),
    ).rejects.toMatchObject({ response: { error: 'OTP_RESEND_TOO_SOON' } });

    await service.requestOtp('03009998877', AuthOtpPurpose.WORKER_LOGIN, PHONE_A_IP);
    expect(smsOtp.sendOtp).toHaveBeenCalledTimes(1);
  });

  // ── Never leak the code ───────────────────────────────────────────────────

  it('returns only the expiry, never the code', async () => {
    const result = await service.requestOtp(
      WORKER_PHONE,
      AuthOtpPurpose.WORKER_LOGIN,
      PHONE_A_IP,
    );

    expect(Object.keys(result)).toEqual(['expiresAt']);
    expect(JSON.stringify(result)).not.toMatch(/\d{6}/);
  });

  it('never writes a full code or a full phone number to the log', async () => {
    const written: string[] = [];
    const log = jest
      .spyOn((service as any).logger, 'log')
      .mockImplementation((m: any) => written.push(String(m)));
    const warn = jest
      .spyOn((service as any).logger, 'warn')
      .mockImplementation((m: any) => written.push(String(m)));

    smsOtp.isConfigured = false; // exercises the dev log path
    await service.requestOtp(WORKER_PHONE, AuthOtpPurpose.WORKER_LOGIN, PHONE_A_IP);

    for (const line of written) {
      expect(line).not.toContain(WORKER_NORMALIZED);
      expect(line).not.toMatch(/\b\d{6}\b/);
    }
    log.mockRestore();
    warn.mockRestore();
  });

  // ── The message itself ────────────────────────────────────────────────────

  describe('production SMS copy', () => {
    it('names HandyGo, the code, the expiry and the do-not-share warning', () => {
      const text = otpMessage('123456');

      expect(text).toBe(
        'Aap ka HandyGo verification code 123456 hai. ' +
          'Yeh 5 minute mein expire ho jayega. ' +
          'Yeh code kisi ke saath share na karein.',
      );
      expect(OTP_VALIDITY_MINUTES).toBe(5);
      // No trace of the old placeholder wording.
      expect(text).not.toContain('verification code:');
    });

    it('is plain Roman Urdu with no Devanagari or Urdu script', () => {
      const text = otpMessage('123456');
      expect(text).not.toMatch(/[ऀ-ॿ]/); // Devanagari
      expect(text).not.toMatch(/[؀-ۿ]/); // Arabic/Urdu script
    });
  });
});
