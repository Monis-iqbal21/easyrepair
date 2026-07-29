import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

class AuthRemoteDatasource {
  final Dio _dio;

  const AuthRemoteDatasource(this._dio);

  Future<AuthResponseModel> register({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String? categoryId,
  }) async {
    final response = await _dio.post(
      '/auth/register',
      data: {
        'phone': phone,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'role': role,
        if (categoryId != null) 'categoryId': categoryId,
      },
    );
    return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthResponseModel> login({
    required String phone,
    required String password,
  }) async {
    debugPrint('[AuthDatasource] login request started for $phone');
    final response = await _dio.post(
      '/auth/login',
      data: {'phone': phone, 'password': password},
    );
    debugPrint('[AuthDatasource] login request completed');
    return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DateTime> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    final response = await _dio.post(
      '/auth/otp/request',
      data: {'phone': phone, 'purpose': purpose},
    );
    final data = response.data['data'] ?? response.data;
    return DateTime.parse(data['expiresAt'] as String);
  }

  Future<AuthResponseModel> clientOtpLogin({
    required String fullName,
    required String phone,
    required String otp,
  }) async {
    final response = await _dio.post(
      '/auth/client/otp-login',
      data: {'fullName': fullName, 'phone': phone, 'otp': otp},
    );
    return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthResponseModel> workerOtpRegister({
    required String fullName,
    required String phone,
    required String otp,
    required String password,
    required String categoryId,
  }) async {
    final response = await _dio.post(
      '/auth/worker/otp-register',
      data: {
        'fullName': fullName,
        'phone': phone,
        'otp': otp,
        'password': password,
        'categoryId': categoryId,
      },
    );
    return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthResponseModel> workerOtpLogin({
    required String phone,
    required String otp,
  }) async {
    final response = await _dio.post(
      '/auth/worker/otp-login',
      data: {'phone': phone, 'otp': otp},
    );
    return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> logout({String? refreshToken}) async {
    await _dio.post(
      '/auth/logout',
      data: refreshToken != null ? {'refreshToken': refreshToken} : null,
    );
  }

  Future<UserModel> getCurrentUser() async {
    final response = await _dio.get('/auth/me');
    final data = response.data['data'] ?? response.data;
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  Future<DateTime> forgotPasswordRequest(String phone) async {
    final response = await _dio.post(
      '/auth/forgot-password/request',
      data: {'phone': phone},
    );
    final data = response.data['data'] ?? response.data;
    return DateTime.parse(data['expiresAt'] as String);
  }

  Future<void> forgotPasswordReset({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    await _dio.post('/auth/forgot-password/reset', data: {
      'phone': phone,
      'otp': otp,
      'newPassword': newPassword,
    });
  }

  Future<void> deleteAccount() async {
    await _dio.delete('/auth/account');
  }

  Future<String> checkClientPhoneStatus(String phone) async {
    final response = await _dio.post(
      '/auth/client/phone-check',
      data: {'phone': phone},
    );
    final data = response.data['data'] ?? response.data;
    return data['status'] as String;
  }

  Future<AuthResponseModel> clientPasswordLogin({
    required String phone,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/client/password-login',
      data: {'phone': phone, 'password': password},
    );
    return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthResponseModel> clientPasswordRegister({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/client/password-register',
      data: {'fullName': fullName, 'phone': phone, 'password': password},
    );
    return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DateTime> clientForgotPasswordRequest(String phone) async {
    final response = await _dio.post(
      '/auth/client/forgot-password/request',
      data: {'phone': phone},
    );
    final data = response.data['data'] ?? response.data;
    return DateTime.parse(data['expiresAt'] as String);
  }

  Future<void> clientForgotPasswordReset({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    await _dio.post('/auth/client/forgot-password/reset', data: {
      'phone': phone,
      'otp': otp,
      'newPassword': newPassword,
    });
  }
}

final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  return AuthRemoteDatasource(ref.watch(dioProvider));
});
