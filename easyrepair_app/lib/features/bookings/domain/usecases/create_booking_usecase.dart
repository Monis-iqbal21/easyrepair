import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/booking_entity.dart';
import '../entities/create_booking_request.dart';
import '../repositories/booking_repository.dart';

class CreateBookingUseCase {
  final BookingRepository _repository;

  const CreateBookingUseCase(this._repository);

  Future<Either<Failure, BookingEntity>> call(CreateBookingRequest request) =>
      _repository.createBooking(request);
}
