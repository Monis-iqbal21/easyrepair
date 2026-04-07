import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/booking_entity.dart';
import '../repositories/booking_repository.dart';

class GetClientBookingsUseCase {
  final BookingRepository _repository;

  const GetClientBookingsUseCase(this._repository);

  Future<Either<Failure, List<BookingEntity>>> call() =>
      _repository.getClientBookings();
}
