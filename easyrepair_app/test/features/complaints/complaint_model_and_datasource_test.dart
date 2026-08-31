import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/complaints/data/datasources/complaint_remote_datasource.dart';
import 'package:handygo_app/features/complaints/data/models/complaint_model.dart';
import 'package:handygo_app/features/complaints/domain/entities/complaint_entity.dart';

void main() {
  Map<String, dynamic> json({
    String status = 'OPEN',
    List<String> issues = const ['WORK_QUALITY', 'WARRANTY_REWORK'],
    String? otherText,
  }) =>
      {
        'id': 'complaint-1',
        'bookingId': 'booking-1',
        'reporterUserId': 'client-1',
        'reportedWorkerProfileId': 'worker-1',
        'issueTypes': issues,
        'otherText': otherText,
        'source': 'APP_CUSTOMER',
        'status': status,
        'humanRequested': false,
        'createdAt': '2026-08-27T10:00:00.000Z',
        'updatedAt': '2026-08-27T10:00:00.000Z',
      };

  test('model maps backend issue, relation, source, and status fields', () {
    final complaint = ComplaintModel.fromJson(
      json(status: 'WAITING_ON_CUSTOMER'),
    ).toEntity();

    expect(complaint.bookingId, 'booking-1');
    expect(complaint.reporterUserId, 'client-1');
    expect(complaint.reportedWorkerProfileId, 'worker-1');
    expect(complaint.source, 'APP_CUSTOMER');
    expect(complaint.status, ComplaintStatus.waitingOnCustomer);
    expect(
      complaint.issueTypes,
      [ComplaintIssueType.workQuality, ComplaintIssueType.warrantyRework],
    );
  });

  test('GET cleanly maps a null data payload to no complaint', () async {
    final dio = _dio((options) {
      expect(options.method, 'GET');
      expect(options.path, '/complaints/booking/booking-1');
      return {'success': true, 'data': null, 'message': ''};
    });

    final result = await ComplaintRemoteDataSourceImpl(dio).getForBooking(
      'booking-1',
    );
    expect(result, isNull);
  });

  // The details are the report itself, not an OTHER-only extra: the server
  // requires them for every complaint, so they always go on the wire.
  test('POST sends the details alongside predefined issues', () async {
    final dio = _dio((options) {
      expect(options.method, 'POST');
      expect(options.path, '/complaints/booking/booking-1');
      expect(options.data, {
        'issueTypes': ['WORK_QUALITY', 'WARRANTY_REWORK'],
        'otherText': 'Ustaad left the job half finished',
      });
      return {'success': true, 'data': json(), 'message': ''};
    });

    final result = await ComplaintRemoteDataSourceImpl(dio).createForBooking(
      bookingId: 'booking-1',
      issueTypes: {
        ComplaintIssueType.workQuality,
        ComplaintIssueType.warrantyRework,
      },
      otherText: '  Ustaad left the job half finished  ',
    );
    expect(result.entity.issueTypes, hasLength(2));
  });

  test('POST always sends otherText trimmed', () async {
    final dio = _dio((options) {
      expect(options.data, {
        'issueTypes': ['OTHER'],
        'otherText': 'Ceiling was marked',
      });
      return {
        'success': true,
        'data': json(issues: const ['OTHER'], otherText: 'Ceiling was marked'),
        'message': '',
      };
    });

    final result = await ComplaintRemoteDataSourceImpl(dio).createForBooking(
      bookingId: 'booking-1',
      issueTypes: {ComplaintIssueType.other},
      otherText: '  Ceiling was marked  ',
    );
    expect(result.entity.otherText, 'Ceiling was marked');
  });
}

Dio _dio(Map<String, dynamic> Function(RequestOptions) response) {
  return Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: response(options),
          ),
        ),
      ),
    );
}
