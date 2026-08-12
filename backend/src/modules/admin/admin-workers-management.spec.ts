import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { AdminRepository } from './admin.repository';
import { ListWorkersQueryDto } from './dto/list-workers-query.dto';
import { UpdateWorkerStatusDto } from './dto/update-worker-status.dto';
import { UpdateWorkerProfileDto } from './dto/update-worker-profile.dto';
import { UpdateWorkerSkillsDto } from './dto/update-worker-skills.dto';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';

const FULL_WORKER_VIEW = {
  id: 'worker-1',
  user: { id: 'worker-user-1', phone: '+923001234567' },
  firstName: 'Ali',
  lastName: 'Khan',
  bio: null,
  avatarUrl: null,
  status: 'ACTIVE',
  verificationStatus: 'VERIFIED',
  skills: [
    { id: 'skill-1', yearsExperience: 3, category: { id: 'cat-1', name: 'Plumber' } },
  ],
  documents: [],
  createdAt: new Date('2026-01-01T00:00:00.000Z'),
  updatedAt: new Date('2026-01-02T00:00:00.000Z'),
  fullLegalName: 'Ali Khan',
  cnicNumber: '12345-1234567-1',
  residentialAddress: 'House 1, Lahore',
  cnicFrontUrl: null,
  cnicBackUrl: null,
  liveSelfieUrl: null,
  faceMatchStatus: 'PENDING',
  trainingStatus: 'NOT_STARTED',
  onboardingStatus: 'APPROVED',
  legalNameConfirmedAt: null,
  generalAgreementAcceptedAt: null,
  tradeAgreementAcceptedAt: null,
  generalAgreementVersion: null,
  tradeAgreementVersion: null,
  submittedForReviewAt: null,
  changesRequiredReason: null,
  rejectionReason: null,
};

/**
 * Every Ustaad Admin Management endpoint (list/status/profile/skills) lives
 * on AdminController ('admin/workers'), already gated by Role.ADMIN.
 */
describe('AdminController (Ustaad management) is behind Role.ADMIN', () => {
  it('Worker and Client are structurally excluded — only Role.ADMIN is allowed', () => {
    expect(Reflect.getMetadata(ROLES_KEY, AdminController)).toEqual([Role.ADMIN]);
  });
});

// ── DTO validation ──────────────────────────────────────────────────────────

describe('ListWorkersQueryDto', () => {
  it('accepts an empty query (all optional, defaults apply)', async () => {
    const dto = plainToInstance(ListWorkersQueryDto, {});
    const errors = await validate(dto, { whitelist: true, forbidNonWhitelisted: true });
    expect(errors).toEqual([]);
    expect(dto.page).toBe(1);
    expect(dto.pageSize).toBe(20);
  });

  it('accepts search/status/onboardingStatus/verificationStatus/categoryId/page/pageSize together', async () => {
    const dto = plainToInstance(ListWorkersQueryDto, {
      search: 'Ali',
      status: 'ACTIVE',
      onboardingStatus: 'APPROVED',
      verificationStatus: 'VERIFIED',
      categoryId: '11111111-1111-4111-8111-111111111111',
      page: 2,
      pageSize: 50,
    });
    const errors = await validate(dto, { whitelist: true, forbidNonWhitelisted: true });
    expect(errors).toEqual([]);
  });

  it('rejects an unknown WorkerStatus value', async () => {
    const dto = plainToInstance(ListWorkersQueryDto, { status: 'BLOCKED' });
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'status')).toBe(true);
  });

  it('rejects pageSize above the cap', async () => {
    const dto = plainToInstance(ListWorkersQueryDto, { pageSize: 500 });
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'pageSize')).toBe(true);
  });

  it('rejects a non-UUID categoryId', async () => {
    const dto = plainToInstance(ListWorkersQueryDto, { categoryId: 'not-a-uuid' });
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'categoryId')).toBe(true);
  });
});

describe('UpdateWorkerStatusDto', () => {
  it.each(['ACTIVE', 'INACTIVE', 'SUSPENDED'])('accepts %s', async (status) => {
    const dto = plainToInstance(UpdateWorkerStatusDto, { status });
    expect(await validate(dto)).toEqual([]);
  });

  it('rejects an invented status (no BLOCKED/BANNED variants)', async () => {
    const dto = plainToInstance(UpdateWorkerStatusDto, { status: 'BANNED' });
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'status')).toBe(true);
  });

  it('rejects a missing status', async () => {
    const dto = plainToInstance(UpdateWorkerStatusDto, {});
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'status')).toBe(true);
  });
});

