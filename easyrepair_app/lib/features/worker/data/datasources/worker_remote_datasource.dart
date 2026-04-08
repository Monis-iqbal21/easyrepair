import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../bookings/data/models/booking_model.dart';
import '../models/worker_profile_model.dart';
import '../models/category_model.dart';
import '../models/worker_review_model.dart';

abstract class WorkerRemoteDatasource {
  Future<WorkerProfileModel> getProfile();

  Future<Map<String, dynamic>> updateAvailability({
    required String status,
    double? lat,
    double? lng,
  });

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
    final response = await _dio.get<Map<String, dynamic>>(
      '/workers/jobs/$bookingId',
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return BookingModel.fromJson(data);
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
