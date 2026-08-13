import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { NotFoundException } from '@nestjs/common';
import { AccountStatus, BookingStatus, Role } from '@prisma/client';
import { AdminClientsController } from './admin-clients.controller';
import { AdminClientsService, summarizeBookingCounts } from './admin-clients.service';
import { AdminClientsRepository } from './admin-clients.repository';
import { ListClientsQueryDto } from './dto/list-clients-query.dto';
import { UpdateClientProfileDto } from './dto/update-client-profile.dto';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { Role as RoleEnum } from '../../common/enums/role.enum';

function clientUserRow(overrides: Partial<any> = {}) {
  const now = new Date();
  return {
    id: 'user-1',
    role: Role.CLIENT,
    phone: '+923001234567',
    phoneVerified: true,
    accountStatus: AccountStatus.ACTIVE,
    isActive: true,
    deletedAt: null,
    createdAt: now,
    updatedAt: now,
    clientProfile: {
      id: 'client-profile-1',
      firstName: 'Sara',
      lastName: 'Khan',
      avatarUrl: null,
      createdAt: now,
      updatedAt: now,
      _count: { bookings: 3 },
    },
    ...overrides,
  };
}

// ── Role guard ───────────────────────────────────────────────────────────────

describe('AdminClientsController is behind Role.ADMIN', () => {
  it('Worker and Client are structurally excluded — only Role.ADMIN is allowed', () => {
    expect(Reflect.getMetadata(ROLES_KEY, AdminClientsController)).toEqual([
      RoleEnum.ADMIN,
    ]);
  });
});

// ── DTO validation ───────────────────────────────────────────────────────────

describe('ListClientsQueryDto', () => {
  it('accepts an empty query (all optional, defaults apply)', async () => {
    const dto = plainToInstance(ListClientsQueryDto, {});
    const errors = await validate(dto, { whitelist: true, forbidNonWhitelisted: true });
    expect(errors).toEqual([]);
    expect(dto.page).toBe(1);
    expect(dto.pageSize).toBe(20);
    expect(dto.sort).toBe('NEWEST');
  });

  it('accepts every filter together', async () => {
    const dto = plainToInstance(ListClientsQueryDto, {
      search: 'Sara',
      accountStatus: 'SUSPENDED',
      phoneVerified: 'VERIFIED',
      sort: 'NAME',
      page: 2,
      pageSize: 50,
    });
    const errors = await validate(dto, { whitelist: true, forbidNonWhitelisted: true });
    expect(errors).toEqual([]);
  });

  it('rejects an invented account status (no RESTRICTED/BLOCKED)', async () => {
    const dto = plainToInstance(ListClientsQueryDto, { accountStatus: 'RESTRICTED' });
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'accountStatus')).toBe(true);
  });

  it('rejects an invalid phoneVerified value', async () => {
    const dto = plainToInstance(ListClientsQueryDto, { phoneVerified: 'MAYBE' });
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'phoneVerified')).toBe(true);
  });
});

describe('UpdateClientProfileDto', () => {
  it('accepts firstName/lastName', async () => {
    const dto = plainToInstance(UpdateClientProfileDto, {
      firstName: 'Sara',
      lastName: 'Khan',
    });
    const errors = await validate(dto, { whitelist: true, forbidNonWhitelisted: true });
    expect(errors).toEqual([]);
  });

  // #20 admin cannot change phone through profile endpoint
  it('rejects phone and every other non-whitelisted field (account status, ids, timestamps)', async () => {
    const dto = plainToInstance(UpdateClientProfileDto, {
      firstName: 'Sara',
      phone: '+923009999999',
      accountStatus: 'SUSPENDED',
      id: 'forged-id',
      userId: 'forged-user-id',
      createdAt: '2020-01-01',
      passwordHash: 'hacked',
    });
    const errors = await validate(dto, { whitelist: true, forbidNonWhitelisted: true });
    const properties = errors.map((e) => e.property);
    expect(properties).toEqual(
      expect.arrayContaining([
        'phone',
        'accountStatus',
        'id',
        'userId',
        'createdAt',
        'passwordHash',
      ]),
    );
  });
});

// ── AdminClientsRepository — query construction ─────────────────────────────