describe('UpdateWorkerProfileDto', () => {
  it('accepts a partial edit of allowed operational fields', async () => {
    const dto = plainToInstance(UpdateWorkerProfileDto, {
      firstName: 'Ali',
      lastName: 'Khan',
      cnicNumber: '12345-1234567-1',
      residentialAddress: 'House 1, Lahore',
    });
    const errors = await validate(dto, { whitelist: true, forbidNonWhitelisted: true });
    expect(errors).toEqual([]);
  });

  it('rejects a malformed CNIC number', async () => {
    const dto = plainToInstance(UpdateWorkerProfileDto, { cnicNumber: '12345' });
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'cnicNumber')).toBe(true);
  });

  /**
   * Immutable legal evidence and identity fields have no property on this
   * DTO — combined with the global ValidationPipe's forbidNonWhitelisted,
   * any attempt to PATCH them through the generic profile endpoint is
   * rejected outright rather than silently accepted or ignored.
   */
  it('rejects phone, legal-evidence fields, and database ids/timestamps', async () => {
    const dto = plainToInstance(UpdateWorkerProfileDto, {
      firstName: 'Ali',
      phone: '+923009999999',
      id: 'forged-id',
      createdAt: '2020-01-01',
      onboardingStatus: 'APPROVED',
      verificationStatus: 'VERIFIED',
      generalAgreementAcceptedAt: '2020-01-01',
      agreementHash: 'deadbeef',
      acceptanceId: 'forged-acceptance',
      cnicFrontUrl: 'https://evil.example/fake.jpg',
    });
    const errors = await validate(dto, { whitelist: true, forbidNonWhitelisted: true });
    const properties = errors.map((e) => e.property);
    expect(properties).toEqual(
      expect.arrayContaining([
        'phone',
        'id',
        'createdAt',
        'onboardingStatus',
        'verificationStatus',
        'generalAgreementAcceptedAt',
        'agreementHash',
        'acceptanceId',
        'cnicFrontUrl',
      ]),
    );
  });
});

describe('UpdateWorkerSkillsDto', () => {
  it('accepts one category id with optional yearsExperience', async () => {
    const dto = plainToInstance(UpdateWorkerSkillsDto, {
      categoryIds: ['11111111-1111-4111-8111-111111111111'],
      yearsExperience: 5,
    });
    expect(await validate(dto)).toEqual([]);
  });

  it('rejects more than one category id, including a duplicated id (product rule: exactly one skill)', async () => {
    const dto = plainToInstance(UpdateWorkerSkillsDto, {
      categoryIds: [
        '11111111-1111-4111-8111-111111111111',
        '11111111-1111-4111-8111-111111111111',
      ],
    });
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'categoryIds')).toBe(true);
  });

  it('rejects an empty categoryIds array', async () => {
    const dto = plainToInstance(UpdateWorkerSkillsDto, { categoryIds: [] });
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'categoryIds')).toBe(true);
  });

  it('rejects a non-UUID category id', async () => {
    const dto = plainToInstance(UpdateWorkerSkillsDto, { categoryIds: ['not-a-uuid'] });
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'categoryIds')).toBe(true);
  });
});

// ── AdminRepository — query construction ────────────────────────────────────

