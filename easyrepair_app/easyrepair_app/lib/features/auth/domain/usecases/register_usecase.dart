import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/auth_tokens_entity.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository _repository;

  const RegisterUseCase(this._repository);

  Future<Either<Failure, AuthTokensEntity>> call({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) {
    return _repository.register(
      phone: phone,
      password: password,
      firstName: firstName,
      lastName: lastName,
      role: role,
    );
  }
}
