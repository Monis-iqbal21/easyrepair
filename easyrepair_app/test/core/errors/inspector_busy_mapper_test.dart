import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/errors/dio_failure_mapper.dart';
import 'package:handygo_app/core/errors/failures.dart';

DioException _conflict(Map<String, dynamic> body) {
  final req = RequestOptions(
    path: '/bookings/child-1/inspection-report/hire-inspector',
  );
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response<Map<String, dynamic>>(
      requestOptions: req,
      statusCode: 409,
      data: body,
    ),
  );
}

void main() {
  group('INSPECTOR_BUSY mapping', () {
    const busyMessage =
        'Inspection karne wala Ustaad abhi doosre kaam mein masroof hai. '
        'Neeche se koi aur Ustaad choose karein.';

    test(
      'a 409 carrying error=INSPECTOR_BUSY maps to InspectorBusyFailure with '
      'the backend message verbatim',
      () {
        final failure = dioExceptionToFailure(
          _conflict({'message': busyMessage, 'error': 'INSPECTOR_BUSY'}),
        );

        expect(failure, isA<InspectorBusyFailure>());
        expect(failure.message, busyMessage);
      },
    );

    test('falls back to the Roman Urdu message when the body has none', () {
      final failure = dioExceptionToFailure(
        _conflict({'error': 'INSPECTOR_BUSY'}),
      );

      expect(failure, isA<InspectorBusyFailure>());
      expect(failure.message, contains('doosre kaam mein masroof hai'));
      expect(failure.message, contains('koi aur Ustaad choose karein'));
    });

    test(
      'an unrelated 409 still maps to the generic ConflictFailure, so the '
      'bidding page only special-cases the busy-inspector path',
      () {
        final failure = dioExceptionToFailure(
          _conflict({'message': 'This Ustaad just got another job.'}),
        );

        expect(failure, isA<ConflictFailure>());
        expect(failure, isNot(isA<InspectorBusyFailure>()));
      },
    );

    test('the other controlled conflict codes are unaffected', () {
      expect(
        dioExceptionToFailure(
          _conflict({'message': 'x', 'error': 'PHONE_IS_WORKER'}),
        ),
        isA<WorkerPhoneConflictFailure>(),
      );
      expect(
        dioExceptionToFailure(
          _conflict({'message': 'x', 'error': 'PHONE_IS_CLIENT'}),
        ),
        isA<ClientPhoneConflictFailure>(),
      );
    });

    test(
      'INSPECTION_LINK_MISSING surfaces as a plain conflict (no silent retry '
      'path in the app)',
      () {
        final failure = dioExceptionToFailure(
          _conflict({
            'message': 'This inspection was already closed…',
            'error': 'INSPECTION_LINK_MISSING',
          }),
        );

        expect(failure, isA<ConflictFailure>());
        expect(failure, isNot(isA<InspectorBusyFailure>()));
      },
    );
  });
}