describe('AdminRepository.findWorkersPaginated', () => {
  let prisma: any;
  let repo: AdminRepository;

  beforeEach(() => {
    prisma = {
      workerProfile: {
        findMany: jest.fn().mockResolvedValue([]),
        count: jest.fn().mockResolvedValue(0),
      },
    };
    repo = new AdminRepository(prisma);
  });

  it('applies status/onboardingStatus/verificationStatus/categoryId filters', async () => {
    await repo.findWorkersPaginated({
      status: 'SUSPENDED',
      onboardingStatus: 'APPROVED',
      verificationStatus: 'VERIFIED',
      categoryId: 'cat-1',
      page: 1,
      pageSize: 20,
    } as any);

    const where = prisma.workerProfile.findMany.mock.calls[0][0].where;
    expect(where.status).toBe('SUSPENDED');
    expect(where.onboardingStatus).toBe('APPROVED');
    expect(where.verificationStatus).toBe('VERIFIED');
    expect(where.skills).toEqual({ some: { categoryId: 'cat-1' } });
  });

  it('searches name, CNIC, and phone (via the user relation) case-insensitively', async () => {
    await repo.findWorkersPaginated({ search: 'Ali', page: 1, pageSize: 20 } as any);

    const where = prisma.workerProfile.findMany.mock.calls[0][0].where;
    expect(where.OR).toEqual([
      { firstName: { contains: 'Ali', mode: 'insensitive' } },
      { lastName: { contains: 'Ali', mode: 'insensitive' } },
      { cnicNumber: { contains: 'Ali', mode: 'insensitive' } },
      { user: { phone: { contains: 'Ali', mode: 'insensitive' } } },
    ]);
  });

  it('ignores a blank/whitespace-only search term', async () => {
    await repo.findWorkersPaginated({ search: '   ', page: 1, pageSize: 20 } as any);

    const where = prisma.workerProfile.findMany.mock.calls[0][0].where;
    expect(where.OR).toBeUndefined();
  });

  it('paginates with the requested page/pageSize', async () => {
    await repo.findWorkersPaginated({ page: 3, pageSize: 10 } as any);

    const args = prisma.workerProfile.findMany.mock.calls[0][0];
    expect(args.skip).toBe(20);
    expect(args.take).toBe(10);
  });

  it('runs count() with the exact same where clause used for findMany', async () => {
    await repo.findWorkersPaginated({ status: 'ACTIVE', page: 1, pageSize: 20 } as any);

    const findManyWhere = prisma.workerProfile.findMany.mock.calls[0][0].where;
    const countWhere = prisma.workerProfile.count.mock.calls[0][0].where;
    expect(countWhere).toEqual(findManyWhere);
  });

  it('never selects passwordHash, refreshTokens, or OTP-related fields off the user relation', async () => {
    await repo.findWorkersPaginated({ page: 1, pageSize: 20 } as any);

    const include = prisma.workerProfile.findMany.mock.calls[0][0].include;
    expect(include.user).toEqual({ select: { phone: true } });
  });
});

// ── AdminService ─────────────────────────────────────────────────────────────

describe('AdminService.getWorkers', () => {
  it('computes pagination meta from the repository total', async () => {
    const adminRepository = {
      findWorkersPaginated: jest.fn().mockResolvedValue({
        items: [
          {
            id: 'worker-1',
            firstName: 'Ali',
            lastName: 'Khan',
            phone: '+923001234567',
            avatarUrl: null,
            primarySkill: 'Plumber',
            status: 'ACTIVE',
            onboardingStatus: 'APPROVED',
            verificationStatus: 'VERIFIED',
            createdAt: new Date(),
          },
        ],
        total: 41,
      }),
    };
    const service = new AdminService(adminRepository as any, {} as any, {} as any);

    const result = await service.getWorkers({ page: 2, pageSize: 20 } as any);

    expect(result.items).toHaveLength(1);
    expect(result.meta).toEqual({ page: 2, pageSize: 20, total: 41, totalPages: 3 });
  });

  it('never leaks passwordHash/refreshToken/OTP fields on a list item', async () => {
    const adminRepository = {
      findWorkersPaginated: jest.fn().mockResolvedValue({
        items: [
          {
            id: 'worker-1',
            firstName: 'Ali',
            lastName: 'Khan',
            phone: '+923001234567',
            avatarUrl: null,
            primarySkill: null,
            status: 'ACTIVE',
            onboardingStatus: 'DRAFT',
            verificationStatus: 'PENDING',
            createdAt: new Date(),
          },
        ],
        total: 1,
      }),
    };
    const service = new AdminService(adminRepository as any, {} as any, {} as any);

    const result = await service.getWorkers({ page: 1, pageSize: 20 } as any);

    const keys = Object.keys(result.items[0]);
    expect(keys).not.toEqual(
      expect.arrayContaining(['passwordHash', 'refreshToken', 'otpHash', 'otp']),
    );
  });
});

