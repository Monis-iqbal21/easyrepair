import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export interface CategoryDto {
  id: string;
  name: string;
  description: string | null;
  iconUrl: string | null;
}

@Injectable()
export class CategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  async findAllActive(): Promise<CategoryDto[]> {
    const rows = await this.prisma.serviceCategory.findMany({
      where: { isActive: true },
      orderBy: { name: 'asc' },
      select: { id: true, name: true, description: true, iconUrl: true },
    });
    return rows;
  }
}
