import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../models/service_category_model.dart';

abstract class CategoriesRemoteDataSource {
  Future<List<ServiceCategoryModel>> getCategories();
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
}
