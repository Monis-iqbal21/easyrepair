import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/repositories/complaint_repository.dart';
import '../datasources/complaint_remote_datasource.dart';

class ComplaintRepositoryImpl implements ComplaintRepository {
  const ComplaintRepositoryImpl(this._dataSource);

  final ComplaintRemoteDataSource _dataSource;

  @override
  Future<Either<Failure, ComplaintEntity?>> getForBooking(
    String bookingId,
  ) async {
    try {
      final model = await _dataSource.getForBooking(bookingId);
      return Right(model?.toEntity());
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(_unknown(error));
    }
  }

  @override
  Future<Either<Failure, ComplaintEntity>> createForBooking({
    required String bookingId,
    required Set<ComplaintIssueType> issueTypes,
    String? otherText,
  }) async {
    try {
      final model = await _dataSource.createForBooking(
        bookingId: bookingId,
        issueTypes: issueTypes,
        otherText: otherText,
      );
      return Right(model.toEntity());
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(_unknown(error));
    }
  }

  @override
  Future<Either<Failure, ComplaintEntity>> requestHuman(
    String complaintId,
  ) async {
    try {
      final model = await _dataSource.requestHuman(complaintId);
      return Right(model.toEntity());
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(_unknown(error));
    }
  }

  ServerFailure _unknown(Object error) => ServerFailure(
        '',
        code: FailureCode.unknown,
        diagnostic: error.toString(),
      );
}