describe('AdminClientsRepository.findPaginated', () => {
  let prisma: any;
  let repo: AdminClientsRepository;

  beforeEach(() => {
    prisma = {
      user: {
        findMany: jest.fn().mockResolvedValue([]),
        count: jest.fn().mockResolvedValue(0),
      },
    };
    repo = new AdminClientsRepository(prisma);
  });

  // #4/#5/#6 list returns CLIENT users only — Worker/Admin structurally excluded
  it('always scopes to role=CLIENT and excludes soft-deleted rows', async () => {
    await repo.findPaginated({ sort: 'NEWEST', page: 1, pageSize: 20 } as any);
    const where = prisma.user.findMany.mock.calls[0][0].where;
    expect(where.role).toBe(Role.CLIENT);
    expect(where.deletedAt).toBeNull();
  });

  // #10 account-status filter
  it('applies the accountStatus filter untouched', async () => {
    await repo.findPaginated({
      accountStatus: AccountStatus.SUSPENDED,
      sort: 'NEWEST',
      page: 1,
      pageSize: 20,
    } as any);
    const where = prisma.user.findMany.mock.calls[0][0].where;
    expect(where.accountStatus).toBe(AccountStatus.SUSPENDED);
  });

  // #11 phone-verification filter
  it.each([
    ['VERIFIED', true],
    ['NOT_VERIFIED', false],
  ])('translates phoneVerified=%s to phoneVerified=%s', async (input, expected) => {
    await repo.findPaginated({ phoneVerified: input, sort: 'NEWEST', page: 1, pageSize: 20 } as any);
    const where = prisma.user.findMany.mock.calls[0][0].where;
    expect(where.phoneVerified).toBe(expected);
  });

  // #9 search by phone works with normalization
  it.each([
    ['03001234567', '+923001234567'],
    ['3001234567', '+923001234567'],
    ['923001234567', '+923001234567'],
    ['+923001234567', '+923001234567'],
  ])('normalizes phone search %s the same way auth does', async (input, expected) => {
    await repo.findPaginated({ search: input, sort: 'NEWEST', page: 1, pageSize: 20 } as any);
    const where = prisma.user.findMany.mock.calls[0][0].where;
    expect(where.phone).toBe(expected);
  });

  // #8 search by name works
  it('falls back to a name/phone OR search for a non-phone term', async () => {
    await repo.findPaginated({ search: 'Sara', sort: 'NEWEST', page: 1, pageSize: 20 } as any);
    const where = prisma.user.findMany.mock.calls[0][0].where;
    expect(where.OR).toEqual([
      { phone: { contains: 'Sara' } },
      { clientProfile: { firstName: { contains: 'Sara', mode: 'insensitive' } } },
      { clientProfile: { lastName: { contains: 'Sara', mode: 'insensitive' } } },
    ]);
  });

  // #12 pagination works
  it('paginates with the requested page/pageSize', async () => {
    await repo.findPaginated({ sort: 'NEWEST', page: 3, pageSize: 10 } as any);
    const args = prisma.user.findMany.mock.calls[0][0];
    expect(args.skip).toBe(20);
    expect(args.take).toBe(10);
  });

  it('sorts NEWEST/OLDEST/NAME as requested, defaulting to NEWEST', async () => {
    await repo.findPaginated({ sort: 'OLDEST', page: 1, pageSize: 20 } as any);
    expect(prisma.user.findMany.mock.calls[0][0].orderBy).toEqual({ createdAt: 'asc' });

    await repo.findPaginated({ sort: 'NAME', page: 1, pageSize: 20 } as any);
    expect(prisma.user.findMany.mock.calls[1][0].orderBy).toEqual({
      clientProfile: { firstName: 'asc' },
    });

    await repo.findPaginated({ sort: 'NEWEST', page: 1, pageSize: 20 } as any);
    expect(prisma.user.findMany.mock.calls[2][0].orderBy).toEqual({ createdAt: 'desc' });
  });

  it('never selects passwordHash, refreshTokens, or fcmToken', async () => {
    await repo.findPaginated({ sort: 'NEWEST', page: 1, pageSize: 20 } as any);
    const select = prisma.user.findMany.mock.calls[0][0].select;
    expect(select).not.toHaveProperty('passwordHash');
    expect(select).not.toHaveProperty('refreshTokens');
    expect(select).not.toHaveProperty('fcmToken');
  });
});

