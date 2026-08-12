import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { AdminUsersController } from './admin-users.controller';
import { AdminService } from './admin.service';
import { UpdateAccountStatusDto } from './dto/update-account-status.dto';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';

/**
 * Client account-status restriction, ADMIN-only. Mirrors the metadata-
 * pinning pattern used for AdminBookingsController — structurally proves a
 * Worker/Client can never reach this endpoint (RolesGuard rejects before the
 * handler runs), without booting a full HTTP/JWT stack.
 */
describe('AdminUsersController is behind Role.ADMIN', () => {
  it('Worker and Client are structurally excluded — only Role.ADMIN is allowed', () => {
    expect(Reflect.getMetadata(ROLES_KEY, AdminUsersController)).toEqual([
      Role.ADMIN,
    ]);
  });
});

describe('UpdateAccountStatusDto', () => {
  it('accepts ACTIVE', async () => {
    const dto = plainToInstance(UpdateAccountStatusDto, { status: 'ACTIVE' });
    expect(await validate(dto)).toEqual([]);
  });

  it('accepts SUSPENDED', async () => {
    const dto = plainToInstance(UpdateAccountStatusDto, {
      status: 'SUSPENDED',
    });
    expect(await validate(dto)).toEqual([]);
  });

  it('rejects any value outside ACTIVE/SUSPENDED (no BLOCKED/BANNED variants)', async () => {
    const dto = plainToInstance(UpdateAccountStatusDto, { status: 'BANNED' });
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'status')).toBe(true);
  });

  it('rejects a missing status', async () => {
    const dto = plainToInstance(UpdateAccountStatusDto, {});
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'status')).toBe(true);
  });
});

describe('AdminService.updateClientAccountStatus', () => {
  let adminRepository: any;
  let service: AdminService;

  beforeEach(() => {
    adminRepository = {
      findUserRoleAndStatusById: jest.fn(),
      updateAccountStatus: jest.fn(),
    };
    service = new AdminService(adminRepository, {} as any, {} as any);
  });

  it('suspends a CLIENT account', async () => {
    adminRepository.findUserRoleAndStatusById.mockResolvedValue({
      id: 'user-1',
      role: 'CLIENT',
      accountStatus: 'ACTIVE',
      deletedAt: null,
    });
    adminRepository.updateAccountStatus.mockResolvedValue({
      id: 'user-1',
      accountStatus: 'SUSPENDED',
      updatedAt: new Date(),
    });

    const result = await service.updateClientAccountStatus(
      'user-1',
      'SUSPENDED' as any,
    );

    expect(adminRepository.updateAccountStatus).toHaveBeenCalledWith(
      'user-1',
      'SUSPENDED',
    );
    expect(result.accountStatus).toBe('SUSPENDED');
  });

  it('reactivates a previously-suspended CLIENT account', async () => {
    adminRepository.findUserRoleAndStatusById.mockResolvedValue({
      id: 'user-1',
      role: 'CLIENT',
      accountStatus: 'SUSPENDED',
      deletedAt: null,
    });
    adminRepository.updateAccountStatus.mockResolvedValue({
      id: 'user-1',
      accountStatus: 'ACTIVE',
      updatedAt: new Date(),
    });

    const result = await service.updateClientAccountStatus(
      'user-1',
      'ACTIVE' as any,
    );

    expect(result.accountStatus).toBe('ACTIVE');
  });

  it('rejects a WORKER target — cannot accidentally corrupt Worker status through this endpoint', async () => {
    adminRepository.findUserRoleAndStatusById.mockResolvedValue({
      id: 'worker-user-1',
      role: 'WORKER',
      accountStatus: 'ACTIVE',
      deletedAt: null,
    });

    await expect(
      service.updateClientAccountStatus('worker-user-1', 'SUSPENDED' as any),
    ).rejects.toThrow(BadRequestException);
    expect(adminRepository.updateAccountStatus).not.toHaveBeenCalled();
  });

  it('rejects an ADMIN target', async () => {
    adminRepository.findUserRoleAndStatusById.mockResolvedValue({
      id: 'admin-user-1',
      role: 'ADMIN',
      accountStatus: 'ACTIVE',
      deletedAt: null,
    });

    await expect(
      service.updateClientAccountStatus('admin-user-1', 'SUSPENDED' as any),
    ).rejects.toThrow(BadRequestException);
    expect(adminRepository.updateAccountStatus).not.toHaveBeenCalled();
  });

  it('rejects a user that does not exist', async () => {
    adminRepository.findUserRoleAndStatusById.mockResolvedValue(null);

    await expect(
      service.updateClientAccountStatus('missing', 'SUSPENDED' as any),
    ).rejects.toThrow(NotFoundException);
    expect(adminRepository.updateAccountStatus).not.toHaveBeenCalled();
  });

  it('rejects a soft-deleted user', async () => {
    adminRepository.findUserRoleAndStatusById.mockResolvedValue({
      id: 'user-1',
      role: 'CLIENT',
      accountStatus: 'ACTIVE',
      deletedAt: new Date(),
    });

    await expect(
      service.updateClientAccountStatus('user-1', 'SUSPENDED' as any),
    ).rejects.toThrow(NotFoundException);
    expect(adminRepository.updateAccountStatus).not.toHaveBeenCalled();
  });
});

describe('AdminUsersController.updateAccountStatus', () => {
  it('forwards the path param and validated body straight to the service', async () => {
    const adminService = {
      updateClientAccountStatus: jest.fn().mockResolvedValue({
        id: 'user-1',
        accountStatus: 'SUSPENDED',
        updatedAt: new Date(),
      }),
    };
    const controller = new AdminUsersController(adminService as any);

    await controller.updateAccountStatus('user-1', {
      status: 'SUSPENDED' as any,
    });

    expect(adminService.updateClientAccountStatus).toHaveBeenCalledWith(
      'user-1',
      'SUSPENDED',
    );
  });
});
