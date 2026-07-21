import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../bookings/data/models/booking_model.dart';
import '../models/worker_profile_model.dart';
import '../models/category_model.dart';
import '../models/worker_review_model.dart';
import '../models/agreement_template_model.dart';

abstract class WorkerRemoteDatasource {
  Future<WorkerProfileModel> getProfile();

  /// Partial update of the profile-completion text/checkbox fields.
  /// Pass only the fields being changed — omitted params are left untouched.
  Future<void> updateProfileCompletion({
    String? fullLegalName,
    String? residentialAddress,
    String? cnicNumber,
    int? experienceYears,
    bool? legalNameConfirmed,
    bool? generalAgreementAccepted,
    bool? tradeAgreementAccepted,
  });

  /// The exact text/version of the agreements the worker is about to accept
  /// — General always, Trade-specific once a main skill is selected.
  Future<List<AgreementTemplateModel>> getAgreementTemplates();

  Future<String> uploadCnicFront(File file);
  Future<String> uploadCnicBack(File file);
  Future<String> uploadLiveSelfie(File file);

  /// Validates all required fields server-side and moves the profile to
  /// SUBMITTED_FOR_REVIEW. Throws a Failure with the missing-fields message
  /// if anything required is absent.
  Future<void> submitProfileForReview();

  Future<List<Map<String, dynamic>>> getNewJobs();

  Future<Map<String, dynamic>> updateAvailability({
    required String status,
    double? lat,
    double? lng,
  });

  /// Location-only ping — never changes availabilityStatus on the server.
  Future<void> updateLocationOnly({required double lat, required double lng});

  Future<List<WorkerSkillModel>> updateSkills(List<String> categoryIds);

  Future<List<CategoryModel>> getCategories();

  Future<List<BookingModel>> getWorkerJobs(String? statusFilter);

  Future<BookingModel> getWorkerJobById(String bookingId);

  Future<BookingModel> completeWorkerJob(String bookingId);

  Future<List<WorkerReviewModel>> getWorkerReviews({int? limit});

  Future<WorkerReviewSummaryModel> getWorkerReviewSummary();
}

class WorkerRemoteDatasourceImpl implements WorkerRemoteDatasource {
  final Dio _dio;

  WorkerRemoteDatasourceImpl(this._dio);