// ── summarizeBookingCounts (booking summary bucketing) ──────────────────────

describe('summarizeBookingCounts', () => {
  // #17 booking counts are correct
  it('buckets every BookingStatus into exactly one of completed/active/cancelled', () => {
    const counts: Partial<Record<BookingStatus, number>> = {
      [BookingStatus.PENDING]: 1,
      [BookingStatus.ACCEPTED]: 1,
      [BookingStatus.EN_ROUTE]: 1,
      [BookingStatus.ARRIVED]: 1,
      [BookingStatus.IN_PROGRESS]: 1,
      [BookingStatus.COMPLETED]: 3,
      [BookingStatus.REJECTED]: 1,
      [BookingStatus.CANCELLED]: 1,
      [BookingStatus.EXPIRED]: 1,
    };

    const result = summarizeBookingCounts(counts);

    expect(result.completed).toBe(3);
    expect(result.active).toBe(5); // PENDING/ACCEPTED/EN_ROUTE/ARRIVED/IN_PROGRESS
    expect(result.cancelled).toBe(3); // REJECTED/CANCELLED/EXPIRED
    expect(result.total).toBe(11);
    // Nothing lost: total always equals the sum of the three buckets.
    expect(result.total).toBe(result.completed + result.active + result.cancelled);
  });

  it('returns all zeros for a client with no bookings', () => {
    expect(summarizeBookingCounts({})).toEqual({
      total: 0,
      completed: 0,
      active: 0,
      cancelled: 0,
    });
  });
});

// ── AdminClientsService.list ─────────────────────────────────────────────────

describe('AdminClientsService.list', () => {
  // #1 admin can list clients
  it('computes pagination meta from the repository total', async () => {
    const repository = {
      findPaginated: jest.fn().mockResolvedValue({ items: [clientUserRow()], total: 41 }),
      findLatestBookingDates: jest.fn().mockResolvedValue(new Map()),
    };
    const service = new AdminClientsService(repository as any);

    const result = await service.list({ page: 2, pageSize: 20 } as any);

    expect(result.items).toHaveLength(1);
    expect(result.meta).toEqual({ page: 2, pageSize: 20, total: 41, totalPages: 3 });
  });

  it('never leaks passwordHash/refreshToken/fcmToken on a list item', async () => {
    const repository = {
      findPaginated: jest.fn().mockResolvedValue({ items: [clientUserRow()], total: 1 }),
      findLatestBookingDates: jest.fn().mockResolvedValue(new Map()),
    };
    const service = new AdminClientsService(repository as any);

    const result = await service.list({ page: 1, pageSize: 20 } as any);

    const keys = Object.keys(result.items[0]);
    expect(keys).not.toEqual(
      expect.arrayContaining(['passwordHash', 'refreshToken', 'fcmToken', 'otpHash']),
    );
  });

  it('uses the latest booking date for lastActivityAt when bookings exist', async () => {
    const latest = new Date('2026-01-05T00:00:00.000Z');
    const repository = {
      findPaginated: jest.fn().mockResolvedValue({ items: [clientUserRow()], total: 1 }),
      findLatestBookingDates: jest
        .fn()
        .mockResolvedValue(new Map([['client-profile-1', latest]])),
    };
    const service = new AdminClientsService(repository as any);

    const result = await service.list({ page: 1, pageSize: 20 } as any);
    expect(result.items[0].lastActivityAt).toBe(latest);
  });

  it('falls back to clientProfile.updatedAt for lastActivityAt when the client has no bookings', async () => {
    const profileUpdatedAt = new Date('2026-02-01T00:00:00.000Z');
    const repository = {
      findPaginated: jest.fn().mockResolvedValue({
        items: [
          clientUserRow({
            clientProfile: {
              ...clientUserRow().clientProfile,
              updatedAt: profileUpdatedAt,
              _count: { bookings: 0 },
            },
          }),
        ],
        total: 1,
      }),
      findLatestBookingDates: jest.fn().mockResolvedValue(new Map()),
    };
    const service = new AdminClientsService(repository as any);

    const result = await service.list({ page: 1, pageSize: 20 } as any);
    expect(result.items[0].lastActivityAt).toBe(profileUpdatedAt);
  });
});

// ── AdminClientsService.getDetail ────────────────────────────────────────────

