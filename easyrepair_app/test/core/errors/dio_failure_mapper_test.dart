import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/errors/dio_failure_mapper.dart';
import 'package:handygo_app/core/errors/failures.dart';

/// General (non-401) error-category mapping — dio_failure_mapper_401_test.dart
/// covers the 401/preserveUnauthorizedMessage branch specifically.
void main() {
  group('dioExceptionToFailure — general categories', () {
    test('connectionError maps to NetworkFailure(noInternet)', () {
      final failure = dioExceptionToFailure(
        DioException(
          requestOptions: RequestOptions(path: '/bookings/my'),
          type: DioExceptionType.connectionError,
          message: 'SocketException: Failed host lookup',
        ),
      );

      expect(failure, isA<NetworkFailure>());
      expect(failure.code, FailureCode.noInternet);
      // The technical detail is kept only for logs/diagnostics — never in
      // the field a screen ever renders.
      expect(failure.message, isEmpty);
      expect(failure.diagnostic, contains('SocketException'));
    });

    test('connectionTimeout maps to NetworkFailure(timeout)', () {
      final failure = dioExceptionToFailure(
        DioException(
          requestOptions: RequestOptions(path: '/bookings/my'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(failure, isA<NetworkFailure>());
      expect(failure.code, FailureCode.timeout);
      expect(failure.message, isEmpty);
    });

    test('receiveTimeout also maps to FailureCode.timeout', () {
      final failure = dioExceptionToFailure(
        DioException(
          requestOptions: RequestOptions(path: '/bookings/my'),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      expect(failure.code, FailureCode.timeout);
    });

    test('a 500 maps to ServerFailure(server) with no body text leaked', () {
      final req = RequestOptions(path: '/bookings/my');
      final failure = dioExceptionToFailure(
        DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response<Map<String, dynamic>>(
            requestOptions: req,
            statusCode: 500,
            data: {
              'message':
                  'PrismaClientKnownRequestError: Unique constraint failed',
            },
          ),
        ),
      );

      expect(failure, isA<ServerFailure>());
      expect(failure.code, FailureCode.server);
      // A 5xx body is never a sentence meant for a user — always discarded.
      expect(failure.message, isEmpty);
      expect(failure.message, isNot(contains('Prisma')));
    });

    test('DioExceptionType.unknown maps to NetworkFailure(unknown) and '
        'keeps the technical text only in diagnostic', () {
      final failure = dioExceptionToFailure(
        DioException(
          requestOptions: RequestOptions(path: '/bookings/my'),
          type: DioExceptionType.unknown,
          error: 'some internal exception object',
        ),
      );

      expect(failure, isA<NetworkFailure>());
      expect(failure.code, FailureCode.unknown);
      expect(failure.message, isEmpty);
      expect(failure.diagnostic, contains('some internal exception object'));
    });

    test('a machine-readable error code (all-caps) is never shown as the '
        'message even when the backend omits a human sentence', () {
      final req = RequestOptions(path: '/bookings/b1/inspection-report/find-other-ustaad');
      final failure = dioExceptionToFailure(
        DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response<Map<String, dynamic>>(
            requestOptions: req,
            statusCode: 409,
            data: {'error': 'INSPECTOR_BUSY'},
          ),
        ),
      );

      expect(failure, isA<InspectorBusyFailure>());
      // The raw code string must never leak into the rendered message.
      expect(failure.message, isNot('INSPECTOR_BUSY'));
    });

    test('OTP_RESEND_TOO_SOON maps to OtpResendTooSoonFailure and carries '
        'retryAfterSeconds so the OTP page can resume its countdown', () {
      final req = RequestOptions(path: '/auth/otp/request');
      final failure = dioExceptionToFailure(
        DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response<Map<String, dynamic>>(
            requestOptions: req,
            statusCode: 400,
            data: {
              'message': 'Thori dair intezaar karein, phir dobara code mangwayein.',
              'error': 'OTP_RESEND_TOO_SOON',
              'retryAfterSeconds': 37,
            },
          ),
        ),
      );

      expect(failure, isA<OtpResendTooSoonFailure>());
      expect(failure.code, FailureCode.otpResendTooSoon);
      expect((failure as OtpResendTooSoonFailure).retryAfterSeconds, 37);
      // The backend's own sentence is shown verbatim, not the app's fallback.
      expect(failure.message, 'Thori dair intezaar karein, phir dobara code mangwayein.');
    });

    test('OTP_RESEND_TOO_SOON without retryAfterSeconds leaves it null '
        'rather than fabricating a number', () {
      final req = RequestOptions(path: '/auth/otp/request');
      final failure = dioExceptionToFailure(
        DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response<Map<String, dynamic>>(
            requestOptions: req,
            statusCode: 400,
            data: {'error': 'OTP_RESEND_TOO_SOON'},
          ),
        ),
      );

      expect(failure, isA<OtpResendTooSoonFailure>());
      expect((failure as OtpResendTooSoonFailure).retryAfterSeconds, isNull);
    });
  });
}