  @override
  Future<WorkerProfileModel> getProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('/workers/profile');
    final data = response.data!['data'] as Map<String, dynamic>;
    return WorkerProfileModel.fromJson(data);
  }

  @override
  Future<List<Map<String, dynamic>>> getNewJobs() async {
    debugPrint('[NewJobs] → GET /workers/jobs/new');
    final response = await _dio.get<Map<String, dynamic>>('/workers/jobs/new');
    final data = response.data!;
    final list = (data['data'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    debugPrint('[NewJobs] ← status=${response.statusCode} raw count=${list.length}');
    for (final job in list) {
      debugPrint(
        '[NewJobs] job id=${job['id']} urgency=${job['urgency']} '
        'status=${job['status']} category=${job['category']?['name']} '
        'distanceKm=${job['distanceKm']} hasMyBid=${job['hasMyBid']}',
      );
    }
    return list;
  }

  @override
  Future<Map<String, dynamic>> updateAvailability({
    required String status,
    double? lat,
    double? lng,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (lat != null) body['lat'] = lat;
    if (lng != null) body['lng'] = lng;

    final response = await _dio.patch<Map<String, dynamic>>(
      '/workers/availability',
      data: body,
    );
    return response.data!['data'] as Map<String, dynamic>;
  }

  @override
  Future<void> updateLocationOnly({
    required double lat,
    required double lng,
  }) async {
    await _dio.patch<void>(
      '/workers/location',
      data: {'lat': lat, 'lng': lng},
    );
  }

  @override
  Future<List<WorkerSkillModel>> updateSkills(List<String> categoryIds) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/workers/skills',
      data: {'categoryIds': categoryIds},
    );
    final list = response.data!['data'] as List<dynamic>;
    return list
        .map((e) => WorkerSkillModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> updateProfileCompletion({
    String? fullLegalName,
    String? residentialAddress,
    String? cnicNumber,
    int? experienceYears,
    bool? legalNameConfirmed,
    bool? generalAgreementAccepted,
    bool? tradeAgreementAccepted,
  }) async {
    final body = <String, dynamic>{};
    if (fullLegalName != null) body['fullLegalName'] = fullLegalName;
    if (residentialAddress != null) {
      body['residentialAddress'] = residentialAddress;
    }
    if (cnicNumber != null) body['cnicNumber'] = cnicNumber;
    if (experienceYears != null) body['experienceYears'] = experienceYears;
    if (legalNameConfirmed != null) {
      body['legalNameConfirmed'] = legalNameConfirmed;
    }
    if (generalAgreementAccepted != null) {
      body['generalAgreementAccepted'] = generalAgreementAccepted;
    }
    if (tradeAgreementAccepted != null) {
      body['tradeAgreementAccepted'] = tradeAgreementAccepted;
    }
    await _dio.patch<void>('/workers/profile-completion', data: body);
  }

  @override
  Future<List<AgreementTemplateModel>> getAgreementTemplates() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/workers/profile-completion/agreement-templates',
    );
    final list = response.data!['data'] as List<dynamic>;
    return list
        .map((e) => AgreementTemplateModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> _uploadDocument(String path, File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: formData,
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    // Each endpoint returns a differently-named URL field — just take the
    // single value present.
    return data.values.first as String;
  }

  @override
  Future<String> uploadCnicFront(File file) =>
      _uploadDocument('/workers/profile-completion/cnic-front', file);

  @override
  Future<String> uploadCnicBack(File file) =>
      _uploadDocument('/workers/profile-completion/cnic-back', file);

  @override
  Future<String> uploadLiveSelfie(File file) =>
      _uploadDocument('/workers/profile-completion/selfie', file);

  @override
  Future<void> submitProfileForReview() async {
    await _dio.post<void>('/workers/profile-completion/submit');
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final response = await _dio.get<Map<String, dynamic>>('/categories');
    final list = response.data!['data'] as List<dynamic>;
    return list
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<BookingModel>> getWorkerJobs(String? statusFilter) async {
    final queryParams = <String, dynamic>{};
    if (statusFilter != null) queryParams['filter'] = statusFilter;

    final response = await _dio.get<Map<String, dynamic>>(
      '/workers/jobs',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final list = response.data!['data'] as List<dynamic>;
    return list
        .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<BookingModel> getWorkerJobById(String bookingId) async {
    debugPrint('[WorkerDatasource] getWorkerJobById called with bookingId=$bookingId');
    debugPrint('[WorkerDatasource] API endpoint: GET /workers/jobs/$bookingId');
    final response = await _dio.get<Map<String, dynamic>>(
      '/workers/jobs/$bookingId',
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    debugPrint('[WorkerDatasource] getWorkerJobById success, returned id=${data['id']} status=${data['status']}');
    final model = BookingModel.fromJson(data);
    debugPrint('[WorkerJobDetail] attachments count = ${model.attachments.length}');
    if (model.attachments.isNotEmpty) {
      debugPrint('[WorkerJobDetail] attachment types = ${model.attachments.map((a) => a.type).toList()}');
    }
    return model;
  }

  @override
  Future<BookingModel> completeWorkerJob(String bookingId) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/workers/jobs/$bookingId/complete',
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return BookingModel.fromJson(data);
  }

  @override
  Future<List<WorkerReviewModel>> getWorkerReviews({int? limit}) async {
    final queryParams = <String, dynamic>{};
    if (limit != null) queryParams['limit'] = limit;

    final response = await _dio.get<Map<String, dynamic>>(
      '/workers/reviews',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final list = response.data!['data'] as List<dynamic>;
    return list
        .map((e) => WorkerReviewModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<WorkerReviewSummaryModel> getWorkerReviewSummary() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/workers/reviews/summary',
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return WorkerReviewSummaryModel.fromJson(data);
  }
}

final workerRemoteDatasourceProvider = Provider<WorkerRemoteDatasource>((ref) {
  return WorkerRemoteDatasourceImpl(ref.watch(dioProvider));
});
