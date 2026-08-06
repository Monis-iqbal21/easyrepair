import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/errors/dio_failure_mapper.dart';
import 'package:handygo_app/core/errors/failures.dart';

/// A 401 must not always mean "your session expired" — only for a
/// *protected* endpoint, where it genuinely does. For a public, pre-login
/// auth call (password login, register, OTP, reset) a 401 means the
/// credentials were rejected, and the backend's own message ("Invalid phone
/// number or password", "Account is deactivated", …) must survive to the UI.
DioException _unauthorized(String path, {String? message}) {
  final req = RequestOptions(path: path);
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response<Map<String, dynamic>>(
      requestOptions: req,
      statusCode: 401,
      data: message == null ? {} : {'message': message},
    ),
  );
}

void main() {
  group('dioExceptionToFailure — 401 handling', () {
    test(
      'defaults to discarding the message (protected-endpoint / session-'
      'expired behaviour), unchanged from before',
      () {
        final failure = _map(
          _unauthorized('/auth/me', message: 'Unauthorized'),
        );

        expect(failure, isA<UnauthorizedFailure>());
        expect(failure.message, isEmpty);
        expect(failure.code, FailureCode.unauthorized);
      },
    );

    test(
      'preserveUnauthorizedMessage: true keeps the backend sentence verbatim '
      '— wrong password',
      () {
        final failure = _map(
          _unauthorized(
            '/auth/client/password-login',
            message: 'Invalid phone number or password',
          ),
          preserveUnauthorizedMessage: true,
        );

        expect(failure, isA<UnauthorizedFailure>());
        expect(failure.message, 'Invalid phone number or password');
      },
    );

    test(
      'preserveUnauthorizedMessage: true still reports empty when the '
      'backend sent no message — never fabricates text',
      () {
        final failure = _map(
          _unauthorized('/auth/login'),
          preserveUnauthorizedMessage: true,
        );

        expect(failure, isA<UnauthorizedFailure>());
        expect(failure.message, isEmpty);
      },
    );

    test(
      'preserveUnauthorizedMessage only changes the 401 branch — a 403 is '
      'unaffected either way',
      () {
        final req = RequestOptions(path: '/auth/client/password-login');
        final err = DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response<Map<String, dynamic>>(
            requestOptions: req,
            statusCode: 403,
            data: {'message': 'Account is deactivated'},
          ),
        );

        final withPreserve = dioExceptionToFailure(
          err,
          preserveUnauthorizedMessage: true,
        );
        final withoutPreserve = dioExceptionToFailure(err);

        expect(withPreserve.message, 'Account is deactivated');
        expect(withoutPreserve.message, 'Account is deactivated');
      },
    );
  });
}

Failure _map(DioException e, {bool preserveUnauthorizedMessage = false}) =>
    dioExceptionToFailure(
      e,
      preserveUnauthorizedMessage: preserveUnauthorizedMessage,
    );
