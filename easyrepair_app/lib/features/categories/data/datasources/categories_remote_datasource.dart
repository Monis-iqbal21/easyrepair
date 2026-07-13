import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../models/service_category_model.dart';
import '../models/standard_service_model.dart';

abstract class CategoriesRemoteDataSource {
  Future<List<ServiceCategoryModel>> getCategories();
  Future<List<StandardServiceModel>> getStandardServices(String categoryId);
}

class CategoriesRemoteDataSourceImpl implements CategoriesRemoteDataSource {
  final Dio _dio;

  const CategoriesRemoteDataSourceImpl(this._dio);

  @override
  Future<List<ServiceCategoryModel>> getCategories() async {
    try {
      final response = await _dio.get('/categories');
      final data = response.data['data'] as List<dynamic>;
      return data
          .map((e) => ServiceCategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }

  @override
  Future<List<StandardServiceModel>> getStandardServices(
    String categoryId,
  ) async {
    try {
      final response = await _dio.get('/categories/$categoryId/standard-services');
      final data = response.data['data'] as List<dynamic>;
      return data
          .map((e) => StandardServiceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw dioExceptionToFailure(e);
    }
  }
}
