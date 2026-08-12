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

    test(
      'carries the app-owned code and no copy when the body has no message, '
      'so the wording comes from AppLocalizations rather than this mapper',
      () {
        final failure = dioExceptionToFailure(
          _conflict({'error': 'INSPECTOR_BUSY'}),
        );

        expect(failure, isA<InspectorBusyFailure>());
        // An echo of the machine code is not a sentence — it must not leak
        // through as the user-visible message.
        expect(failure.message, isEmpty);
        expect(failure.code, FailureCode.inspectorBusy);
      },
    );

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
          _conflict({'message': '', 'error': 'PHONE_ALREADY_REGISTERED'}),
        ),
        isA<PhoneAlreadyRegisteredFailure>(),
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