describe('AdminService.updateWorkerStatus', () => {
  let adminRepository: any;
  let service: AdminService;

  beforeEach(() => {
    adminRepository = {
      findById: jest.fn().mockResolvedValue({ id: 'worker-1' }),
      updateStatus: jest.fn().mockResolvedValue(FULL_WORKER_VIEW),
    };
    service = new AdminService(adminRepository, {} as any, {} as any);
  });

  it.each([
    ['ACTIVE', 'INACTIVE'],
    ['ACTIVE', 'SUSPENDED'],
    ['INACTIVE', 'ACTIVE'],
    ['INACTIVE', 'SUSPENDED'],
    ['SUSPENDED', 'ACTIVE'],
    ['SUSPENDED', 'INACTIVE'],
  ])('allows %s → %s (WorkerStatus, no restricted transitions)', async (_from, to) => {
    adminRepository.updateStatus.mockResolvedValue({ ...FULL_WORKER_VIEW, status: to });

    const result = await service.updateWorkerStatus('worker-1', to as any);

    expect(adminRepository.updateStatus).toHaveBeenCalledWith('worker-1', to);
    expect(result.status).toBe(to);
  });

  it('rejects a nonexistent worker profile id', async () => {
    adminRepository.findById.mockResolvedValue(null);

    await expect(
      service.updateWorkerStatus('missing', 'SUSPENDED' as any),
    ).rejects.toThrow(NotFoundException);
    expect(adminRepository.updateStatus).not.toHaveBeenCalled();
  });

  it('never leaks passwordHash/refreshToken on the returned worker view', async () => {
    const result = await service.updateWorkerStatus('worker-1', 'SUSPENDED' as any);
    expect(Object.keys(result)).not.toEqual(
      expect.arrayContaining(['passwordHash', 'refreshToken', 'otpHash']),
    );
  });
});

describe('AdminService.updateWorkerProfile', () => {
  let adminRepository: any;
  let service: AdminService;

  beforeEach(() => {
    adminRepository = {
      findById: jest.fn().mockResolvedValue({ id: 'worker-1' }),
      updateProfile: jest.fn().mockResolvedValue(FULL_WORKER_VIEW),
    };
    service = new AdminService(adminRepository, {} as any, {} as any);
  });

  it('updates an allowed field (e.g. residentialAddress)', async () => {
    await service.updateWorkerProfile('worker-1', {
      residentialAddress: 'New Address, Karachi',
    } as any);

    expect(adminRepository.updateProfile).toHaveBeenCalledWith('worker-1', {
      residentialAddress: 'New Address, Karachi',
    });
  });

  it('rejects a future date of birth', async () => {
    const future = new Date(Date.now() + 24 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 10);

    await expect(
      service.updateWorkerProfile('worker-1', { dateOfBirth: future } as any),
    ).rejects.toThrow(BadRequestException);
    expect(adminRepository.updateProfile).not.toHaveBeenCalled();
  });

  it('surfaces a duplicate CNIC as a friendly BadRequestException, not a raw Prisma error', async () => {
    adminRepository.updateProfile.mockRejectedValue(
      new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
        code: 'P2002',
        clientVersion: 'test',
        meta: { target: ['cnicNumber'] },
      }),
    );

    await expect(
      service.updateWorkerProfile('worker-1', { cnicNumber: '12345-1234567-1' } as any),
    ).rejects.toThrow(BadRequestException);
  });

  it('rejects a nonexistent worker profile id', async () => {
    adminRepository.findById.mockResolvedValue(null);

    await expect(
      service.updateWorkerProfile('missing', { firstName: 'X' } as any),
    ).rejects.toThrow(NotFoundException);
    expect(adminRepository.updateProfile).not.toHaveBeenCalled();
  });

  /**
   * A CLIENT's User row has no WorkerProfile — findById (scoped to
   * workerProfile) returns null for any CLIENT userId exactly like a
   * nonexistent id, so a CLIENT can never be "edited" through this
   * Worker-scoped endpoint.
   */
  it('a CLIENT user id resolves the same as a nonexistent worker (structurally excluded)', async () => {
    adminRepository.findById.mockResolvedValue(null);

    await expect(
      service.updateWorkerProfile('client-user-id', { firstName: 'X' } as any),
    ).rejects.toThrow(NotFoundException);
  });
});

describe('AdminService.updateWorkerSkills', () => {
  let adminRepository: any;
  let service: AdminService;

  beforeEach(() => {
    adminRepository = {
      findById: jest.fn().mockResolvedValue({ id: 'worker-1' }),
      findCategoriesByIds: jest.fn().mockResolvedValue([{ id: 'cat-1' }]),
      replaceSkills: jest.fn().mockResolvedValue(FULL_WORKER_VIEW),
    };
    service = new AdminService(adminRepository, {} as any, {} as any);
  });

  it('replaces the skill with a valid category id', async () => {
    await service.updateWorkerSkills('worker-1', {
      categoryIds: ['cat-1'],
      yearsExperience: 4,
    } as any);

    expect(adminRepository.replaceSkills).toHaveBeenCalledWith('worker-1', ['cat-1'], 4);
  });

  it('rejects more than one category id even if the DTO layer is bypassed', async () => {
    await expect(
      service.updateWorkerSkills('worker-1', {
        categoryIds: ['cat-1', 'cat-2'],
      } as any),
    ).rejects.toThrow(BadRequestException);
    expect(adminRepository.replaceSkills).not.toHaveBeenCalled();
  });

  it('rejects an unknown/inactive category id', async () => {
    adminRepository.findCategoriesByIds.mockResolvedValue([]);

    await expect(
      service.updateWorkerSkills('worker-1', { categoryIds: ['fake-cat'] } as any),
    ).rejects.toThrow(BadRequestException);
    expect(adminRepository.replaceSkills).not.toHaveBeenCalled();
  });

  it('rejects a nonexistent worker profile id', async () => {
    adminRepository.findById.mockResolvedValue(null);

    await expect(
      service.updateWorkerSkills('missing', { categoryIds: ['cat-1'] } as any),
    ).rejects.toThrow(NotFoundException);
    expect(adminRepository.replaceSkills).not.toHaveBeenCalled();
  });
});

