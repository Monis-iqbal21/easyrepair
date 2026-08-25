import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { ClientAddressesService } from './client-addresses.service';
import { CreateClientAddressDto } from './dto/create-client-address.dto';
import { UpdateClientAddressDto } from './dto/update-client-address.dto';

@Controller('client-addresses')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.CLIENT)
export class ClientAddressesController {
  constructor(private readonly service: ClientAddressesService) {}

  @Get()
  findAll(@CurrentUser() user: { id: string }) {
    return this.service.findAll(user.id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(
    @CurrentUser() user: { id: string },
    @Body() dto: CreateClientAddressDto,
  ) {
    return this.service.create(user.id, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Body() dto: UpdateClientAddressDto,
  ) {
    return this.service.update(user.id, id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async delete(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
  ): Promise<void> {
    await this.service.delete(user.id, id);
  }
}
