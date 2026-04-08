import { PrismaService } from '../../prisma/prisma.service';
export interface CategoryDto {
    id: string;
    name: string;
    description: string | null;
    iconUrl: string | null;
}
export declare class CategoriesService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    findAllActive(): Promise<CategoryDto[]>;
}
