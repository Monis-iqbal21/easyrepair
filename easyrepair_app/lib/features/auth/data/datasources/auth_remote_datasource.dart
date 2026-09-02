import 'package:dio/dio.dart';
import '../../domain/entities/auth_tokens_entity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

class AuthRemoteDatasource {
  /// No [AuthInterceptor] — used for every public, pre-login endpoint below
  /// (login, register, OTP, password reset, phone-check) so none of them
  /// ever carries a stale Authorization header or gets its 401 mistaken for
  /// an expired session. See `publicDioProvider`'s doc comment.
  final Dio _publicDio;

  /// Authenticated client — only for the genuinely protected endpoints
  /// (`/auth/logout`, `/auth/me`, `/auth/account`).
  final Dio _dio;

  const AuthRemoteDatasource(this._publicDio, this._dio);

  Future<AuthResponseModel> register({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String? categoryId,
  }) async {
    final response = await _publicDio.post(
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
    final response = await _publicDio.post(
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
    final response = await _publicDio.post(
      '/auth/otp/request',
      data: {'phone': phone, 'purpose': purpose},
    );
    final data = response.data['data'] ?? response.data;
    return DateTime.parse(data['expiresAt'] as String);
  }

  /// Client LOGIN by one-time code — authentication only, so the body is a
  /// phone and a code and nothing else. The endpoint no longer accepts a
  /// name; registration is where one belongs.
  Future<AuthResponseModel> clientOtpLogin({
    required String phone,
    required String otp,
  }) async {
    final response = await _publicDio.post(
      '/auth/client/otp-login',
      data: {'phone': phone, 'otp': otp},
    );
    return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Step 2 of Ustaad registration: spends the code and returns the token
  /// that authorises finishing the registration. Creates nothing.
  Future<WorkerRegistrationToken> workerOtpVerify({
    required String phone,
    required String otp,
  }) async {
    final response = await _publicDio.post(
      '/auth/worker/otp-verify',
      data: {'phone': phone, 'otp': otp},
    );
    final data = response.data['data'] ?? response.data;
    return WorkerRegistrationToken(
      token: data['registrationToken'] as String,
      expiresAt: DateTime.parse(data['expiresAt'] as String),
    );
  }

  /// Creates the Ustaad account. Proof of the number is either the
  /// [registrationToken] from Step 2 or, for the original single-call path,
  /// an [otp] — the backend requires exactly one.
  Future<AuthResponseModel> workerOtpRegister({
    required String fullName,
    required String phone,
    String? otp,
    required String password,
    required String categoryId,
    String? registrationToken,
  }) async {
    final response = await _publicDio.post(
      '/auth/worker/otp-register',
      data: {
        'fullName': fullName,
        'phone': phone,
        if (otp != null) 'otp': otp,
        if (registrationToken != null) 'registrationToken': registrationToken,
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
    final response = await _publicDio.post(
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
    final response = await _publicDio.post(
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
    await _publicDio.post('/auth/forgot-password/reset', data: {
      'phone': phone,
      'otp': otp,
      'newPassword': newPassword,
    });
  }

  Future<void> deleteAccount() async {
    await _dio.delete(
      '/auth/account',
      data: const {'confirmation': 'DELETE_MY_ACCOUNT'},
    );
  }

  Future<String> checkClientPhoneStatus(String phone) async {
    final response = await _publicDio.post(
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
    final response = await _publicDio.post(
      '/auth/client/password-login',
      data: {'phone': phone, 'password': password},
    );
    return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Client REGISTRATION — the one call that carries a name, and the one
  /// that creates an account. Sending [otp] makes it atomic: the backend
  /// verifies the code before writing anything, so a rejected code leaves no
  /// half-registered account behind.
  Future<AuthResponseModel> clientPasswordRegister({
    required String fullName,
    required String phone,
    required String password,
    required String otp,
  }) async {
    final response = await _publicDio.post(
      '/auth/client/password-register',
      data: {
        'fullName': fullName,
        'phone': phone,
        'password': password,
        'otp': otp,
      },
    );
    return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DateTime> clientForgotPasswordRequest(String phone) async {
    final response = await _publicDio.post(
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
    await _publicDio.post('/auth/client/forgot-password/reset', data: {
      'phone': phone,
      'otp': otp,
      'newPassword': newPassword,
    });
  }
}

final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  return AuthRemoteDatasource(
    ref.watch(publicDioProvider),
    ref.watch(dioProvider),
  );
});
