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

      if (statusCode == 400) {
        return ValidationFailure(message ?? 'Invalid request');
      } else if (statusCode == 401) {
        return const UnauthorizedFailure(
          'Session expired. Please login again.',
        );
      } else if (statusCode == 409) {
        return ConflictFailure(message ?? 'Conflict occurred');
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
    if (data['message'] != null) {
      return data['message'].toString();
    }
    if (data['error'] != null) {
      return data['error'].toString();
    }
  }
  return null;
}
