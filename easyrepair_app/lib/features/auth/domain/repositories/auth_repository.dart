import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/auth_tokens_entity.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, AuthTokensEntity>> register({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    /// Required when role == 'WORKER' — the Ustaad's single main skill.
    String? categoryId,
  });

  Future<Either<Failure, AuthTokensEntity>> login({
    required String phone,
    required String password,
  });

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, UserEntity>> getCurrentUser();

  Future<Either<Failure, void>> forgotPasswordRequest(String phone);

  Future<Either<Failure, void>> forgotPasswordReset({
    required String phone,
    required String otp,
    required String newPassword,
  });

  Future<Either<Failure, void>> deleteAccount();
}
