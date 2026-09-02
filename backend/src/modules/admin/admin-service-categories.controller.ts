import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  UseGuards,
} from '@nestjs/common';
import { CategoriesService } from '../categories/categories.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';
import { UpdateServiceCategoryAvailabilityDto } from './dto/update-service-category-availability.dto';

/** Small Phase-1 admin API for the category lifecycle only; no admin UI exists. */
@Controller('admin/service-categories')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminServiceCategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  /** Returns every category, including inactive ones, for an admin selector. */
  @Get()
  findAll() {
    return this.categoriesService.findAllForAdmin();
  }

  /** Accepted labels: ACTIVE (Active), INACTIVE (Inactive), SOON (Coming Soon). */
  @Patch(':categoryId/availability-status')
  @HttpCode(HttpStatus.OK)
  updateAvailabilityStatus(
    @Param('categoryId') categoryId: string,
    @Body() dto: UpdateServiceCategoryAvailabilityDto,
  ) {
    return this.categoriesService.updateAvailabilityStatus(
      categoryId,
      dto.status,
    );
  }
}
