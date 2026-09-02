import { NotFoundException } from '@nestjs/common';
import { ServiceAvailabilityStatus } from '@prisma/client';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { AdminServiceCategoriesController } from '../admin/admin-service-categories.controller';
import { UpdateServiceCategoryAvailabilityDto } from '../admin/dto/update-service-category-availability.dto';
import { CategoriesRepository } from './categories.repository';
import { CategoriesService } from './categories.service';

const ROWS = [
  { id: 'active', availabilityStatus: ServiceAvailabilityStatus.ACTIVE },
  { id: 'inactive', availabilityStatus: ServiceAvailabilityStatus.INACTIVE },
  { id: 'soon', availabilityStatus: ServiceAvailabilityStatus.SOON },
];

describe('Service category availability lifecycle', () => {
  it('returns ACTIVE and excludes INACTIVE/SOON for Worker registration', async () => {
    const prisma = {
      serviceCategory: {
        findMany: jest.fn(({ where }: any) =>
          Promise.resolve(
            ROWS.filter(
              (row) => row.availabilityStatus === where.availabilityStatus,
            ),
          ),
        ),
      },
    };
    const repository = new CategoriesRepository(prisma as any);

    await expect(repository.findWorkerRegistrationEligible()).resolves.toEqual([
      ROWS[0],
    ]);
    expect(prisma.serviceCategory.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { availabilityStatus: ServiceAvailabilityStatus.ACTIVE },
      }),
    );
  });

  it('keeps the existing Client listing on the legacy isActive predicate', async () => {
    const prisma = {
      serviceCategory: { findMany: jest.fn().mockResolvedValue([]) },
    };
    const repository = new CategoriesRepository(prisma as any);

    await repository.findClientVisible();

    expect(prisma.serviceCategory.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { isActive: true } }),
    );
  });

  it.each([
    [ServiceAvailabilityStatus.ACTIVE, true],
    [ServiceAvailabilityStatus.INACTIVE, false],
    [ServiceAvailabilityStatus.SOON, true],
  ])(
    'admin transition to %s safely maintains the legacy mirror',
    async (status, isActive) => {
      const prisma = {
        serviceCategory: {
          update: jest.fn().mockResolvedValue({ id: 'cat-1' }),
        },
        workerSkill: { deleteMany: jest.fn(), updateMany: jest.fn() },
      };
      const repository = new CategoriesRepository(prisma as any);

      await repository.updateAvailabilityStatus('cat-1', status);

      expect(prisma.serviceCategory.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'cat-1' },
          data: { availabilityStatus: status, isActive },
        }),
      );
      expect(prisma.workerSkill.deleteMany).not.toHaveBeenCalled();
      expect(prisma.workerSkill.updateMany).not.toHaveBeenCalled();
    },
  );
});

describe('CategoriesService admin control', () => {
  it('updates an existing category and returns the repository result', async () => {
    const repository = {
      findById: jest.fn().mockResolvedValue({ id: 'cat-1' }),
      updateAvailabilityStatus: jest.fn().mockResolvedValue({
        id: 'cat-1',
        availabilityStatus: ServiceAvailabilityStatus.SOON,
      }),
    };
    const service = new CategoriesService(repository as any);

    await expect(
      service.updateAvailabilityStatus('cat-1', ServiceAvailabilityStatus.SOON),
    ).resolves.toMatchObject({
      availabilityStatus: 'SOON',
      availabilityLabel: 'Coming Soon',
    });
  });

  it('rejects a nonexistent category', async () => {
    const repository = {
      findById: jest.fn().mockResolvedValue(null),
      updateAvailabilityStatus: jest.fn(),
    };
    const service = new CategoriesService(repository as any);

    await expect(
      service.updateAvailabilityStatus(
        'missing',
        ServiceAvailabilityStatus.INACTIVE,
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(repository.updateAvailabilityStatus).not.toHaveBeenCalled();
  });
});

describe('Admin service-category status API', () => {
  it.each(['ACTIVE', 'INACTIVE', 'SOON'])('accepts %s', async (status) => {
    const dto = plainToInstance(UpdateServiceCategoryAvailabilityDto, {
      status,
    });
    expect(await validate(dto)).toEqual([]);
  });

  it('rejects an invented lifecycle value', async () => {
    const dto = plainToInstance(UpdateServiceCategoryAvailabilityDto, {
      status: 'DISABLED',
    });
    const errors = await validate(dto);
    expect(errors.some((error) => error.property === 'status')).toBe(true);
  });

  it('forwards the category and validated status to the service', async () => {
    const categoriesService = {
      updateAvailabilityStatus: jest.fn().mockResolvedValue({ id: 'cat-1' }),
    };
    const controller = new AdminServiceCategoriesController(
      categoriesService as any,
    );

    await controller.updateAvailabilityStatus('cat-1', {
      status: ServiceAvailabilityStatus.INACTIVE,
    });

    expect(categoriesService.updateAvailabilityStatus).toHaveBeenCalledWith(
      'cat-1',
      ServiceAvailabilityStatus.INACTIVE,
    );
  });
});
