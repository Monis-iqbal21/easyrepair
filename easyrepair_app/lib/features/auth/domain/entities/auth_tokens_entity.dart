import 'user_entity.dart';

class AuthTokensEntity {
  final String accessToken;
  final String refreshToken;
  final UserEntity user;

  const AuthTokensEntity({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });
}
