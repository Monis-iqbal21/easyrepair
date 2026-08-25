import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../data/datasources/saved_addresses_remote_datasource.dart';
import '../entities/saved_address_entity.dart';

abstract class SavedAddressesRepository {
  Future<Either<Failure, List<SavedAddressEntity>>> getAll();
  Future<Either<Failure, SavedAddressEntity>> create(SavedAddressDraft draft);
  Future<Either<Failure, SavedAddressEntity>> update(
    String id,
    SavedAddressDraft draft,
  );
  Future<Either<Failure, Unit>> delete(String id);
}