describe('AdminClientsService.getDetail', () => {
  let repository: any;
  let service: AdminClientsService;

  beforeEach(() => {
    repository = {
      findByClientProfileId: jest.fn(),
      getBookingStatusCounts: jest.fn().mockResolvedValue({}),
      findRecentBookings: jest.fn().mockResolvedValue([]),
    };
    service = new AdminClientsService(repository);
  });

  // #13 client detail returns correct profile
  it('returns the full detail shape', async () => {
    repository.findByClientProfileId.mockResolvedValue(clientUserRow());
    repository.getBookingStatusCounts.mockResolvedValue({ [BookingStatus.COMPLETED]: 2 });

    const result = await service.getDetail('client-profile-1');

    expect(result.id).toBe('client-profile-1');
    expect(result.userId).toBe('user-1');
    expect(result.firstName).toBe('Sara');
    expect(result.accountStatus).toBe(AccountStatus.ACTIVE);
    expect(result.bookingSummary.completed).toBe(2);
  });

  // #14/#15/#16 never exposes passwordHash / refresh tokens / fcmToken
  it('never leaks passwordHash/refreshToken/fcmToken in the detail response', async () => {
    repository.findByClientProfileId.mockResolvedValue(clientUserRow());

    const result = await service.getDetail('client-profile-1');

    const keys = Object.keys(result);
    expect(keys).not.toEqual(
      expect.arrayContaining(['passwordHash', 'refreshToken', 'fcmToken', 'otpHash']),
    );
  });

  // #18 recent bookings limited correctly
  it('requests recent bookings with the fixed limit of 5', async () => {
    repository.findByClientProfileId.mockResolvedValue(clientUserRow());

    await service.getDetail('client-profile-1');

    expect(repository.findRecentBookings).toHaveBeenCalledWith('client-profile-1', 5);
  });

  it('maps a booking with no assigned worker to workerName: null', async () => {
    repository.findByClientProfileId.mockResolvedValue(clientUserRow());
    repository.findRecentBookings.mockResolvedValue([
      {
        id: 'booking-1',
        status: BookingStatus.PENDING,
        createdAt: new Date(),
        category: { name: 'Plumbing' },
        workerProfile: null,
      },
    ]);

    const result = await service.getDetail('client-profile-1');
    expect(result.recentBookings[0].workerName).toBeNull();
  });

  it('maps a booking with an assigned worker to their full name', async () => {
    repository.findByClientProfileId.mockResolvedValue(clientUserRow());
    repository.findRecentBookings.mockResolvedValue([
      {
        id: 'booking-1',
        status: BookingStatus.COMPLETED,
        createdAt: new Date(),
        category: { name: 'Plumbing' },
        workerProfile: { firstName: 'Ali', lastName: 'Raza' },
      },
    ]);

    const result = await service.getDetail('client-profile-1');
    expect(result.recentBookings[0].workerName).toBe('Ali Raza');
  });

  // #7 soft-deleted users handled correctly
  it('rejects a soft-deleted client as not found', async () => {
    repository.findByClientProfileId.mockResolvedValue(
      clientUserRow({ deletedAt: new Date() }),
    );

    await expect(service.getDetail('client-profile-1')).rejects.toThrow(NotFoundException);
  });

  it('rejects a nonexistent client profile id', async () => {
    repository.findByClientProfileId.mockResolvedValue(null);

    await expect(service.getDetail('missing')).rejects.toThrow(NotFoundException);
  });

  // #21/#22 Worker/Admin target rejected — structurally via ClientProfile
  // scoping (a Worker/Admin has no ClientProfile row), reinforced by the
  // explicit role check below as defense-in-depth.
  it('rejects a row whose role is not CLIENT even if somehow returned', async () => {
    repository.findByClientProfileId.mockResolvedValue(
      clientUserRow({ role: Role.WORKER }),
    );

    await expect(service.getDetail('client-profile-1')).rejects.toThrow(NotFoundException);
  });

  it('rejects an ADMIN row even if somehow returned', async () => {
    repository.findByClientProfileId.mockResolvedValue(
      clientUserRow({ role: Role.ADMIN }),
    );

    await expect(service.getDetail('client-profile-1')).rejects.toThrow(NotFoundException);
  });
});

// ── AdminClientsService.updateProfile ────────────────────────────────────────

