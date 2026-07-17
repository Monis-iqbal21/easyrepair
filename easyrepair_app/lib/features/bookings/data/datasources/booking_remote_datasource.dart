import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/create_booking_request.dart';
import '../../domain/entities/inspection_report_entity.dart';
import '../../domain/entities/update_booking_request.dart';
import '../models/booking_model.dart';
import '../models/inspection_report_model.dart';
import '../models/nearby_worker_model.dart';

abstract class BookingRemoteDataSource {
  Future<BookingModel> createBooking(CreateBookingRequest request);
  Future<List<BookingModel>> getClientBookings();
  Future<BookingModel> getBookingById(String bookingId);
  Future<BookingModel> updateBooking(UpdateBookingRequest request);
  Future<BookingModel> cancelBooking(String bookingId);
  Future<BookingModel> submitReview(ReviewRequest request);
  Future<BookingAttachmentModel> uploadAttachment(
    String bookingId,
    File file,
    String mimeType, {
    double? durationSeconds,
  });
  Future<void> deleteAttachment(String bookingId, String attachmentId);
  Future<NearbyWorkersResultModel> getNearbyWorkers(
    String bookingId, {
    double? radiusKm,
  });
  Future<BookingModel> assignWorker(String bookingId, String workerProfileId);

  /// Client "Make Live Again" on an EXPIRED booking.
  Future<BookingModel> relistBooking(String bookingId);

  // ── Worker lifecycle (assigned worker only) ─────────────────────────────
  Future<BookingModel> markOnMyWay(String bookingId);
  Future<BookingModel> markArrived(String bookingId);
  Future<BookingModel> startJob(String bookingId);
  Future<BookingModel> completeJobLifecycle(String bookingId);
  Future<BookingModel> workerCancelBooking(String bookingId, String reason);

  // ── Inspection report (INSPECTION lane) ─────────────────────────────────
  Future<InspectionReportModel> submitInspectionReport(
    String bookingId, {
    String? issueFound,
    String? recommendedRepair,
    required double labourCost,
    required bool partsNeeded,
    required List<InspectionReportPartDraft> parts,
    String? notes,
    required List<File> photos,
    File? voiceNoteFile,
    double? voiceNoteDurationSeconds,
  });
  Future<InspectionReportModel> getInspectionReport(String bookingId);
  Future<BookingModel> acceptInspectionQuote(String bookingId);
  Future<BookingModel> closeAfterInspection(String bookingId);
}

