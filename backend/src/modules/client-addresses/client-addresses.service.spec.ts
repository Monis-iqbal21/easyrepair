import { ConflictException, NotFoundException } from '@nestjs/common';
import { ClientAddressesService } from './client-addresses.service';

describe('ClientAddressesService', () => {
  let repository: {
    findClientProfileByUserId: jest.Mock;
    findAll: jest.Mock;
    findById: jest.Mock;
    findByNormalizedLabel: jest.Mock;
    create: jest.Mock;
    update: jest.Mock;
    delete: jest.Mock;
  };
  let service: ClientAddressesService;

  const home = {
    id: 'address-home',
    clientProfileId: 'client-1',
    label: 'Home',
    normalizedLabel: 'home',
    addressLine: 'DHA Phase 6',
    city: 'Karachi',
    latitude: 24.8,
    longitude: 67.0,
  };

  beforeEach(() => {
    repository = {
      findClientProfileByUserId: jest
        .fn()
        .mockResolvedValue({ id: 'client-1' }),
      findAll: jest.fn().mockResolvedValue([]),
      findById: jest.fn().mockResolvedValue(home),
      findByNormalizedLabel: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockImplementation((_clientId, data) => ({
        ...home,
        ...data,
      })),
      update: jest.fn().mockImplementation((_id, data) => ({
        ...home,
        ...data,
      })),
      delete: jest.fn().mockResolvedValue(home),
    };
    service = new ClientAddressesService(repository as any);
  });

  it('normalizes whitespace and case on create', async () => {
    await service.create('user-1', {
      label: '  HoMe  ',
      addressLine: '  Clifton  ',
      city: ' Karachi ',
      latitude: 24.81,
      longitude: 67.03,
    });

    expect(repository.create).toHaveBeenCalledWith(
      'client-1',
      expect.objectContaining({
        label: 'HoMe',
        normalizedLabel: 'home',
        addressLine: 'Clifton',
        city: 'Karachi',
      }),
    );
  });

  it('rejects a case-insensitive duplicate create', async () => {
    repository.findByNormalizedLabel.mockResolvedValue(home);

    await expect(
      service.create('user-1', {
        label: 'HOME',
        addressLine: 'Clifton',
        latitude: 24.81,
        longitude: 67.03,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(repository.create).not.toHaveBeenCalled();
  });

  it('rejects a rename that conflicts with another saved address', async () => {
    repository.findByNormalizedLabel.mockResolvedValue({
      ...home,
      id: 'another-address',
    });

    await expect(
      service.update('user-1', home.id, { label: ' HOME ' }),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(repository.update).not.toHaveBeenCalled();
  });

  it('never deletes an address outside the current client scope', async () => {
    repository.findById.mockResolvedValue(null);

    await expect(
      service.delete('user-1', 'someone-elses-address'),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(repository.delete).not.toHaveBeenCalled();
  });

  it('deletes an owned address', async () => {
    await service.delete('user-1', home.id);
    expect(repository.delete).toHaveBeenCalledWith(home.id);
  });
});