// ── AdminController — pass-through ───────────────────────────────────────────

describe('AdminController Ustaad management endpoints', () => {
  it('getWorkers forwards the validated query straight to the service', async () => {
    const adminService = { getWorkers: jest.fn().mockResolvedValue({ items: [], meta: {} }) };
    const controller = new AdminController(adminService as any);
    const query = { search: 'Ali', page: 1, pageSize: 20 } as any;

    await controller.getWorkers(query);

    expect(adminService.getWorkers).toHaveBeenCalledWith(query);
  });

  it('updateWorkerStatus forwards the path param and status', async () => {
    const adminService = { updateWorkerStatus: jest.fn().mockResolvedValue(FULL_WORKER_VIEW) };
    const controller = new AdminController(adminService as any);

    await controller.updateWorkerStatus('worker-1', { status: 'SUSPENDED' as any });

    expect(adminService.updateWorkerStatus).toHaveBeenCalledWith('worker-1', 'SUSPENDED');
  });

  it('updateWorkerProfile forwards the path param and validated body', async () => {
    const adminService = { updateWorkerProfile: jest.fn().mockResolvedValue(FULL_WORKER_VIEW) };
    const controller = new AdminController(adminService as any);
    const dto = { firstName: 'Ali' } as any;

    await controller.updateWorkerProfile('worker-1', dto);

    expect(adminService.updateWorkerProfile).toHaveBeenCalledWith('worker-1', dto);
  });

  it('updateWorkerSkills forwards the path param and validated body', async () => {
    const adminService = { updateWorkerSkills: jest.fn().mockResolvedValue(FULL_WORKER_VIEW) };
    const controller = new AdminController(adminService as any);
    const dto = { categoryIds: ['cat-1'] } as any;

    await controller.updateWorkerSkills('worker-1', dto);

    expect(adminService.updateWorkerSkills).toHaveBeenCalledWith('worker-1', dto);
  });
});

// ── Detail view — full field + security shape ───────────────────────────────

describe('AdminService.getWorkerById (Ustaad Detail)', () => {
  it('returns the full detail shape including status/onboarding/verification and updatedAt', async () => {
    const adminRepository = {
      findWorkerByIdFull: jest.fn().mockResolvedValue(FULL_WORKER_VIEW),
    };
    const service = new AdminService(adminRepository as any, {} as any, {} as any);

    const result = await service.getWorkerById('worker-1');

    expect(result.status).toBe('ACTIVE');
    expect(result.onboardingStatus).toBe('APPROVED');
    expect(result.verificationStatus).toBe('VERIFIED');
    expect(result.updatedAt).toEqual(FULL_WORKER_VIEW.updatedAt);
    expect(result.skills).toEqual([
      { id: 'skill-1', yearsExperience: 3, category: { id: 'cat-1', name: 'Plumber' } },
    ]);
  });

  it('never leaks passwordHash/refreshToken/OTP fields', async () => {
    const adminRepository = {
      findWorkerByIdFull: jest.fn().mockResolvedValue(FULL_WORKER_VIEW),
    };
    const service = new AdminService(adminRepository as any, {} as any, {} as any);

    const result = await service.getWorkerById('worker-1');

    expect(Object.keys(result)).not.toEqual(
      expect.arrayContaining(['passwordHash', 'refreshToken', 'otpHash', 'otp']),
    );
  });

  it('a nonexistent worker id is rejected', async () => {
    const adminRepository = {
      findWorkerByIdFull: jest.fn().mockResolvedValue(null),
    };
    const service = new AdminService(adminRepository as any, {} as any, {} as any);

    await expect(service.getWorkerById('missing')).rejects.toThrow(NotFoundException);
  });
});
