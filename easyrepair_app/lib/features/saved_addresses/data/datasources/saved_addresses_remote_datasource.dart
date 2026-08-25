import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../models/saved_address_model.dart';

class SavedAddressDraft {
  final String label;
  final String addressLine;
  final String city;
  final double latitude;
  final double longitude;

  const SavedAddressDraft({
    required this.label,
    required this.addressLine,
    this.city = '',
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'addressLine': addressLine,
    'city': city,
    'latitude': latitude,
    'longitude': longitude,
  };
}

abstract class SavedAddressesRemoteDataSource {
  Future<List<SavedAddressModel>> getAll();
  Future<SavedAddressModel> create(SavedAddressDraft draft);
  Future<SavedAddressModel> update(String id, SavedAddressDraft draft);
  Future<void> delete(String id);
}

class SavedAddressesRemoteDataSourceImpl
    implements SavedAddressesRemoteDataSource {
  final Dio _dio;

  const SavedAddressesRemoteDataSourceImpl(this._dio);

  @override
  Future<List<SavedAddressModel>> getAll() async {
    try {
      final response = await _dio.get('/client-addresses');
      final data = response.data['data'] as List<dynamic>? ?? [];
      return data
          .map(
            (item) => SavedAddressModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (error) {
      throw dioExceptionToFailure(error);
    }
  }

  @override
  Future<SavedAddressModel> create(SavedAddressDraft draft) async {
    try {
      final response = await _dio.post(
        '/client-addresses',
        data: draft.toJson(),
      );
      return SavedAddressModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw dioExceptionToFailure(error);
    }
  }

  @override
  Future<SavedAddressModel> update(String id, SavedAddressDraft draft) async {
    try {
      final response = await _dio.patch(
        '/client-addresses/$id',
        data: draft.toJson(),
      );
      return SavedAddressModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw dioExceptionToFailure(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _dio.delete('/client-addresses/$id');
    } on DioException catch (error) {
      throw dioExceptionToFailure(error);
    }
  }
}
