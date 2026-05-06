import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/bid_model.dart';

abstract class BidRemoteDataSource {
  Future<BidModel> submitBid({
    required String bookingId,
    required double amount,
    String? message,
  });

  Future<BidModel> editBid({
    required String bidId,
    required double amount,
    String? message,
  });

  Future<BidModel?> getMyBid(String bookingId);

  Future<List<BidWithWorkerModel>> getBidsForBooking(String bookingId);

  Future<BidModel> acceptBid(String bidId);
}

class BidRemoteDataSourceImpl implements BidRemoteDataSource {
  final Dio _dio;

  const BidRemoteDataSourceImpl(this._dio);

  @override
  Future<BidModel> submitBid({
    required String bookingId,
    required double amount,
    String? message,
  }) async {
    try {
      final body = <String, dynamic>{
        'amount': amount,
        if (message != null && message.isNotEmpty) 'message': message,
      };
      final response = await _dio.post('/bookings/$bookingId/bids', data: body);
      final data = response.data['data'] as Map<String, dynamic>;
      return BidModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<BidModel> editBid({
    required String bidId,
    required double amount,
    String? message,
  }) async {
    try {
      final body = <String, dynamic>{
        'amount': amount,
        if (message != null && message.isNotEmpty) 'message': message,
      };
      final response = await _dio.patch('/bids/$bidId', data: body);
      final data = response.data['data'] as Map<String, dynamic>;
      return BidModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<BidModel?> getMyBid(String bookingId) async {
    try {
      final response = await _dio.get('/bookings/$bookingId/bids/my');
      final data = response.data['data'];
      if (data == null) return null;
      return BidModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      // 404 means no bid yet — treat as null
      if (e.response?.statusCode == 404) return null;
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<List<BidWithWorkerModel>> getBidsForBooking(String bookingId) async {
    try {
      final response = await _dio.get('/bookings/$bookingId/bids');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => BidWithWorkerModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<BidModel> acceptBid(String bidId) async {
    try {
      final response = await _dio.post('/bids/$bidId/accept');
      final data = response.data['data'] as Map<String, dynamic>;
      return BidModel.fromJson(data);
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }
}

final bidRemoteDataSourceProvider = Provider<BidRemoteDataSource>((ref) {
  return BidRemoteDataSourceImpl(ref.watch(dioProvider));
});
