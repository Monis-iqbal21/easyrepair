import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cached_result.dart';
import '../../../../core/errors/dio_failure_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_datasource.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDatasource _datasource;

  const NotificationRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, CachedResult<List<NotificationEntity>>>>
      getNotifications() async {
    try {
      final result = await _datasource.getNotifications();
      return Right(CachedResult(
        result.data.map((m) => m.toEntity()).toList(),
        isStale: result.isStale,
      ));
    } on Failure catch (f) {
      // fetchWithCache already mapped the DioException (and decided whether
      // cache was permitted) — pass its verdict through untouched.
      return Left(f);
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure('', code: FailureCode.unknown, diagnostic: e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getUnreadCount() async {
    try {
      final count = await _datasource.getUnreadCount();
      return Right(count);
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure('', code: FailureCode.unknown, diagnostic: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markRead(String id) async {
    try {
      await _datasource.markRead(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure('', code: FailureCode.unknown, diagnostic: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markAllRead() async {
    try {
      await _datasource.markAllRead();
      return const Right(null);
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure('', code: FailureCode.unknown, diagnostic: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveFcmToken(String token) async {
    try {
      await _datasource.saveFcmToken(token);
      return const Right(null);
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure('', code: FailureCode.unknown, diagnostic: e.toString()));
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(
    ref.watch(notificationRemoteDatasourceProvider),
  );
});
