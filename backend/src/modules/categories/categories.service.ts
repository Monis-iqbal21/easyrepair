import { Injectable, NotFoundException } from '@nestjs/common';
import { BookingLane, ServiceAvailabilityStatus } from '@prisma/client';
import { CategoriesRepository } from './categories.repository';

export interface CategoryDto {
  id: string;
  name: string;
  description: string | null;
  iconUrl: string | null;
  inspectionFee: number | null;
  /// LEGACY INSPECTION-only flag, superseded by [soleLane] but deliberately
  /// still returned: an older APK knows only this field, and dropping it from
  /// the response would change what those builds render. Newer builds consult
  /// [soleLane] first and fall back to this. See category-lanes.ts.
  inspectionOnly: boolean;
  /// The single lane this category offers, or null to fall through to
  /// [inspectionOnly]. The client app renders only the resolved lane; the rule
  /// itself is enforced server-side. See ServiceCategory.soleLane.
  soleLane: BookingLane | null;
  /** Additive for older clients, which safely ignore unknown response keys. */
  availabilityStatus: ServiceAvailabilityStatus;
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
