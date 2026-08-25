import { Module } from '@nestjs/common';
import { ClientAddressesController } from './client-addresses.controller';
import { ClientAddressesRepository } from './client-addresses.repository';
import { ClientAddressesService } from './client-addresses.service';

@Module({
  controllers: [ClientAddressesController],
  providers: [ClientAddressesService, ClientAddressesRepository],
})
export class ClientAddressesModule {}
