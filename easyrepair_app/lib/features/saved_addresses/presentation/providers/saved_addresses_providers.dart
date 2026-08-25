import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/saved_addresses_remote_datasource.dart';
import '../../data/repositories/saved_addresses_repository_impl.dart';
import '../../domain/entities/saved_address_entity.dart';
import '../../domain/repositories/saved_addresses_repository.dart';
import '../../domain/usecases/get_saved_addresses_usecase.dart';
import '../../domain/usecases/save_address_usecase.dart';

final savedAddressesRemoteDataSourceProvider =
    Provider<SavedAddressesRemoteDataSource>((ref) {
      return SavedAddressesRemoteDataSourceImpl(ref.watch(dioProvider));
    });

final savedAddressesRepositoryProvider = Provider<SavedAddressesRepository>((
  ref,
) {
  return SavedAddressesRepositoryImpl(
    ref.watch(savedAddressesRemoteDataSourceProvider),
  );
});

final getSavedAddressesUseCaseProvider = Provider<GetSavedAddressesUseCase>((
  ref,
) {
  return GetSavedAddressesUseCase(ref.watch(savedAddressesRepositoryProvider));
});

final saveAddressUseCaseProvider = Provider<SaveAddressUseCase>((ref) {
  return SaveAddressUseCase(ref.watch(savedAddressesRepositoryProvider));
});

class SavedAddressesNotifier
    extends AutoDisposeAsyncNotifier<List<SavedAddressEntity>> {
  @override
  Future<List<SavedAddressEntity>> build() async {
    final result = await ref.read(getSavedAddressesUseCaseProvider).call();
    return result.fold((failure) => throw failure, (rows) => rows);
  }

  Future<SavedAddressEntity> create(SavedAddressDraft draft) async {
    final result = await ref.read(saveAddressUseCaseProvider).create(draft);
    return result.fold((failure) => throw failure, (created) {
      state = AsyncData([created, ...?state.valueOrNull]);
      return created;
    });
  }

  Future<SavedAddressEntity> updateAddress(
    String id,
    SavedAddressDraft draft,
  ) async {
    final result = await ref.read(saveAddressUseCaseProvider).update(id, draft);
    return result.fold((failure) => throw failure, (updated) {
      final current = state.valueOrNull ?? const <SavedAddressEntity>[];
      state = AsyncData([
        updated,
        for (final row in current)
          if (row.id != id) row,
      ]);
      return updated;
    });
  }

  Future<void> delete(String id) async {
    final result = await ref.read(saveAddressUseCaseProvider).delete(id);
    result.fold((failure) => throw failure, (_) {
      state = AsyncData([
        for (final row in state.valueOrNull ?? const <SavedAddressEntity>[])
          if (row.id != id) row,
      ]);
    });
  }
}

final savedAddressesProvider =
    AsyncNotifierProvider.autoDispose<
      SavedAddressesNotifier,
      List<SavedAddressEntity>
    >(SavedAddressesNotifier.new);
