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

/// Ustaad login: registered phone + password, and nothing else.
///
/// Covers two things. First, the contract itself — there is no OTP step on
/// this page any more, and neither field may be skipped. Second, the
/// role-privacy requirement that predates this change: a Client-owned or
/// genuinely nonexistent phone must show the exact same generic "not
/// registered" copy the Client page shows for the mirror case — never a
/// role-revealing message, never a "use Client login" redirect.
class _FakeAuthRepository implements AuthRepository {
  Failure? workerOtpLoginFailure;
  Failure? loginFailure;
  Failure? requestOtpFailure;
  DateTime? lastExpiresAt;
  int requestOtpCalls = 0;
  int workerOtpLoginCalls = 0;
  int loginCalls = 0;
  String? lastLoginPhone;
  String? lastLoginPassword;
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
    workerOtpLoginCalls++;
    if (workerOtpLoginFailure != null) return Left(workerOtpLoginFailure!);
    return Right(_tokens());
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> login({
    required String phone,
    required String password,
  }) async {
    loginCalls++;
    lastLoginPhone = phone;
    lastLoginPassword = password;
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
  group('login is phone + password, with no OTP step', () {
    testWidgets('the page offers no OTP entry, no "send code" action and no '
        'OTP login button', (tester) async {
      await tester.pumpWidget(_wrap(_FakeAuthRepository()));

      expect(find.text('OTP Bhejein'), findsNothing);
      expect(find.text('OTP se login karein'), findsNothing);
      expect(find.text('Code dobara bhejein'), findsNothing);
      // Phone + password, and no third entry field for a code.
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('requesting an OTP is never even attempted', (tester) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(_wrap(repo));

      await tester.enterText(find.byType(TextFormField).first, '03378372427');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.ensureVisible(find.text('Password Se Login Karein'));
      await tester.tap(find.text('Password Se Login Karein'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.requestOtpCalls, 0,
          reason: 'no SMS may be sent for an Ustaad login');
      expect(repo.workerOtpLoginCalls, 0,
          reason: 'the password-free login endpoint must never be called');
    });

    testWidgets('correct phone + password authenticates through the password '
        'endpoint', (tester) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(_wrap(repo));

      await tester.enterText(find.byType(TextFormField).first, '03378372427');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.ensureVisible(find.text('Password Se Login Karein'));
      await tester.tap(find.text('Password Se Login Karein'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.loginCalls, 1);
      expect(repo.lastLoginPhone, '03378372427');
      expect(repo.lastLoginPassword, 'password123');
      // No error surfaced: the session is established and the router (not
      // this page) dispatches the authenticated Ustaad onward.
      expect(find.text('Ye number registered nahi hai.'), findsNothing);
    });
  });

  group('credentials are still mandatory', () {
    testWidgets('a missing password is rejected locally — a phone number '
        'alone can never log an Ustaad in', (tester) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(_wrap(repo));

      await tester.enterText(find.byType(TextFormField).first, '03378372427');
      await tester.ensureVisible(find.text('Password Se Login Karein'));
      await tester.tap(find.text('Password Se Login Karein'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.loginCalls, 0);
    });

    testWidgets('a malformed phone is rejected before any request',
        (tester) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(_wrap(repo));

      await tester.enterText(find.byType(TextFormField).first, '12345');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.ensureVisible(find.text('Password Se Login Karein'));
      await tester.tap(find.text('Password Se Login Karein'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.loginCalls, 0);
    });

    testWidgets('a wrong password surfaces the server rejection and creates '
        'no session', (tester) async {
      final repo = _FakeAuthRepository()
        ..loginFailure = const UnauthorizedFailure('');
      await tester.pumpWidget(_wrap(repo));

      await tester.enterText(find.byType(TextFormField).first, '03378372427');
      await tester.enterText(find.byType(TextFormField).last, 'wrong-password');
      await tester.ensureVisible(find.text('Password Se Login Karein'));
      await tester.tap(find.text('Password Se Login Karein'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.loginCalls, 1);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

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
}
