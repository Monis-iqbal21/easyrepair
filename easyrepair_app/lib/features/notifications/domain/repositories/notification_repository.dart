import 'package:fpdart/fpdart.dart';

import '../../../../core/data/cached_result.dart';
import '../../../../core/errors/failures.dart';
import '../entities/notification_entity.dart';

abstract class NotificationRepository {
  /// Notification history, with offline read fallback to the last cached
  /// list (`CachedResult.isStale == true`) when the server is unreachable.
  Future<Either<Failure, CachedResult<List<NotificationEntity>>>>
  getNotifications();
  Future<Either<Failure, int>> getUnreadCount();
  Future<Either<Failure, void>> markRead(String id);
  Future<Either<Failure, void>> markAllRead();
  Future<Either<Failure, void>> saveFcmToken(
    String token, {
    required String locale,
  });
}
