import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/dio_failure_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/bid_entity.dart';
import '../../domain/repositories/bid_repository.dart';
import '../datasources/bid_remote_datasource.dart';

class BidRepositoryImpl implements BidRepository {
  final BidRemoteDataSource _datasource;

  const BidRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, BidEntity>> submitBid({
    required String bookingId,
    required double amount,
    String? message,
  }) async {
    try {
      final model = await _datasource.submitBid(
        bookingId: bookingId,
        amount: amount,
        message: message,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BidEntity>> editBid({
    required String bidId,
    required double amount,
    String? message,
  }) async {
    try {
      final model = await _datasource.editBid(
        bidId: bidId,
        amount: amount,
        message: message,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BidEntity?>> getMyBid(String bookingId) async {
    try {
      final model = await _datasource.getMyBid(bookingId);
      return Right(model?.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<BidWithWorkerEntity>>> getBidsForBooking(
    String bookingId,
  ) async {
    try {
      final models = await _datasource.getBidsForBooking(bookingId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BidEntity>> acceptBid(String bidId) async {
    try {
      final model = await _datasource.acceptBid(bidId);
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
