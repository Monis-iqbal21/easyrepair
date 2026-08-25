import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { CreateClientAddressDto } from './dto/create-client-address.dto';
import { UpdateClientAddressDto } from './dto/update-client-address.dto';
import {
  ClientAddressesRepository,
  ClientAddressWriteData,
} from './client-addresses.repository';

@Injectable()
export class ClientAddressesService {
  constructor(private readonly repository: ClientAddressesRepository) {}

  private cleanLabel(value: string): string {
    return value.trim().replace(/\s+/g, ' ');
  }

  private normalizeLabel(value: string): string {
    return this.cleanLabel(value).toLocaleLowerCase('en-US');
  }

  private async clientProfileId(userId: string): Promise<string> {
    const profile = await this.repository.findClientProfileByUserId(userId);
    if (!profile) throw new ForbiddenException('Client profile not found.');
    return profile.id;
  }

  private conflict(): never {
    throw new ConflictException({
      error: 'SAVED_ADDRESS_NAME_EXISTS',
      message: 'A saved address with this name already exists.',
    });
  }

  private writeData(dto: CreateClientAddressDto): ClientAddressWriteData {
    const label = this.cleanLabel(dto.label);
    return {
      label,
      normalizedLabel: this.normalizeLabel(label),
      addressLine: dto.addressLine.trim(),
      city: dto.city?.trim() ?? '',
      latitude: dto.latitude,
      longitude: dto.longitude,
    };
  }

  async findAll(userId: string) {
    return this.repository.findAll(await this.clientProfileId(userId));
  }

  async create(userId: string, dto: CreateClientAddressDto) {
    const clientProfileId = await this.clientProfileId(userId);
    const data = this.writeData(dto);
    const existing = await this.repository.findByNormalizedLabel(
      clientProfileId,
      data.normalizedLabel,
    );
    if (existing) this.conflict();

    try {
      return await this.repository.create(clientProfileId, data);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        this.conflict();
      }
      throw error;
    }
  }

  async update(userId: string, id: string, dto: UpdateClientAddressDto) {
    const clientProfileId = await this.clientProfileId(userId);
    const current = await this.repository.findById(clientProfileId, id);
    if (!current) throw new NotFoundException('Saved address not found.');

    const data: Partial<ClientAddressWriteData> = {};
    if (dto.label !== undefined) {
      data.label = this.cleanLabel(dto.label);
      data.normalizedLabel = this.normalizeLabel(data.label);
      const conflict = await this.repository.findByNormalizedLabel(
        clientProfileId,
        data.normalizedLabel,
      );
      if (conflict && conflict.id !== id) this.conflict();
    }
    if (dto.addressLine !== undefined) {
      data.addressLine = dto.addressLine.trim();
    }
    if (dto.city !== undefined) data.city = dto.city.trim();
    if (dto.latitude !== undefined) data.latitude = dto.latitude;
    if (dto.longitude !== undefined) data.longitude = dto.longitude;

    try {
      return await this.repository.update(id, data);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        this.conflict();
      }
      throw error;
    }
  }

  async delete(userId: string, id: string): Promise<void> {
    const clientProfileId = await this.clientProfileId(userId);
    const current = await this.repository.findById(clientProfileId, id);
    if (!current) throw new NotFoundException('Saved address not found.');
    await this.repository.delete(id);
  }
}
