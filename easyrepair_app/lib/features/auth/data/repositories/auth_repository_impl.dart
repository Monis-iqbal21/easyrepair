import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/auth_tokens_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _datasource;
  final SecureStorageService _storage;

  const AuthRepositoryImpl(this._datasource, this._storage);

  @override
  Future<Either<Failure, DateTime>> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  }) async {
    try {
      final expiresAt = await _datasource.requestOtp(
        phone: phone,
        purpose: purpose.apiValue,
      );
      return Right(expiresAt);
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> clientOtpLogin({
    required String fullName,
    required String phone,
    required String otp,
  }) async {
    try {
      final model = await _datasource.clientOtpLogin(
        fullName: fullName,
        phone: phone,
        otp: otp,
      );
      await _storage.saveTokens(
        accessToken: model.accessToken,
        refreshToken: model.refreshToken,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> workerOtpRegister({
    required String fullName,
    required String phone,
    required String otp,
    required String password,
    required String categoryId,
  }) async {
    try {
      final model = await _datasource.workerOtpRegister(
        fullName: fullName,
        phone: phone,
        otp: otp,
        password: password,
        categoryId: categoryId,
      );
      await _storage.saveTokens(
        accessToken: model.accessToken,
        refreshToken: model.refreshToken,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> workerOtpLogin({
    required String phone,
    required String otp,
  }) async {
    try {
      final model = await _datasource.workerOtpLogin(phone: phone, otp: otp);
      await _storage.saveTokens(
        accessToken: model.accessToken,
        refreshToken: model.refreshToken,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> register({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String? categoryId,
  }) async {
    try {
      final model = await _datasource.register(
        phone: phone,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
        categoryId: categoryId,
      );
      await _storage.saveTokens(
        accessToken: model.accessToken,
        refreshToken: model.refreshToken,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> login({
    required String phone,
    required String password,
  }) async {
    try {
      final model = await _datasource.login(phone: phone, password: password);
      await _storage.saveTokens(
        accessToken: model.accessToken,
        refreshToken: model.refreshToken,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      await _datasource.logout(refreshToken: refreshToken);
      await _storage.clearTokens();
      return const Right(null);
    } on DioException catch (e) {
      await _storage.clearTokens();
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      await _storage.clearTokens();
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      final model = await _datasource.getCurrentUser();
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DateTime>> forgotPasswordRequest(String phone) async {
    try {
      final expiresAt = await _datasource.forgotPasswordRequest(phone);
      return Right(expiresAt);
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> forgotPasswordReset({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await _datasource.forgotPasswordReset(
        phone: phone,
        otp: otp,
        newPassword: newPassword,
      );
      return const Right(null);
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    try {
      await _datasource.deleteAccount();
      await _storage.clearTokens();
      return const Right(null);
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ClientPhoneStatus>> checkClientPhoneStatus(
    String phone,
  ) async {
    try {
      final status = await _datasource.checkClientPhoneStatus(phone);
      return Right(switch (status) {
        'CLIENT' => ClientPhoneStatus.client,
        'WORKER' => ClientPhoneStatus.worker,
        _ => ClientPhoneStatus.newAccount,
      });
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> clientPasswordLogin({
    required String phone,
    required String password,
  }) async {
    try {
      final model = await _datasource.clientPasswordLogin(
        phone: phone,
        password: password,
      );
      await _storage.saveTokens(
        accessToken: model.accessToken,
        refreshToken: model.refreshToken,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> clientPasswordRegister({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    try {
      final model = await _datasource.clientPasswordRegister(
        fullName: fullName,
        phone: phone,
        password: password,
      );
      await _storage.saveTokens(
        accessToken: model.accessToken,
        refreshToken: model.refreshToken,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DateTime>> clientForgotPasswordRequest(
    String phone,
  ) async {
    try {
      final expiresAt = await _datasource.clientForgotPasswordRequest(phone);
      return Right(expiresAt);
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clientForgotPasswordReset({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await _datasource.clientForgotPasswordReset(
        phone: phone,
        otp: otp,
        newPassword: newPassword,
      );
      return const Right(null);
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(authRemoteDatasourceProvider),
    ref.watch(secureStorageServiceProvider),
  );
});
