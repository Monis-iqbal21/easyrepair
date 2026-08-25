import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../data/datasources/saved_addresses_remote_datasource.dart';
import '../entities/saved_address_entity.dart';
import '../repositories/saved_addresses_repository.dart';

class SaveAddressUseCase {
  final SavedAddressesRepository _repository;
  const SaveAddressUseCase(this._repository);

  Future<Either<Failure, SavedAddressEntity>> create(SavedAddressDraft draft) =>
      _repository.create(draft);

  Future<Either<Failure, SavedAddressEntity>> update(
    String id,
    SavedAddressDraft draft,
  ) => _repository.update(id, draft);

  Future<Either<Failure, Unit>> delete(String id) => _repository.delete(id);
}
