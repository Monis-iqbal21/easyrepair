import { Injectable } from '@nestjs/common';
import { Prisma, ServiceAvailabilityStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

const CATEGORY_SELECT = {
  id: true,
  name: true,
  description: true,
  iconUrl: true,
  inspectionFee: true,
  inspectionOnly: true,
  availabilityStatus: true,
} satisfies Prisma.ServiceCategorySelect;

@Injectable()
export class CategoriesRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** Legacy Client surface. Keep its visibility semantics unchanged here. */
  findClientVisible() {
    return this.prisma.serviceCategory.findMany({
      where: { isActive: true },
      orderBy: { name: 'asc' },
      select: CATEGORY_SELECT,
    });
  }

  /** New Worker selection surface: lifecycle status is the sole gate. */
  findWorkerRegistrationEligible() {
    return this.prisma.serviceCategory.findMany({
      where: { availabilityStatus: ServiceAvailabilityStatus.ACTIVE },
      orderBy: { name: 'asc' },
      select: CATEGORY_SELECT,
    });
  }

  findAllForAdmin() {
    return this.prisma.serviceCategory.findMany({
      orderBy: { name: 'asc' },
      select: {
        ...CATEGORY_SELECT,
        isActive: true,
        updatedAt: true,
      },
    });
  }

  findById(id: string) {
    return this.prisma.serviceCategory.findUnique({
      where: { id },
      select: { id: true },
    });
  }

  /**
   * `isActive` remains a compatibility mirror for the existing Client list:
   * SOON stays visible there so older APKs can keep rendering their existing
   * Coming Soon tiles; INACTIVE stays hidden. New Worker code never reads it.
   */
  updateAvailabilityStatus(
    id: string,
    availabilityStatus: ServiceAvailabilityStatus,
  ) {
    return this.prisma.serviceCategory.update({
      where: { id },
      data: {
        availabilityStatus,
        isActive: availabilityStatus !== ServiceAvailabilityStatus.INACTIVE,
      },
      select: {
        ...CATEGORY_SELECT,
        isActive: true,
        updatedAt: true,
      },
    });
  }

  findStandardServiceCategory(categoryId: string) {
    return this.prisma.serviceCategory.findUnique({
      where: { id: categoryId },
      select: { id: true },
    });
  }

  findActiveStandardServices(categoryId: string) {
    return this.prisma.standardService.findMany({
      where: { categoryId, isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      select: {
        id: true,
        categoryId: true,
        name: true,
        description: true,
        price: true,
        iconUrl: true,
      },
    });
  }
}