class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  final Dio _dio;

  const BookingRemoteDataSourceImpl(this._dio);

  @override
  Future<BookingModel> createBooking(CreateBookingRequest request) async {
    try {
      final body = <String, dynamic>{
        'serviceCategory': request.serviceCategory,
        'urgency': request.urgency.apiValue,
        'addressLine': request.addressLine,
        if (request.latitude != null) 'latitude': request.latitude,
        if (request.longitude != null) 'longitude': request.longitude,
        if (request.city != null && request.city!.isNotEmpty)
          'city': request.city,
        if (request.timeSlot != null) 'timeSlot': request.timeSlot!.apiValue,
        if (request.urgentWindow != null)
          'urgentWindow': request.urgentWindow!.apiValue,
        if (request.scheduledAt != null)
          'scheduledAt': request.scheduledAt!.toIso8601String(),
        if (request.title != null && request.title!.isNotEmpty)
          'title': request.title,
        if (request.description != null && request.description!.isNotEmpty)
          'description': request.description,
        'inspection': request.inspection,
        'lane': request.lane.raw,
        if (request.standardServiceIds.isNotEmpty)
          'standardServiceIds': request.standardServiceIds
        else if (request.standardServiceId != null)
          'standardServiceId': request.standardServiceId,
      };

      final response = await _dio.post('/bookings', data: body);
      final data = response.data['data'] as Map<String, dynamic>;
      return BookingModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<List<BookingModel>> getClientBookings() async {
    try {
      final response = await _dio.get('/bookings/my');
      final data = response.data['data'] as List<dynamic>;
      return data
          .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<BookingModel> getBookingById(String bookingId) async {
    try {
      final response = await _dio.get('/bookings/$bookingId');
      final data = response.data['data'] as Map<String, dynamic>;
      return BookingModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<BookingModel> updateBooking(UpdateBookingRequest request) async {
    try {
      final body = <String, dynamic>{
        if (request.serviceCategory != null)
          'serviceCategory': request.serviceCategory,
        if (request.title != null) 'title': request.title,
        if (request.description != null) 'description': request.description,
        if (request.urgency != null) 'urgency': request.urgency!.apiValue,
        if (request.timeSlot != null) 'timeSlot': request.timeSlot!.apiValue,
        if (request.urgentWindow != null)
          'urgentWindow': request.urgentWindow!.apiValue,
        if (request.scheduledAt != null)
          'scheduledAt': request.scheduledAt!.toIso8601String(),
        if (request.addressLine != null) 'addressLine': request.addressLine,
        if (request.city != null) 'city': request.city,
        if (request.latitude != null) 'latitude': request.latitude,
        if (request.longitude != null) 'longitude': request.longitude,
        if (request.inspection != null) 'inspection': request.inspection,
        if (request.standardServiceIds != null)
          'standardServiceIds': request.standardServiceIds,
      };
      final response = await _dio.patch('/bookings/${request.bookingId}', data: body);
      final data = response.data['data'] as Map<String, dynamic>;
      return BookingModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<BookingModel> cancelBooking(String bookingId) async {
    try {
      final response = await _dio.patch('/bookings/$bookingId/cancel');
      final data = response.data['data'] as Map<String, dynamic>;
      return BookingModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<BookingModel> submitReview(ReviewRequest request) async {
    try {
      final body = <String, dynamic>{
        'rating': request.rating,
        if (request.comment != null && request.comment!.isNotEmpty)
          'comment': request.comment,
      };
      final response =
          await _dio.post('/bookings/${request.bookingId}/review', data: body);
      final data = response.data['data'] as Map<String, dynamic>;
      return BookingModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<BookingAttachmentModel> uploadAttachment(
    String bookingId,
    File file,
    String mimeType, {
    double? durationSeconds,
  }) async {
    try {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
        if (durationSeconds != null) 'durationSeconds': durationSeconds.toString(),
      });
      final response = await _dio.post(
        '/bookings/$bookingId/attachments',
        data: formData,
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return BookingAttachmentModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<void> deleteAttachment(String bookingId, String attachmentId) async {
    try {
      await _dio.delete('/bookings/$bookingId/attachments/$attachmentId');
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<NearbyWorkersResultModel> getNearbyWorkers(
    String bookingId, {
    double? radiusKm,
  }) async {
    try {
      final response = await _dio.get(
        '/bookings/$bookingId/nearby-workers',
        queryParameters: radiusKm != null ? {'radiusKm': radiusKm} : null,
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return NearbyWorkersResultModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<BookingModel> assignWorker(
    String bookingId,
    String workerProfileId,
  ) async {
    try {
      final response = await _dio.post(
        '/bookings/$bookingId/assign',
        data: {'workerProfileId': workerProfileId},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return BookingModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<BookingModel> relistBooking(String bookingId) async {
    try {
      final response = await _dio.patch('/bookings/$bookingId/relist');
      final data = response.data['data'] as Map<String, dynamic>;
      return BookingModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<BookingModel> markOnMyWay(String bookingId) async {
    try {
      final response = await _dio.post('/bookings/$bookingId/on-my-way');
      final data = response.data['data'] as Map<String, dynamic>;
      return BookingModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<BookingModel> markArrived(String bookingId) async {
    try {
      final response = await _dio.post('/bookings/$bookingId/arrived');
      final data = response.data['data'] as Map<String, dynamic>;
      return BookingModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<BookingModel> startJob(String bookingId) async {
    try {
      final response = await _dio.post('/bookings/$bookingId/start');
      final data = response.data['data'] as Map<String, dynamic>;
      return BookingModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<BookingModel> completeJobLifecycle(String bookingId) async {
    try {
      final response = await _dio.post('/bookings/$bookingId/complete');
      final data = response.data['data'] as Map<String, dynamic>;
      return BookingModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<BookingModel> workerCancelBooking(
    String bookingId,
    String reason,
  ) async {
    try {
      final response = await _dio.post(
        '/bookings/$bookingId/worker-cancel',
        data: {'reason': reason},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return BookingModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<InspectionReportModel> submitInspectionReport(
    String bookingId, {
    String? issueFound,
    String? recommendedRepair,
    required double labourCost,
    required bool partsNeeded,
    required List<InspectionReportPartDraft> parts,
    String? notes,
    required List<File> photos,
    File? voiceNoteFile,
    double? voiceNoteDurationSeconds,
  }) async {
    try {
      final payload = {
        if (issueFound != null && issueFound.isNotEmpty) 'issueFound': issueFound,
        if (recommendedRepair != null && recommendedRepair.isNotEmpty)
          'recommendedRepair': recommendedRepair,
        'labourCost': labourCost,
        'partsNeeded': partsNeeded,
        'parts': parts
            .map((p) => {
                  'name': p.name,
                  'quantity': p.quantity,
                  'unitPrice': p.unitPrice,
                  if (p.warranty != null && p.warranty!.isNotEmpty)
                    'warranty': p.warranty,
                })
            .toList(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (voiceNoteFile != null && voiceNoteDurationSeconds != null)
          'voiceNoteDurationSeconds': voiceNoteDurationSeconds,
      };
      final formData = FormData.fromMap({
        'payload': jsonEncode(payload),
        'photos': await Future.wait(
          photos.map(
            (file) => MultipartFile.fromFile(
              file.path,
              filename: file.path.split('/').last,
            ),
          ),
        ),
        if (voiceNoteFile != null)
          'voiceNote': await MultipartFile.fromFile(
            voiceNoteFile.path,
            filename: voiceNoteFile.path.split('/').last,
            contentType: DioMediaType.parse('audio/x-m4a'),
          ),
      });
      final response = await _dio.post(
        '/bookings/$bookingId/inspection-report',
        data: formData,
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return InspectionReportModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<InspectionReportModel> getInspectionReport(String bookingId) async {
    try {
      final response = await _dio.get('/bookings/$bookingId/inspection-report');
      final data = response.data['data'] as Map<String, dynamic>;
      return InspectionReportModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<BookingModel> acceptInspectionQuote(String bookingId) async {
    try {
      await _dio.post('/bookings/$bookingId/inspection-report/accept');
      // The accept endpoint returns the report DTO, not the booking — re-fetch
      // the booking so the caller gets the updated lane/status fields.
      return getBookingById(bookingId);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<BookingModel> closeAfterInspection(String bookingId) async {
    try {
      await _dio.post('/bookings/$bookingId/inspection-report/close');
      return getBookingById(bookingId);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }
}

extension BookingUrgencyApiMapper on BookingUrgency {
  String get apiValue {
    switch (this) {
      case BookingUrgency.urgent:
        return 'URGENT';
      case BookingUrgency.normal:
        return 'NORMAL';
    }
  }
}

extension TimeSlotApiMapper on TimeSlot {
  String get apiValue {
    switch (this) {
      case TimeSlot.morning:
        return 'MORNING';
      case TimeSlot.afternoon:
        return 'AFTERNOON';
      case TimeSlot.evening:
        return 'EVENING';
      case TimeSlot.night:
        return 'NIGHT';
    }
  }
}

extension UrgentWindowApiMapper on UrgentWindow {
  String get apiValue {
    switch (this) {
      case UrgentWindow.within1Hour:
        return 'WITHIN_1_HOUR';
      case UrgentWindow.within2Hours:
        return 'WITHIN_2_HOURS';
      case UrgentWindow.within4Hours:
        return 'WITHIN_4_HOURS';
    }
  }
}
