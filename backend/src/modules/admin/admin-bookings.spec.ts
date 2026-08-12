import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { AdminBookingsController } from './admin-bookings.controller';
import { AdminService } from './admin.service';
import { UpdateCommissionStatusDto } from './dto/update-commission-status.dto';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';

/**
 * Commission-status settlement tracking, ADMIN-only. Mirrors the metadata-
 * pinning pattern in customer-agreements.controller.spec.ts — structurally
 * proves a Worker/Client can never reach this endpoint (RolesGuard rejects
 * before the handler runs), without booting a full HTTP/JWT stack.
 */
describe('AdminBookingsController is behind Role.ADMIN', () => {
  it('Worker and Client are structurally excluded — only Role.ADMIN is allowed', () => {
    expect(Reflect.getMetadata(ROLES_KEY, AdminBookingsController)).toEqual([
      Role.ADMIN,
    ]);
  });
});

describe('UpdateCommissionStatusDto', () => {
  it('accepts PENDING', async () => {
    const dto = plainToInstance(UpdateCommissionStatusDto, { status: 'PENDING' });
    expect(await validate(dto)).toEqual([]);
  });

  it('accepts PAID', async () => {
    const dto = plainToInstance(UpdateCommissionStatusDto, { status: 'PAID' });
    expect(await validate(dto)).toEqual([]);
  });

  it('rejects any value outside PENDING/PAID', async () => {
    const dto = plainToInstance(UpdateCommissionStatusDto, { status: 'PARTIALLY_PAID' });
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'status')).toBe(true);
  });

  it('rejects a missing status', async () => {
    const dto = plainToInstance(UpdateCommissionStatusDto, {});
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'status')).toBe(true);
  });
});

describe('AdminService.updateBookingCommissionStatus', () => {
  let adminRepository: any;
  let service: AdminService;

  beforeEach(() => {
    adminRepository = {
      findCompletedBookingById: jest.fn(),
      updateBookingCommissionStatus: jest.fn(),
    };
    service = new AdminService(adminRepository, {} as any, {} as any);
  });

  it('Admin can move a completed booking to PAID', async () => {
    adminRepository.findCompletedBookingById.mockResolvedValue({
      id: 'b-1',
      status: 'COMPLETED',
    });
    adminRepository.updateBookingCommissionStatus.mockResolvedValue({
      id: 'b-1',
      commissionStatus: 'PAID',
      commissionStatusUpdatedAt: new Date(),
    });

    const result = await service.updateBookingCommissionStatus('b-1', 'PAID' as any);

    expect(adminRepository.updateBookingCommissionStatus).toHaveBeenCalledWith(
      'b-1',
      'PAID',
    );
    expect(result.commissionStatus).toBe('PAID');
  });

  it('rejects a booking that does not exist', async () => {
    adminRepository.findCompletedBookingById.mockResolvedValue(null);

    await expect(
      service.updateBookingCommissionStatus('missing', 'PAID' as any),
    ).rejects.toThrow(NotFoundException);
    expect(adminRepository.updateBookingCommissionStatus).not.toHaveBeenCalled();
  });

  it.each(['PENDING', 'ACCEPTED', 'IN_PROGRESS', 'CANCELLED', 'EXPIRED', 'REJECTED'])(
    'rejects a booking that is not COMPLETED (status=%s) — a booking still open or never finished can never become an earning/commission record',
    async (status) => {
      adminRepository.findCompletedBookingById.mockResolvedValue({
        id: 'b-1',
        status,
      });

      await expect(
        service.updateBookingCommissionStatus('b-1', 'PAID' as any),
      ).rejects.toThrow(BadRequestException);
      expect(adminRepository.updateBookingCommissionStatus).not.toHaveBeenCalled();
    },
  );

  it('updating one booking never touches another', async () => {
    adminRepository.findCompletedBookingById.mockResolvedValue({
      id: 'job-A',
      status: 'COMPLETED',
    });
    adminRepository.updateBookingCommissionStatus.mockResolvedValue({
      id: 'job-A',
      commissionStatus: 'PAID',
      commissionStatusUpdatedAt: new Date(),
    });

    await service.updateBookingCommissionStatus('job-A', 'PAID' as any);

    expect(adminRepository.updateBookingCommissionStatus).toHaveBeenCalledTimes(1);
    expect(adminRepository.updateBookingCommissionStatus).toHaveBeenCalledWith(
      'job-A',
      'PAID',
    );
    // No call ever referenced a different booking id.
    for (const call of adminRepository.updateBookingCommissionStatus.mock.calls) {
      expect(call[0]).toBe('job-A');
    }
  });
});

describe('AdminBookingsController.updateCommissionStatus', () => {
  it('forwards the path param and validated body straight to the service', async () => {
    const adminService = {
      updateBookingCommissionStatus: jest.fn().mockResolvedValue({
        id: 'b-1',
        commissionStatus: 'PAID',
        commissionStatusUpdatedAt: new Date(),
      }),
    };
    const controller = new AdminBookingsController(adminService as any);

    await controller.updateCommissionStatus('b-1', { status: 'PAID' as any });

    expect(adminService.updateBookingCommissionStatus).toHaveBeenCalledWith(
      'b-1',
      'PAID',
    );
  });
});
