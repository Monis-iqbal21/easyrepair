import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export interface CategoryDto {
  id: string;
  name: string;
  description: string | null;
  iconUrl: string | null;
  inspectionFee: number | null;
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
  constructor(private readonly prisma: PrismaService) {}

  async findAllActive(): Promise<CategoryDto[]> {
    const rows = await this.prisma.serviceCategory.findMany({
      where: { isActive: true },
      orderBy: { name: 'asc' },
      select: {
        id: true,
        name: true,
        description: true,
        iconUrl: true,
        inspectionFee: true,
      },
    });
    return rows;
  }

  /** GET /categories/:id/standard-services — active fixed-price catalog for a category */
  async findStandardServices(categoryId: string): Promise<StandardServiceDto[]> {
    const category = await this.prisma.serviceCategory.findUnique({
      where: { id: categoryId },
      select: { id: true },
    });
    if (!category) throw new NotFoundException('Category not found');

    const rows = await this.prisma.standardService.findMany({
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
    return rows;
  }
}
