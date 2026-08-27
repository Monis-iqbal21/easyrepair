import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/complaint_entity.dart';

abstract class ComplaintRepository {
  Future<Either<Failure, ComplaintEntity?>> getForBooking(String bookingId);

  Future<Either<Failure, ComplaintEntity>> createForBooking({
    required String bookingId,
    required Set<ComplaintIssueType> issueTypes,
    String? otherText,
  });

  Future<Either<Failure, ComplaintEntity>> requestHuman(String complaintId);
}
