import { Injectable, NotFoundException } from '@nestjs/common';
import { BookingLane, ServiceAvailabilityStatus } from '@prisma/client';
import { CategoriesRepository } from './categories.repository';

export interface CategoryDto {
  id: string;
  name: string;
  description: string | null;
  iconUrl: string | null;
  inspectionFee: number | null;
  /// True when this category offers the INSPECTION lane only — the client app
  /// skips the lane picker entirely for it. See ServiceCategory.inspectionOnly.
  inspectionOnly: boolean;
  /** Additive for older clients, which safely ignore unknown response keys. */
  availabilityStatus: ServiceAvailabilityStatus;
  /// The single lane this category offers, or null when it is unrestricted.
  /// The client app renders only this lane; the rule itself is enforced
  /// server-side. See ServiceCategory.soleLane and category-lanes.ts.
  soleLane: BookingLane | null;
}

export interface StandardServiceDto {
  id: string;
  categoryId: string;
  name: string;
  description: string | null;
  price: number;
  iconUrl: string | null;
}

@Injectable()
export class CategoriesService {
  constructor(private readonly categoriesRepository: CategoriesRepository) {}

  async findAllActive(): Promise<CategoryDto[]> {
    return this.categoriesRepository.findClientVisible();
  }

  async findWorkerRegistrationEligible(): Promise<CategoryDto[]> {
    return this.categoriesRepository.findWorkerRegistrationEligible();
  }

  async findAllForAdmin() {
    const categories = await this.categoriesRepository.findAllForAdmin();
    return categories.map((category) => this._withAvailabilityLabel(category));
  }

  async updateAvailabilityStatus(
    categoryId: string,
    status: ServiceAvailabilityStatus,
  ) {
    const category = await this.categoriesRepository.findById(categoryId);
    if (!category) throw new NotFoundException('Category not found');
    const updated = await this.categoriesRepository.updateAvailabilityStatus(
      categoryId,
      status,
    );
    return this._withAvailabilityLabel(updated);
  }

  /** GET /categories/:id/standard-services — active fixed-price catalog for a category */
  async findStandardServices(
    categoryId: string,
  ): Promise<StandardServiceDto[]> {
    const category =
      await this.categoriesRepository.findStandardServiceCategory(categoryId);
    if (!category) throw new NotFoundException('Category not found');

    return this.categoriesRepository.findActiveStandardServices(categoryId);
  }

  private _withAvailabilityLabel<
    T extends { availabilityStatus: ServiceAvailabilityStatus },
  >(category: T): T & { availabilityLabel: string } {
    const labels: Record<ServiceAvailabilityStatus, string> = {
      [ServiceAvailabilityStatus.ACTIVE]: 'Active',
      [ServiceAvailabilityStatus.INACTIVE]: 'Inactive',
      [ServiceAvailabilityStatus.SOON]: 'Coming Soon',
    };
    return {
      ...category,
      availabilityLabel: labels[category.availabilityStatus],
    };
  }
}
