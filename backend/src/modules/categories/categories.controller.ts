import { Controller, Get, Param } from '@nestjs/common';
import { CategoriesService } from './categories.service';

@Controller('categories')
export class CategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  /** GET /categories — returns all active service categories */
  @Get()
  findAll() {
    return this.categoriesService.findAllActive();
  }

  /** GET /categories/:id/standard-services — fixed-price catalog for a category */
  @Get(':id/standard-services')
  findStandardServices(@Param('id') categoryId: string) {
    return this.categoriesService.findStandardServices(categoryId);
  }
}