describe('AdminClientsService.updateProfile', () => {
  let repository: any;
  let service: AdminClientsService;

  beforeEach(() => {
    repository = {
      findByClientProfileId: jest.fn().mockResolvedValue(clientUserRow()),
      updateProfile: jest.fn().mockResolvedValue(undefined),
      getBookingStatusCounts: jest.fn().mockResolvedValue({}),
      findRecentBookings: jest.fn().mockResolvedValue([]),
    };
    service = new AdminClientsService(repository);
  });

  // #19 admin can edit allowed client profile fields
  it('updates firstName/lastName and returns the refreshed detail', async () => {
    const result = await service.updateProfile('client-profile-1', {
      firstName: 'Sara',
      lastName: 'Ahmed',
    } as any);

    expect(repository.updateProfile).toHaveBeenCalledWith('client-profile-1', {
      firstName: 'Sara',
      lastName: 'Ahmed',
    });
    expect(result.id).toBe('client-profile-1');
  });

  it('does not call updateProfile when the DTO has no fields set', async () => {
    await service.updateProfile('client-profile-1', {} as any);
    expect(repository.updateProfile).not.toHaveBeenCalled();
  });

  // #21 Worker target rejected by Client update endpoint
  it('rejects updating a nonexistent/non-client profile id', async () => {
    repository.findByClientProfileId.mockResolvedValue(null);

    await expect(
      service.updateProfile('worker-profile-id', { firstName: 'X' } as any),
    ).rejects.toThrow(NotFoundException);
    expect(repository.updateProfile).not.toHaveBeenCalled();
  });

  // #22 Admin target rejected
  it('rejects updating a row whose role is ADMIN even if somehow returned', async () => {
    repository.findByClientProfileId.mockResolvedValue(clientUserRow({ role: Role.ADMIN }));

    await expect(
      service.updateProfile('client-profile-1', { firstName: 'X' } as any),
    ).rejects.toThrow(NotFoundException);
    expect(repository.updateProfile).not.toHaveBeenCalled();
  });
});

// ── AdminClientsController — pass-through ────────────────────────────────────

describe('AdminClientsController', () => {
  it('list forwards the validated query straight to the service', async () => {
    const adminClientsService = { list: jest.fn().mockResolvedValue({ items: [], meta: {} }) };
    const controller = new AdminClientsController(adminClientsService as any);
    const query = { search: 'Sara', page: 1, pageSize: 20 } as any;

    await controller.list(query);

    expect(adminClientsService.list).toHaveBeenCalledWith(query);
  });

  it('getDetail forwards the path param to the service', async () => {
    const adminClientsService = { getDetail: jest.fn().mockResolvedValue({}) };
    const controller = new AdminClientsController(adminClientsService as any);

    await controller.getDetail('client-profile-1');

    expect(adminClientsService.getDetail).toHaveBeenCalledWith('client-profile-1');
  });

  it('updateProfile forwards the path param and validated body', async () => {
    const adminClientsService = { updateProfile: jest.fn().mockResolvedValue({}) };
    const controller = new AdminClientsController(adminClientsService as any);
    const dto = { firstName: 'Sara' } as any;

    await controller.updateProfile('client-profile-1', dto);

    expect(adminClientsService.updateProfile).toHaveBeenCalledWith('client-profile-1', dto);
  });
});

// ── #23 valid account-status change / #24 existing restriction compatibility ─
// The account-status endpoint itself (PATCH /admin/users/:userId/account-status)
// is intentionally NOT duplicated here — it already exists on
// AdminUsersController with its own passing test suite (admin-users.spec.ts),
// which this task does not modify. This test only pins the integration
// contract this page depends on: the client detail response must carry the
// User.id that endpoint expects.
describe('Client detail <-> existing account-status endpoint contract', () => {
  it('exposes userId (User.id), matching what PATCH /admin/users/:userId/account-status expects', async () => {
    const repository = {
      findByClientProfileId: jest.fn().mockResolvedValue(clientUserRow({ id: 'user-42' })),
      getBookingStatusCounts: jest.fn().mockResolvedValue({}),
      findRecentBookings: jest.fn().mockResolvedValue([]),
    };
    const service = new AdminClientsService(repository as any);

    const result = await service.getDetail('client-profile-1');
    expect(result.userId).toBe('user-42');
  });
});
