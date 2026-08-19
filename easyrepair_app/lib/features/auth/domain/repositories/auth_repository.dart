import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/auth_tokens_entity.dart';
import '../entities/user_entity.dart';

/// The three OTP purposes recognized by the backend's `/auth/otp/request`
/// endpoint (`AuthOtpPurpose` in the Prisma schema) — kept in sync manually
/// since this is a small, stable, backend-owned enum.
enum OtpPurpose { clientLoginRegister, workerRegister, workerLogin }

extension OtpPurposeApiValue on OtpPurpose {
  String get apiValue => switch (this) {
        OtpPurpose.clientLoginRegister => 'CLIENT_LOGIN_REGISTER',
        OtpPurpose.workerRegister => 'WORKER_REGISTER',
        OtpPurpose.workerLogin => 'WORKER_LOGIN',
      };
}

/// Result of `/auth/client/phone-check` — drives which sub-form the Client
/// password mode shows. Role-privacy safe: a Worker-owned phone reports as
/// [newAccount], exactly like a genuinely new number — see backend
/// `AuthService.checkClientPhoneStatus`. The subsequent registration attempt
/// on that phone correctly rejects with "already registered" without ever
/// revealing it belongs to a Worker.
enum ClientPhoneStatus { client, newAccount }

abstract class AuthRepository {
  /// Classifies [phone] before any password is entered — existing Client
  /// (show login) or not (show registration). Deliberately reveals only
  /// whether a CLIENT account exists, never whether a Worker owns the
  /// number.
  Future<Either<Failure, ClientPhoneStatus>> checkClientPhoneStatus(
    String phone,
  );

  /// Client password fallback — existing account only.
  Future<Either<Failure, AuthTokensEntity>> clientPasswordLogin({
    required String phone,
    required String password,
  });

  /// Client REGISTRATION — the only Client auth call that carries a name,
  /// and the only one that creates an account. The backend verifies [otp]
  /// before writing anything and creates the account already phone-verified,
  /// so a rejected code cannot leave a half-registered user behind.
  Future<Either<Failure, AuthTokensEntity>> clientPasswordRegister({
    required String fullName,
    required String phone,
    required String password,
    required String otp,
  });

  /// Client-only password reset OTP request — same authoritative-`expiresAt`
  /// contract as the Worker `forgotPasswordRequest` below.
  Future<Either<Failure, DateTime>> clientForgotPasswordRequest(String phone);

  Future<Either<Failure, void>> clientForgotPasswordReset({
    required String phone,
    required String otp,
    required String newPassword,
  });

  /// Requests an OTP for [phone] scoped to [purpose]. Returns the backend's
  /// authoritative expiry — the countdown UI must always derive from this,
  /// never from a locally-assumed 5-minute duration.
  Future<Either<Failure, DateTime>> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  });

  /// Client LOGIN by one-time code — EXISTING Clients only.
  ///
  /// Authentication carries no registration data, so there is no name here.
  /// A number with no Client account, a Worker-owned number and a deleted
  /// account all fail identically with [FailureCode.phoneNotRegistered];
  /// nothing is ever created.
  Future<Either<Failure, AuthTokensEntity>> clientOtpLogin({
    required String phone,
    required String otp,
  });

  /// Ustaad registration Step 2 — verifies and CONSUMES the code, returning
  /// the short-lived token that authorises finishing the registration. No
  /// account and no session are created here, and the token cannot
  /// authenticate anything else.
  Future<Either<Failure, WorkerRegistrationToken>> workerOtpVerify({
    required String phone,
    required String otp,
  });

  /// Creates the Ustaad account. Exactly one proof of the number is required:
  /// [registrationToken] from Step 2 (what the 4-step flow uses, so the code
  /// cannot expire while the profile is filled in), or [otp] for the original
  /// single-call path.
  Future<Either<Failure, AuthTokensEntity>> workerOtpRegister({
    required String fullName,
    required String phone,
    String? otp,
    required String password,
    required String categoryId,
    String? registrationToken,
  });

  Future<Either<Failure, AuthTokensEntity>> workerOtpLogin({
    required String phone,
    required String otp,
  });

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

  /// Worker-only. Returns the backend's authoritative OTP expiry — the
  /// response shape (including this value) is deliberately identical whether
  /// or not the phone is registered/a Worker, so it must never be used to
  /// probe account existence.
  Future<Either<Failure, DateTime>> forgotPasswordRequest(String phone);

  Future<Either<Failure, void>> forgotPasswordReset({
    required String phone,
    required String otp,
    required String newPassword,
  });

  Future<Either<Failure, void>> deleteAccount();
}
