import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export interface ClientAddressWriteData {
  label: string;
  normalizedLabel: string;
  addressLine: string;
  city: string;
  latitude: number;
  longitude: number;
}

@Injectable()
export class ClientAddressesRepository {
  constructor(private readonly prisma: PrismaService) {}

  findClientProfileByUserId(userId: string) {
    return this.prisma.clientProfile.findUnique({
      where: { userId },
      select: { id: true },
    });
  }

  findAll(clientProfileId: string) {
    return this.prisma.clientAddress.findMany({
      where: { clientProfileId },
      orderBy: [{ updatedAt: 'desc' }, { label: 'asc' }],
    });
  }

  findById(clientProfileId: string, id: string) {
    return this.prisma.clientAddress.findFirst({
      where: { id, clientProfileId },
    });
  }

  findByNormalizedLabel(clientProfileId: string, normalizedLabel: string) {
    return this.prisma.clientAddress.findUnique({
      where: {
        clientProfileId_normalizedLabel: {
          clientProfileId,
          normalizedLabel,
        },
      },
    });
  }

  create(clientProfileId: string, data: ClientAddressWriteData) {
    return this.prisma.clientAddress.create({
      data: { clientProfileId, ...data },
    });
  }

  update(id: string, data: Partial<ClientAddressWriteData>) {
    return this.prisma.clientAddress.update({ where: { id }, data });
  }

  delete(id: string) {
    return this.prisma.clientAddress.delete({ where: { id } });
  }
}
