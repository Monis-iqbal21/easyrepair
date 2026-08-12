import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:handygo_app/features/auth/domain/entities/auth_tokens_entity.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:handygo_app/features/auth/presentation/pages/worker_login_page.dart';

import '../../../support/l10n_test_app.dart';

/// Pins the role-privacy requirement on the Worker side: a Client-owned or
/// genuinely nonexistent phone through the Worker login page (OTP or
/// password) must show the exact same generic "not registered" copy the
/// Client page shows for the mirror case — never a role-revealing message,
/// never a "use Client login" redirect.
class _FakeAuthRepository implements AuthRepository {
  Failure? workerOtpLoginFailure;
  Failure? loginFailure;
  Failure? requestOtpFailure;
  DateTime? lastExpiresAt;
  int requestOtpCalls = 0;
  Duration nextExpiresIn = const Duration(minutes: 5);

  AuthTokensEntity _tokens() => AuthTokensEntity(
        accessToken: 'a',
        refreshToken: 'r',
        user: const UserEntity(
          id: 'w1',
          phone: '+923378372427',
          role: 'WORKER',
          firstName: 'Bilal',
          lastName: 'Ahmed',
          workerStatus: 'ACTIVE',
        ),
      );

  @override
  Future<Either<Failure, DateTime>> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  }) async {
    requestOtpCalls++;
    if (requestOtpFailure != null) return Left(requestOtpFailure!);
    lastExpiresAt = DateTime.now().add(nextExpiresIn);
    return Right(lastExpiresAt!);
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> workerOtpLogin({
    required String phone,
    required String otp,
  }) async {
    if (workerOtpLoginFailure != null) return Left(workerOtpLoginFailure!);
    return Right(_tokens());
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> login({
    required String phone,
    required String password,
  }) async {
    if (loginFailure != null) return Left(loginFailure!);
    return Right(_tokens());
  }

  @override
  Future<Either<Failure, ClientPhoneStatus>> checkClientPhoneStatus(
    String phone,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, AuthTokensEntity>> clientPasswordLogin({
    required String phone,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, AuthTokensEntity>> clientPasswordRegister({
    required String fullName,
    required String phone,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, DateTime>> clientForgotPasswordRequest(
    String phone,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> clientForgotPasswordReset({
    required String phone,
    required String otp,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, AuthTokensEntity>> clientOtpLogin({
    required String fullName,
    required String phone,
    required String otp,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, AuthTokensEntity>> workerOtpRegister({
    required String fullName,
    required String phone,
    required String otp,
    required String password,
    required String categoryId,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, AuthTokensEntity>> register({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String? categoryId,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> logout() => throw UnimplementedError();

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, DateTime>> forgotPasswordRequest(String phone) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> forgotPasswordReset({
    required String phone,
    required String otp,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> deleteAccount() => throw UnimplementedError();
}

Widget _wrap(_FakeAuthRepository repo) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: localizedApp(
      const WorkerLoginPage(),
      locale: AppLocale.romanUrdu,
    ),
  );
}

void main() {
  testWidgets(
    'a Client-owned (or nonexistent) phone via Worker password login shows '
    'the exact same generic message as the Client-side mirror case — no '
    'role hint, no "use Client login" redirect',
    (tester) async {
      final repo = _FakeAuthRepository()
        ..loginFailure = const PhoneNotRegisteredFailure('');
      await tester.pumpWidget(_wrap(repo));

      await tester.enterText(find.byType(TextFormField).first, '03378372427');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.ensureVisible(find.text('Password Se Login Karein'));
      await tester.tap(find.text('Password Se Login Karein'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Ye number registered nahi hai.'), findsOneWidget);
      expect(find.textContaining('Client'), findsNothing);
    },
  );

  testWidgets(
    'a Client-owned (or nonexistent) phone via Worker OTP login shows the '
    'exact same generic message',
    (tester) async {
      final repo = _FakeAuthRepository()
        ..workerOtpLoginFailure = const PhoneNotRegisteredFailure('');
      await tester.pumpWidget(_wrap(repo));

      await tester.enterText(find.byType(TextFormField).first, '03378372427');
      await tester.tap(find.text('OTP Bhejein'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Unlike the Client page, OTP and password fields are both visible at
      // once here (single merged page) — the Pinput is EditableText index 1
      // (0 is the phone field; the always-visible password field comes
      // after it), not the last one.
      await tester.enterText(find.byType(EditableText).at(1), '123456');
      await tester.pump();

      await tester.ensureVisible(find.text('OTP se login karein'));
      await tester.tap(find.text('OTP se login karein'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Ye number registered nahi hai.'), findsOneWidget);
    },
  );

  testWidgets(
    'a failed resend keeps the OTP box visible instead of reverting to the phone-only form',
    (tester) async {
      final repo = _FakeAuthRepository()
        // Backdate the first send's expiresAt so the resend cooldown has
        // already elapsed by the time it renders — see the identical
        // Client-page test for why this avoids the widget's own 1s ticker.
        ..nextExpiresIn = const Duration(minutes: 5) - const Duration(seconds: 61);
      await tester.pumpWidget(_wrap(repo));

      await tester.enterText(find.byType(TextFormField).first, '03378372427');
      await tester.tap(find.text('OTP Bhejein'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('OTP se login karein'), findsOneWidget);
      expect(find.text('Code dobara bhejein'), findsOneWidget);

      // The resend itself is rejected — same shared OtpRequestNotifier as
      // the Client page, so the fix (and the test) mirrors it exactly.
      repo.requestOtpFailure = const OtpResendTooSoonFailure('too soon');
      await tester.ensureVisible(find.text('Code dobara bhejein'));
      await tester.tap(find.text('Code dobara bhejein'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.requestOtpCalls, 2);
      expect(find.text('OTP se login karein'), findsOneWidget);
    },
  );
}
