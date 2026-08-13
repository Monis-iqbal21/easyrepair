import { randomBytes } from 'crypto';
import {
  BadRequestException,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { AuthOtpPurpose } from '@prisma/client';
import { AdminOtpController } from './admin-otp.controller';
import { AdminOtpService } from './admin-otp.service';
import { AdminOtpRepository } from './admin-otp.repository';
import { encryptOtp } from '../../common/utils/otp-encryption.util';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';

const ENCRYPTION_KEY = randomBytes(32).toString('hex');

function makeConfig(key: string | undefined = ENCRYPTION_KEY): any {
  return {
    get: jest.fn((path: string) =>
      path === 'otpAdmin.encryptionKey' ? key : undefined,
    ),
  };
}

function baseRecord(overrides: Partial<any> = {}) {
  const now = Date.now();
  return {
    id: 'otp-1',
    phone: '+923001234567',
    purpose: AuthOtpPurpose.WORKER_LOGIN,
    otpHash: '$2b$10$dummyhashvalueeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
    expiresAt: new Date(now + 4 * 60 * 1000),
    consumedAt: null,
    attempts: 0,
    requestIp: '203.0.113.9',
    createdAt: new Date(now - 60 * 1000),
    smsDispatched: true,
    otpCiphertext: null,
    otpCipherIv: null,
    otpCipherTag: null,
    ...overrides,
  };
}

/**
 * Every OTP Diagnostics/reveal endpoint lives on AdminOtpController
 * ('admin/otp'), gated by Role.ADMIN — independent of anything the admin
 * web sidebar shows or hides.
 */
describe('AdminOtpController is behind Role.ADMIN', () => {
  it('Worker and Client are structurally excluded — only Role.ADMIN is allowed', () => {
    expect(Reflect.getMetadata(ROLES_KEY, AdminOtpController)).toEqual([
      Role.ADMIN,
    ]);
  });
});

// ── AdminOtpRepository — query construction ─────────────────────────────────

describe('AdminOtpRepository.findPaginated', () => {
  let prisma: any;
  let repo: AdminOtpRepository;

  beforeEach(() => {
    prisma = {
      authOtp: {
        findMany: jest.fn().mockResolvedValue([]),
        count: jest.fn().mockResolvedValue(0),
      },
    };
    repo = new AdminOtpRepository(prisma);
  });

  // #16 phone filter normalizes formats consistently
  it.each([
    ['031012' /* still being typed, too short to normalize */, undefined],
    ['03101234567', '+923101234567'],
    ['3101234567', '+923101234567'],
    ['923101234567', '+923101234567'],
    ['+923101234567', '+923101234567'],
  ])('normalizes phone search %s the same way auth does', async (input, expected) => {
    await repo.findPaginated({ search: input, sinceMinutes: 60, page: 1, pageSize: 20 } as any);
    const where = prisma.authOtp.findMany.mock.calls[0][0].where;
    if (expected) {
      expect(where.phone).toBe(expected);
    } else {
      expect(where.phone).toEqual(expect.objectContaining({ contains: expect.any(String) }));
    }
  });

  // #17 purpose filter works
  it('applies the purpose filter untouched', async () => {
    await repo.findPaginated({
      purpose: AuthOtpPurpose.CLIENT_LOGIN_REGISTER,
      sinceMinutes: 60,
      page: 1,
      pageSize: 20,
    } as any);
    const where = prisma.authOtp.findMany.mock.calls[0][0].where;
    expect(where.purpose).toBe(AuthOtpPurpose.CLIENT_LOGIN_REGISTER);
  });

  it('translates status=ACTIVE to not-consumed + not-yet-expired', async () => {
    await repo.findPaginated({ status: 'ACTIVE', sinceMinutes: 60, page: 1, pageSize: 20 } as any);
    const where = prisma.authOtp.findMany.mock.calls[0][0].where;
    expect(where.consumedAt).toBeNull();
    expect(where.expiresAt).toEqual(expect.objectContaining({ gt: expect.any(Date) }));
  });

  it('translates status=CONSUMED to consumedAt not null', async () => {
    await repo.findPaginated({ status: 'CONSUMED', sinceMinutes: 60, page: 1, pageSize: 20 } as any);
    const where = prisma.authOtp.findMany.mock.calls[0][0].where;
    expect(where.consumedAt).toEqual({ not: null });
  });

  it('translates status=EXPIRED to not-consumed + already past expiry', async () => {
    await repo.findPaginated({ status: 'EXPIRED', sinceMinutes: 60, page: 1, pageSize: 20 } as any);
    const where = prisma.authOtp.findMany.mock.calls[0][0].where;
    expect(where.consumedAt).toBeNull();
    expect(where.expiresAt).toEqual(expect.objectContaining({ lte: expect.any(Date) }));
  });

  // #18 pagination works
  it('paginates with the requested page/pageSize', async () => {
    await repo.findPaginated({ sinceMinutes: 60, page: 3, pageSize: 10 } as any);
    const args = prisma.authOtp.findMany.mock.calls[0][0];
    expect(args.skip).toBe(20);
    expect(args.take).toBe(10);
  });

  it('scopes to the requested time range', async () => {
    await repo.findPaginated({ sinceMinutes: 30, page: 1, pageSize: 20 } as any);
    const where = prisma.authOtp.findMany.mock.calls[0][0].where;
    expect(where.createdAt.gte.getTime()).toBeGreaterThan(Date.now() - 31 * 60 * 1000);
    expect(where.createdAt.gte.getTime()).toBeLessThan(Date.now() - 29 * 60 * 1000);
  });
});

// ── AdminOtpService.list ─────────────────────────────────────────────────────

describe('AdminOtpService.list', () => {
  it('#1 admin can list OTP records, computing pagination meta', async () => {
    const repository = {
      findPaginated: jest.fn().mockResolvedValue({ items: [baseRecord()], total: 41 }),
    };
    const service = new AdminOtpService(repository as any, makeConfig());

    const result = await service.list({ sinceMinutes: 60, page: 2, pageSize: 20 } as any);

    expect(result.items).toHaveLength(1);
    expect(result.meta).toEqual({ page: 2, pageSize: 20, total: 41, totalPages: 3 });
  });

  // #4 / #5 list never returns otpHash or encryption fields
  it('never includes otpHash or any encryption field on a list item', async () => {
    const repository = {
      findPaginated: jest.fn().mockResolvedValue({
        items: [
          baseRecord({
            otpCiphertext: 'cipher',
            otpCipherIv: 'iv',
            otpCipherTag: 'tag',
          }),
        ],
        total: 1,
      }),
    };
    const service = new AdminOtpService(repository as any, makeConfig());

    const result = await service.list({ sinceMinutes: 60, page: 1, pageSize: 20 } as any);

    const keys = Object.keys(result.items[0]);
    expect(keys).not.toEqual(
      expect.arrayContaining([
        'otpHash',
        'otpCiphertext',
        'otpCipherIv',
        'otpCipherTag',
      ]),
    );
  });

  // #6 active OTP shows revealable=true
  it('marks an active OTP with a stored encrypted copy as revealable', async () => {
    const repository = {
      findPaginated: jest.fn().mockResolvedValue({
        items: [
          baseRecord({
            otpCiphertext: 'cipher',
            otpCipherIv: 'iv',
            otpCipherTag: 'tag',
          }),
        ],
        total: 1,
      }),
    };
    const service = new AdminOtpService(repository as any, makeConfig());

    const result = await service.list({ sinceMinutes: 60, page: 1, pageSize: 20 } as any);
    expect(result.items[0].status).toBe('ACTIVE');
    expect(result.items[0].revealable).toBe(true);
  });

  // #2 ACTIVE + smsDispatched=false + encrypted OTP -> revealable=false
  it('marks an active OTP as not revealable when the SMS was never confirmed dispatched, even with a stored encrypted copy', async () => {
    const repository = {
      findPaginated: jest.fn().mockResolvedValue({
        items: [
          baseRecord({
            smsDispatched: false,
            otpCiphertext: 'cipher',
            otpCipherIv: 'iv',
            otpCipherTag: 'tag',
          }),
        ],
        total: 1,
      }),
    };
    const service = new AdminOtpService(repository as any, makeConfig());

    const result = await service.list({ sinceMinutes: 60, page: 1, pageSize: 20 } as any);
    expect(result.items[0].status).toBe('ACTIVE');
    expect(result.items[0].smsStatus).toBe('NOT_SENT');
    expect(result.items[0].revealable).toBe(false);
  });

  it('marks an active OTP with NO stored encrypted copy as not revealable', async () => {
    const repository = {
      findPaginated: jest.fn().mockResolvedValue({ items: [baseRecord()], total: 1 }),
    };
    const service = new AdminOtpService(repository as any, makeConfig());

    const result = await service.list({ sinceMinutes: 60, page: 1, pageSize: 20 } as any);
    expect(result.items[0].revealable).toBe(false);
  });

  it('derives CONSUMED status and never-revealable regardless of ciphertext presence', async () => {
    const repository = {
      findPaginated: jest.fn().mockResolvedValue({
        items: [
          baseRecord({
            consumedAt: new Date(),
            otpCiphertext: 'cipher',
            otpCipherIv: 'iv',
            otpCipherTag: 'tag',
          }),
        ],
        total: 1,
      }),
    };
    const service = new AdminOtpService(repository as any, makeConfig());

    const result = await service.list({ sinceMinutes: 60, page: 1, pageSize: 20 } as any);
    expect(result.items[0].status).toBe('CONSUMED');
    expect(result.items[0].revealable).toBe(false);
  });

  it('derives EXPIRED status and never-revealable', async () => {
    const repository = {
      findPaginated: jest.fn().mockResolvedValue({
        items: [
          baseRecord({
            expiresAt: new Date(Date.now() - 60_000),
            otpCiphertext: 'cipher',
            otpCipherIv: 'iv',
            otpCipherTag: 'tag',
          }),
        ],
        total: 1,
      }),
    };
    const service = new AdminOtpService(repository as any, makeConfig());

    const result = await service.list({ sinceMinutes: 60, page: 1, pageSize: 20 } as any);
    expect(result.items[0].status).toBe('EXPIRED');
    expect(result.items[0].revealable).toBe(false);
  });

  it('maps smsDispatched to a friendly DISPATCHED/NOT_SENT status', async () => {
    const repository = {
      findPaginated: jest.fn().mockResolvedValue({
        items: [baseRecord({ smsDispatched: true }), baseRecord({ id: 'otp-2', smsDispatched: false })],
        total: 2,
      }),
    };
    const service = new AdminOtpService(repository as any, makeConfig());

    const result = await service.list({ sinceMinutes: 60, page: 1, pageSize: 20 } as any);
    expect(result.items[0].smsStatus).toBe('DISPATCHED');
    expect(result.items[1].smsStatus).toBe('NOT_SENT');
  });
});

// ── AdminOtpService.reveal ────────────────────────────────────────────────────

describe('AdminOtpService.reveal', () => {
  let repository: any;
  let service: AdminOtpService;

  beforeEach(() => {
    repository = {
      findByIdForReveal: jest.fn(),
      createRevealAuditLog: jest.fn().mockResolvedValue(undefined),
    };
    service = new AdminOtpService(repository, makeConfig());
  });

  // #9 / #10 admin can reveal active OTP, plaintext equals what was generated
  it('decrypts and returns the exact plaintext OTP that was encrypted at issuance', async () => {
    const encrypted = encryptOtp('654321', ENCRYPTION_KEY);
    repository.findByIdForReveal.mockResolvedValue(
      baseRecord({
        otpCiphertext: encrypted.ciphertext,
        otpCipherIv: encrypted.iv,
        otpCipherTag: encrypted.tag,
      }),
    );

    const result = await service.reveal('otp-1', 'admin-1', '1.2.3.4', 'jest-agent');

    expect(result.otp).toBe('654321');
    expect(result.expiresAt).toBeInstanceOf(Date);
  });

  // #2 ACTIVE + smsDispatched=false + encrypted OTP -> direct POST /reveal rejected
  it('rejects revealing an ACTIVE OTP whose SMS was never confirmed dispatched, even with a valid encrypted copy', async () => {
    const encrypted = encryptOtp('999999', ENCRYPTION_KEY);
    repository.findByIdForReveal.mockResolvedValue(
      baseRecord({
        smsDispatched: false,
        otpCiphertext: encrypted.ciphertext,
        otpCipherIv: encrypted.iv,
        otpCipherTag: encrypted.tag,
      }),
    );

    await expect(service.reveal('otp-1', 'admin-1', null, null)).rejects.toThrow(
      BadRequestException,
    );
    expect(repository.createRevealAuditLog).not.toHaveBeenCalled();
  });

  it('never leaks the plaintext OTP in the rejection when smsDispatched is false', async () => {
    const encrypted = encryptOtp('888888', ENCRYPTION_KEY);
    repository.findByIdForReveal.mockResolvedValue(
      baseRecord({
        smsDispatched: false,
        otpCiphertext: encrypted.ciphertext,
        otpCipherIv: encrypted.iv,
        otpCipherTag: encrypted.tag,
      }),
    );

    try {
      await service.reveal('otp-1', 'admin-1', null, null);
      fail('expected reveal to throw');
    } catch (err) {
      expect(JSON.stringify((err as Error).message)).not.toContain('888888');
    }
  });

  // #7 expired OTP reveal rejected
  it('rejects revealing an expired OTP', async () => {
    const encrypted = encryptOtp('111111', ENCRYPTION_KEY);
    repository.findByIdForReveal.mockResolvedValue(
      baseRecord({
        expiresAt: new Date(Date.now() - 1000),
        otpCiphertext: encrypted.ciphertext,
        otpCipherIv: encrypted.iv,
        otpCipherTag: encrypted.tag,
      }),
    );

    await expect(service.reveal('otp-1', 'admin-1', null, null)).rejects.toThrow(
      BadRequestException,
    );
    expect(repository.createRevealAuditLog).not.toHaveBeenCalled();
  });

  // #8 consumed OTP reveal rejected
  it('rejects revealing a consumed OTP', async () => {
    const encrypted = encryptOtp('111111', ENCRYPTION_KEY);
    repository.findByIdForReveal.mockResolvedValue(
      baseRecord({
        consumedAt: new Date(),
        otpCiphertext: encrypted.ciphertext,
        otpCipherIv: encrypted.iv,
        otpCipherTag: encrypted.tag,
      }),
    );

    await expect(service.reveal('otp-1', 'admin-1', null, null)).rejects.toThrow(
      BadRequestException,
    );
    expect(repository.createRevealAuditLog).not.toHaveBeenCalled();
  });

  it('rejects revealing an OTP with no stored encrypted copy', async () => {
    repository.findByIdForReveal.mockResolvedValue(baseRecord());

    await expect(service.reveal('otp-1', 'admin-1', null, null)).rejects.toThrow(
      BadRequestException,
    );
    expect(repository.createRevealAuditLog).not.toHaveBeenCalled();
  });

  it('rejects a nonexistent OTP id', async () => {
    repository.findByIdForReveal.mockResolvedValue(null);

    await expect(service.reveal('missing', 'admin-1', null, null)).rejects.toThrow(
      NotFoundException,
    );
  });

  // #13 wrong encryption key / decryption failure handled safely
  it('returns a safe error (not a raw crypto exception) when the configured key cannot decrypt the stored ciphertext', async () => {
    const encrypted = encryptOtp('222222', ENCRYPTION_KEY);
    repository.findByIdForReveal.mockResolvedValue(
      baseRecord({
        otpCiphertext: encrypted.ciphertext,
        otpCipherIv: encrypted.iv,
        otpCipherTag: encrypted.tag,
      }),
    );
    const wrongKeyService = new AdminOtpService(
      repository,
      makeConfig(randomBytes(32).toString('hex')),
    );

    await expect(
      wrongKeyService.reveal('otp-1', 'admin-1', null, null),
    ).rejects.toThrow(InternalServerErrorException);
    expect(repository.createRevealAuditLog).not.toHaveBeenCalled();
  });

  // #14 reveal creates audit log
  it('writes an audit log entry on a successful reveal, with the correct fields', async () => {
    const encrypted = encryptOtp('333333', ENCRYPTION_KEY);
    repository.findByIdForReveal.mockResolvedValue(
      baseRecord({
        phone: '+923009998877',
        purpose: AuthOtpPurpose.WORKER_REGISTER,
        otpCiphertext: encrypted.ciphertext,
        otpCipherIv: encrypted.iv,
        otpCipherTag: encrypted.tag,
      }),
    );

    await service.reveal('otp-1', 'admin-42', '9.9.9.9', 'Mozilla/Test');

    expect(repository.createRevealAuditLog).toHaveBeenCalledWith({
      adminUserId: 'admin-42',
      authOtpId: 'otp-1',
      targetPhone: '+923009998877',
      purpose: AuthOtpPurpose.WORKER_REGISTER,
      ipAddress: '9.9.9.9',
      userAgent: 'Mozilla/Test',
    });
  });

  // #15 audit log never stores plaintext OTP
  it('never includes the plaintext OTP anywhere in the audit log payload', async () => {
    const encrypted = encryptOtp('444444', ENCRYPTION_KEY);
    repository.findByIdForReveal.mockResolvedValue(
      baseRecord({
        otpCiphertext: encrypted.ciphertext,
        otpCipherIv: encrypted.iv,
        otpCipherTag: encrypted.tag,
      }),
    );

    await service.reveal('otp-1', 'admin-1', null, null);

    const auditPayload = repository.createRevealAuditLog.mock.calls[0][0];
    expect(JSON.stringify(auditPayload)).not.toContain('444444');
  });
});

// ── AdminOtpController — pass-through ────────────────────────────────────────

describe('AdminOtpController', () => {
  it('list forwards the validated query straight to the service', async () => {
    const adminOtpService = { list: jest.fn().mockResolvedValue({ items: [], meta: {} }) };
    const controller = new AdminOtpController(adminOtpService as any);
    const query = { sinceMinutes: 60, page: 1, pageSize: 20 } as any;

    await controller.list(query);

    expect(adminOtpService.list).toHaveBeenCalledWith(query);
  });

  it('reveal forwards the id, admin id, ip, and user-agent to the service', async () => {
    const adminOtpService = {
      reveal: jest.fn().mockResolvedValue({ otp: '123456', expiresAt: new Date() }),
    };
    const controller = new AdminOtpController(adminOtpService as any);
    const req = { ip: '5.5.5.5', headers: { 'user-agent': 'test-agent' } } as any;

    await controller.reveal('otp-1', { id: 'admin-9' } as any, req);

    expect(adminOtpService.reveal).toHaveBeenCalledWith(
      'otp-1',
      'admin-9',
      '5.5.5.5',
      'test-agent',
    );
  });
});
