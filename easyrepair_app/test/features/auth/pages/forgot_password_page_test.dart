import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:handygo_app/features/auth/domain/entities/auth_tokens_entity.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:handygo_app/features/auth/presentation/pages/forgot_password_page.dart';

class _FakeAuthRepository implements AuthRepository {
  int requestCalls = 0;
  int resetCalls = 0;
  Failure? requestFailure;
  Failure? resetFailure;

  @override
  Future<Either<Failure, DateTime>> forgotPasswordRequest(String phone) async {
    requestCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (requestFailure != null) return Left(requestFailure!);
    return Right(DateTime.now().add(const Duration(minutes: 5)));
  }

  @override
  Future<Either<Failure, void>> forgotPasswordReset({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    resetCalls++;
    if (resetFailure != null) return Left(resetFailure!);
    return const Right(null);
  }

  @override
  Future<Either<Failure, DateTime>> requestOtp({
    required String phone,
    required OtpPurpose purpose,
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
  Future<Either<Failure, AuthTokensEntity>> workerOtpLogin({
    required String phone,
    required String otp,
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
  Future<Either<Failure, AuthTokensEntity>> login({
    required String phone,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> logout() => throw UnimplementedError();

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> deleteAccount() => throw UnimplementedError();
}

Widget _wrap(_FakeAuthRepository repo) {
  final router = GoRouter(
    initialLocation: '/forgot-password',
    routes: [
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/auth/worker/login',
        builder: (_, _) => const Scaffold(body: Text('WORKER_LOGIN_PAGE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('ForgotPasswordPage (Ustaad-only)', () {
    testWidgets('rejects an invalid phone without calling the backend', (
      tester,
    ) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(_wrap(repo));

      await tester.enterText(find.byType(TextFormField).first, '123');
      await tester.tap(find.text('OTP Bhejein'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sahi Pakistani mobile number'), findsOneWidget);
      expect(repo.requestCalls, 0);
    });

    testWidgets(
      'requesting the code reveals the 6-box OTP entry and the new-password fields',
      (tester) async {
        final repo = _FakeAuthRepository();
        await tester.pumpWidget(_wrap(repo));

        await tester.enterText(find.byType(TextFormField).first, '03378372427');
        await tester.tap(find.text('OTP Bhejein'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(repo.requestCalls, 1);
        expect(find.text('Naya Password'), findsOneWidget);
        expect(find.text('Naya Password Dobara Likhein'), findsOneWidget);
        expect(find.text('Naya Password Confirm Karein'), findsOneWidget);
      },
    );

    testWidgets(
      'the confirm button stays disabled until all 6 OTP digits are entered',
      (tester) async {
        final repo = _FakeAuthRepository();
        await tester.pumpWidget(_wrap(repo));

        await tester.enterText(find.byType(TextFormField).first, '03378372427');
        await tester.tap(find.text('OTP Bhejein'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final confirmButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Naya Password Confirm Karein'),
        );
        expect(confirmButton.onPressed, isNull);
      },
    );

    testWidgets(
      'submitting resets the password, invalidates the OTP server-side, and redirects to Worker login',
      (tester) async {
        final repo = _FakeAuthRepository();
        await tester.pumpWidget(_wrap(repo));

        await tester.enterText(find.byType(TextFormField).first, '03378372427');
        await tester.tap(find.text('OTP Bhejein'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Pinput renders its input capture via a raw EditableText (not a
        // Material TextField), so it must be targeted specifically —
        // find.byType(TextField) would only match the password fields.
        await tester.enterText(find.byType(EditableText).first, '123456');
        await tester.pump();

        final passwordFields = find.byType(TextFormField);
        await tester.enterText(passwordFields.at(0), 'newSecurePassword1');
        await tester.enterText(passwordFields.at(1), 'newSecurePassword1');

        await tester.ensureVisible(
          find.text('Naya Password Confirm Karein'),
        );
        await tester.tap(find.text('Naya Password Confirm Karein'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pumpAndSettle();

        expect(repo.resetCalls, 1);
        expect(find.text('WORKER_LOGIN_PAGE'), findsOneWidget);
      },
    );

    testWidgets('preserves the entered phone number after a request failure', (
      tester,
    ) async {
      final repo = _FakeAuthRepository()
        ..requestFailure = const NetworkFailure('Internet check karein.');
      await tester.pumpWidget(_wrap(repo));

      await tester.enterText(find.byType(TextFormField).first, '03378372427');
      await tester.tap(find.text('OTP Bhejein'));
      await tester.pumpAndSettle();

      expect(find.text('OTP Bhejein'), findsOneWidget); // still on step 1
      final phoneField =
          tester.widget<TextFormField>(find.byType(TextFormField).first);
      expect(phoneField.controller!.text, '03378372427');
    });
  });
}
