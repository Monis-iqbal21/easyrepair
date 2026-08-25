import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/saved_address_entity.dart';
import '../repositories/saved_addresses_repository.dart';

class GetSavedAddressesUseCase {
  final SavedAddressesRepository _repository;
  const GetSavedAddressesUseCase(this._repository);

  Future<Either<Failure, List<SavedAddressEntity>>> call() =>
      _repository.getAll();
}
