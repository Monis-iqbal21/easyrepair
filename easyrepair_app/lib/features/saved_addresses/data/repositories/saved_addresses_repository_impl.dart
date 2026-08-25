import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/saved_address_entity.dart';
import '../../domain/repositories/saved_addresses_repository.dart';
import '../datasources/saved_addresses_remote_datasource.dart';

class SavedAddressesRepositoryImpl implements SavedAddressesRepository {
  final SavedAddressesRemoteDataSource _remote;

  const SavedAddressesRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<SavedAddressEntity>>> getAll() async {
    try {
      final rows = await _remote.getAll();
      return right(rows.map((row) => row.toEntity()).toList());
    } on Failure catch (failure) {
      return left(failure);
    }
  }

  @override
  Future<Either<Failure, SavedAddressEntity>> create(
    SavedAddressDraft draft,
  ) async {
    try {
      return right((await _remote.create(draft)).toEntity());
    } on Failure catch (failure) {
      return left(failure);
    }
  }

  @override
  Future<Either<Failure, SavedAddressEntity>> update(
    String id,
    SavedAddressDraft draft,
  ) async {
    try {
      return right((await _remote.update(id, draft)).toEntity());
    } on Failure catch (failure) {
      return left(failure);
    }
  }

  @override
  Future<Either<Failure, Unit>> delete(String id) async {
    try {
      await _remote.delete(id);
      return right(unit);
    } on Failure catch (failure) {
      return left(failure);
    }
  }
}
