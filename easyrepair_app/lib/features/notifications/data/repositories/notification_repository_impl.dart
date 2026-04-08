import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/dio_failure_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_datasource.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDatasource _datasource;

  const NotificationRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<NotificationEntity>>> getNotifications() async {
    try {
      final models = await _datasource.getNotifications();
      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
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
      return Left(ServerFailure(e.toString()));
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
      return Left(ServerFailure(e.toString()));
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
      return Left(ServerFailure(e.toString()));
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
      return Left(ServerFailure(e.toString()));
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(
    ref.watch(notificationRemoteDatasourceProvider),
  );
});
