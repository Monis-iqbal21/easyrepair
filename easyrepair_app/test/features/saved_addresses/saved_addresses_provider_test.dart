import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/features/saved_addresses/data/datasources/saved_addresses_remote_datasource.dart';
import 'package:handygo_app/features/saved_addresses/domain/entities/saved_address_entity.dart';
import 'package:handygo_app/features/saved_addresses/domain/repositories/saved_addresses_repository.dart';
import 'package:handygo_app/features/saved_addresses/presentation/providers/saved_addresses_providers.dart';

class _FakeSavedAddressesRepository implements SavedAddressesRepository {
  final List<SavedAddressEntity> rows = [];

  SavedAddressEntity _fromDraft(String id, SavedAddressDraft draft) {
    return SavedAddressEntity(
      id: id,
      label: draft.label,
      normalizedLabel: draft.label.trim().toLowerCase(),
      addressLine: draft.addressLine,
      city: draft.city,
      latitude: draft.latitude,
      longitude: draft.longitude,
    );
  }

  @override
  Future<Either<Failure, List<SavedAddressEntity>>> getAll() async =>
      right(List.of(rows));

  @override
  Future<Either<Failure, SavedAddressEntity>> create(
    SavedAddressDraft draft,
  ) async {
    final row = _fromDraft('created-${rows.length}', draft);
    rows.add(row);
    return right(row);
  }

  @override
  Future<Either<Failure, SavedAddressEntity>> update(
    String id,
    SavedAddressDraft draft,
  ) async {
    final row = _fromDraft(id, draft);
    rows
      ..removeWhere((item) => item.id == id)
      ..add(row);
    return right(row);
  }

  @override
  Future<Either<Failure, Unit>> delete(String id) async {
    rows.removeWhere((item) => item.id == id);
    return right(unit);
  }
}

void main() {
  test('empty backend state stays empty (no phantom Home/Office)', () async {
    final repository = _FakeSavedAddressesRepository();
    final container = ProviderContainer(
      overrides: [
        savedAddressesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(savedAddressesProvider.future), isEmpty);
  });

  test('create, update, and delete patch provider state immediately', () async {
    final repository = _FakeSavedAddressesRepository();
    final container = ProviderContainer(
      overrides: [
        savedAddressesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(savedAddressesProvider.future);

    final notifier = container.read(savedAddressesProvider.notifier);
    final created = await notifier.create(
      const SavedAddressDraft(
        label: 'Home',
        addressLine: 'DHA Phase 6',
        city: 'Karachi',
        latitude: 24.8,
        longitude: 67.0,
      ),
    );
    expect(container.read(savedAddressesProvider).valueOrNull, [created]);

    final updated = await notifier.updateAddress(
      created.id,
      const SavedAddressDraft(
        label: 'Home',
        addressLine: 'Clifton',
        city: 'Karachi',
        latitude: 24.81,
        longitude: 67.03,
      ),
    );
    expect(
      container.read(savedAddressesProvider).valueOrNull?.single.addressLine,
      'Clifton',
    );

    await notifier.delete(updated.id);
    expect(container.read(savedAddressesProvider).valueOrNull, isEmpty);
  });
}
