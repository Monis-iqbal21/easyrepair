import 'package:dio/dio.dart';
import 'failures.dart';

Failure dioExceptionToFailure(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const NetworkFailure('Connection timeout. Please try again.');

    case DioExceptionType.badResponse:
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;

      final message = _extractMessage(data);
      final errorCode = _extractErrorCode(data);

      if (statusCode == 400) {
        return ValidationFailure(message ?? 'Invalid request');
      } else if (statusCode == 401) {
        return const UnauthorizedFailure(
          'Session expired. Please login again.',
        );
      } else if (statusCode == 409) {
        if (errorCode == 'PHONE_IS_WORKER') {
          return WorkerPhoneConflictFailure(
            message ?? 'Ye mobile number Ustaad account ke saath registered hai.',
          );
        }
        if (errorCode == 'PHONE_IS_CLIENT') {
          return ClientPhoneConflictFailure(
            message ?? 'Ye number Client account ke saath registered hai.',
          );
        }
        return ConflictFailure(message ?? 'Conflict occurred');
      } else if (statusCode == 429) {
        return ServerFailure(message ?? 'Too many requests. Please wait.');
      } else if (statusCode == 500) {
        return const ServerFailure('Server error. Try again later.');
      }

      return ServerFailure(message ?? 'Something went wrong');

    case DioExceptionType.cancel:
      return const NetworkFailure('Request cancelled');

    case DioExceptionType.unknown:
    default:
      return NetworkFailure(e.message ?? 'Unexpected error occurred');
  }
}

String? _extractMessage(dynamic data) {
  if (data is Map<String, dynamic>) {
    final message = data['message'];
    // NestJS class-validator responses send `message` as a list of strings
    // (one per failed validator) rather than a single string — join them
    // into one readable line instead of showing Dart's raw "[a, b]" list
    // formatting (or, worse, crashing a `message as String` cast).
    if (message is List) {
      final joined = message
          .where((m) => m != null)
          .map((m) => m.toString())
          .join(', ');
      if (joined.isNotEmpty) return joined;
    } else if (message != null) {
      return message.toString();
    }
    if (data['error'] != null) {
      return data['error'].toString();
    }
  }
  return null;
}

/// The backend's `error` field doubles as a machine-checkable code (e.g.
/// `PHONE_IS_WORKER`) for the handful of cases where a plain message string
/// isn't enough to drive different UI (see `GlobalExceptionFilter`, which
/// passes a thrown exception's `error` field through verbatim).
String? _extractErrorCode(dynamic data) {
  if (data is Map<String, dynamic> && data['error'] != null) {
    return data['error'].toString();
  }
  return null;
}
