import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/complaint_entity.dart';
import '../models/complaint_model.dart';

abstract class ComplaintRemoteDataSource {
  Future<ComplaintModel?> getForBooking(String bookingId);

  Future<ComplaintModel> createForBooking({
    required String bookingId,
    required Set<ComplaintIssueType> issueTypes,
    String? otherText,
  });

  Future<ComplaintModel> requestHuman(String complaintId);
}

class ComplaintRemoteDataSourceImpl implements ComplaintRemoteDataSource {
  const ComplaintRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<ComplaintModel?> getForBooking(String bookingId) async {
    try {
      final response = await _dio.get('/complaints/booking/$bookingId');
      final data = _payload(response.data);
      return data == null ? null : ComplaintModel.fromJson(data);
    } on DioException catch (error) {
      throw dioExceptionToFailure(error);
    }
  }

  @override
  Future<ComplaintModel> createForBooking({
    required String bookingId,
    required Set<ComplaintIssueType> issueTypes,
    String? otherText,
  }) async {
    try {
      // `otherText` is the report itself, not an OTHER-only extra: the
      // server requires it for every complaint, so it always goes on the
      // wire. Sent trimmed to match the server's own trim-then-validate.
      final body = <String, dynamic>{
        'issueTypes': issueTypes.map((issue) => issue.apiValue).toList(),
        'otherText': otherText?.trim() ?? '',
      };
      final response = await _dio.post(
        '/complaints/booking/$bookingId',
        data: body,
      );
      return ComplaintModel.fromJson(_requiredPayload(response.data));
    } on DioException catch (error) {
      throw dioExceptionToFailure(error);
    }
  }

  @override
  Future<ComplaintModel> requestHuman(String complaintId) async {
    try {
      final response = await _dio.post('/complaints/$complaintId/human-request');
      return ComplaintModel.fromJson(_requiredPayload(response.data));
    } on DioException catch (error) {
      throw dioExceptionToFailure(error);
    }
  }

  static Map<String, dynamic>? _payload(dynamic responseData) {
    if (responseData is! Map) return null;
    final data = responseData['data'];
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  static Map<String, dynamic> _requiredPayload(dynamic responseData) =>
      _payload(responseData) ?? const <String, dynamic>{};
}
