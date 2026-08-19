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

/// Authorisation to finish an Ustaad registration, issued by
/// `POST /auth/worker/otp-verify` in exchange for the one-time code.
///
/// Deliberately NOT an [AuthTokensEntity]: it is not a session, it is never
/// written to secure storage, and the backend refuses it anywhere except the
/// registration call it was minted for.
class WorkerRegistrationToken {
  const WorkerRegistrationToken({
    required this.token,
    required this.expiresAt,
  });

  final String token;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
