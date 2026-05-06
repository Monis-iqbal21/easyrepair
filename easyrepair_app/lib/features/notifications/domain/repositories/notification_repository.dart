import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/notification_entity.dart';

abstract class NotificationRepository {
  Future<Either<Failure, List<NotificationEntity>>> getNotifications();
  Future<Either<Failure, int>> getUnreadCount();
  Future<Either<Failure, void>> markRead(String id);
  Future<Either<Failure, void>> markAllRead();
  Future<Either<Failure, void>> saveFcmToken(String token);
}
