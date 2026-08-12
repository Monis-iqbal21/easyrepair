import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:handygo_app/features/auth/domain/entities/auth_tokens_entity.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:handygo_app/features/auth/presentation/pages/client_otp_auth_page.dart';

class _FakeAuthRepository implements AuthRepository {
  int requestOtpCalls = 0;
  int clientOtpLoginCalls = 0;
  Failure? requestOtpFailure;
  Failure? clientOtpLoginFailure;
  DateTime? lastExpiresAt;
  /// How far in the future the next successful requestOtp's expiresAt is
  /// set — defaults to a fresh 5-minute code. Tests that need the resend
  /// cooldown already elapsed (without waiting on the widget's own 1s
  /// ticker) shorten this, mirroring OtpInputSection's own tests.
  Duration nextExpiresIn = const Duration(minutes: 5);

  int phoneCheckCalls = 0;
  ClientPhoneStatus phoneCheckResult = ClientPhoneStatus.newAccount;
  Failure? phoneCheckFailure;

  int passwordLoginCalls = 0;
  Failure? passwordLoginFailure;

  int passwordRegisterCalls = 0;
  Failure? passwordRegisterFailure;

  AuthTokensEntity _tokens() => AuthTokensEntity(
        accessToken: 'a',
        refreshToken: 'r',
        user: const UserEntity(
          id: 'u1',
          phone: '+923378372427',
          role: 'CLIENT',
          firstName: 'Ali',
          lastName: 'Khan',
        ),
      );

  @override
  Future<Either<Failure, ClientPhoneStatus>> checkClientPhoneStatus(
    String phone,
  ) async {
    phoneCheckCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (phoneCheckFailure != null) return Left(phoneCheckFailure!);
    return Right(phoneCheckResult);
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> clientPasswordLogin({
    required String phone,
    required String password,
  }) async {
    passwordLoginCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (passwordLoginFailure != null) return Left(passwordLoginFailure!);
    return Right(_tokens());
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> clientPasswordRegister({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    passwordRegisterCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (passwordRegisterFailure != null) return Left(passwordRegisterFailure!);
    return Right(_tokens());
  }

  @override
  Future<Either<Failure, DateTime>> clientForgotPasswordRequest(
    String phone,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> clientForgotPasswordReset({
    required String phone,
    required String otp,
    required String newPassword,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, DateTime>> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  }) async {
    requestOtpCalls++;
    // A real network round trip always has latency — without it, a
    // same-frame double tap can't be meaningfully distinguished from a
    // double tap that lands while the first request is still in flight
    // (the actual race the app's `_sendInFlight` guard defends against).
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (requestOtpFailure != null) return Left(requestOtpFailure!);
    lastExpiresAt = DateTime.now().add(nextExpiresIn);
    return Right(lastExpiresAt!);
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> clientOtpLogin({
    required String fullName,
    required String phone,
    required String otp,
  }) async {
    clientOtpLoginCalls++;
    if (clientOtpLoginFailure != null) return Left(clientOtpLoginFailure!);
    return Right(
      AuthTokensEntity(
        accessToken: 'a',
        refreshToken: 'r',
        user: const UserEntity(
          id: 'u1',
          phone: '+923378372427',
          role: 'CLIENT',
          firstName: 'Ali',
          lastName: 'Khan',
        ),
      ),
    );
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> workerOtpRegister({
    required String fullName,
    required String phone,
    required String otp,
    required String password,
    required String categoryId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> workerOtpLogin({
    required String phone,
    required String otp,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> register({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String? categoryId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> login({
    required String phone,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> logout() {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, DateTime>> forgotPasswordRequest(String phone) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> forgotPasswordReset({
    required String phone,
    required String otp,
    required String newPassword,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> deleteAccount() {
    throw UnimplementedError();
  }
}

Widget _wrap(_FakeAuthRepository repo) {
  final router = GoRouter(
    initialLocation: '/auth/client',
    routes: [
      GoRoute(
        path: '/auth/client',
        builder: (_, _) => const ClientOtpAuthPage(),
      ),
      GoRoute(
        path: '/auth/worker/login',
        builder: (_, _) => const Scaffold(body: Text('WORKER_LOGIN_PAGE')),
      ),
      GoRoute(
        path: '/auth/client/forgot-password',
        builder: (_, _) =>
            const Scaffold(body: Text('CLIENT_FORGOT_PASSWORD_PAGE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(
      routerConfig: router,
      locale: AppLocale.romanUrdu.locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      localeResolutionCallback: (_, _) => AppLocale.romanUrdu.locale,
    ),
  );
}

void main() {
  group('ClientOtpAuthPage', () {
    testWidgets('shows a validation error and never calls requestOtp for an invalid phone', (
      tester,
    ) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(_wrap(repo));

      await tester.enterText(find.byType(TextFormField).at(0), 'Ali Khan');
      await tester.enterText(find.byType(TextFormField).at(1), '123');
      await tester.tap(find.text('Code Bhejein'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sahi Pakistani mobile number'), findsOneWidget);
      expect(repo.requestOtpCalls, 0);
    });

    testWidgets('sends the OTP and reveals the OTP boxes + verify button', (
      tester,
    ) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(_wrap(repo));

      await tester.enterText(find.byType(TextFormField).at(0), 'Ali Khan');
      await tester.enterText(find.byType(TextFormField).at(1), '03378372427');
      await tester.tap(find.text('Code Bhejein'));
      // OtpInputSection runs a periodic 1s Timer once mounted, which never
      // lets pumpAndSettle() converge — pump a bounded number of frames
      // instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.requestOtpCalls, 1);
      expect(find.text('Verify Karke Aage Barhein'), findsOneWidget);
    });

    testWidgets('preserves entered name/phone after a request failure', (
      tester,
    ) async {
      final repo = _FakeAuthRepository()
        ..requestOtpFailure = const NetworkFailure('Internet connection check karein.');
      await tester.pumpWidget(_wrap(repo));

      await tester.enterText(find.byType(TextFormField).at(0), 'Ali Khan');
      await tester.enterText(find.byType(TextFormField).at(1), '03378372427');
      await tester.tap(find.text('Code Bhejein'));
      await tester.pumpAndSettle();

      // Still on the request step (OTP boxes never appeared) and the typed
      // values are untouched.
      expect(find.text('Code Bhejein'), findsOneWidget);
      final nameField =
          tester.widget<TextFormField>(find.byType(TextFormField).at(0));
      expect(nameField.controller!.text, 'Ali Khan');
      final phoneField =
          tester.widget<TextFormField>(find.byType(TextFormField).at(1));
      expect(phoneField.controller!.text, '03378372427');
    });

    testWidgets(
      'the send button disables itself the instant a request is in flight, '
      'so a second tap before the response returns can never fire another request',
      (tester) async {
        final repo = _FakeAuthRepository();
        await tester.pumpWidget(_wrap(repo));

        await tester.enterText(find.byType(TextFormField).at(0), 'Ali Khan');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          '03378372427',
        );
        await tester.tap(find.text('Code Bhejein'));
        await tester.pump(); // lets the _sendInFlight setState take effect

        // The button is now disabled — a second physical tap here would
        // hit-test onto `onPressed: null` and do nothing, which is exactly
        // what backs the "no duplicate submission" requirement.
        final button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(button.onPressed, isNull);
        expect(repo.requestOtpCalls, 1);

        // Let the in-flight (fake, delayed) request resolve so no pending
        // timer/microtask leaks past the end of the test.
        await tester.pump(const Duration(milliseconds: 60));
      },
    );

    testWidgets(
      'a failed resend keeps the OTP box visible instead of reverting to the phone form',
      (tester) async {
        final repo = _FakeAuthRepository()
          // Backdate the first send's expiresAt so the resend cooldown has
          // already elapsed by the time it renders — same technique
          // otp_input_section_test.dart uses, avoids depending on the
          // widget's own 1s ticker firing during a large tester.pump.
          ..nextExpiresIn = const Duration(minutes: 5) - const Duration(seconds: 61);
        await tester.pumpWidget(_wrap(repo));

        await tester.enterText(find.byType(TextFormField).at(0), 'Ali Khan');
        await tester.enterText(find.byType(TextFormField).at(1), '03378372427');
        await tester.tap(find.text('Code Bhejein'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('Verify Karke Aage Barhein'), findsOneWidget);
        expect(find.text('Code dobara bhejein'), findsOneWidget);

        // The resend itself is rejected (e.g. a race against the backend's
        // own cooldown, or a provider hiccup) — the OTP box must stay put.
        repo.requestOtpFailure = const OtpResendTooSoonFailure('too soon');
        await tester.ensureVisible(find.text('Code dobara bhejein'));
        await tester.tap(find.text('Code dobara bhejein'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(repo.requestOtpCalls, 2);
        expect(find.text('Verify Karke Aage Barhein'), findsOneWidget);
      },
    );

    testWidgets(
      'a Worker-owned phone through the OTP flow shows the generic '
      '"already registered" message — never a role-revealing redirect',
      (tester) async {
        final repo = _FakeAuthRepository()
          ..clientOtpLoginFailure = const PhoneAlreadyRegisteredFailure('');
        await tester.pumpWidget(_wrap(repo));

        await tester.enterText(find.byType(TextFormField).at(0), 'Ali Khan');
        await tester.enterText(find.byType(TextFormField).at(1), '03378372427');
        await tester.tap(find.text('Code Bhejein'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Pinput renders its input capture via a raw EditableText (not a
        // Material TextField) — target it directly. It is the LAST
        // EditableText in the tree: the name and phone fields precede it and
        // both now stay editable through the OTP step, so `.first` would
        // type into the name field (and typing into the phone field
        // deliberately cancels the pending OTP).
        await tester.enterText(find.byType(EditableText).last, '123456');
        await tester.pump();

        await tester.ensureVisible(find.text('Verify Karke Aage Barhein'));
        await tester.tap(find.text('Verify Karke Aage Barhein'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // The role-privacy-required copy, shown as a plain snackbar — no
        // "Ustaad Login" button, no navigation, no role hint anywhere.
        expect(find.text('Ye number pehle se registered hai.'), findsOneWidget);
        expect(find.text('Ustaad Login'), findsNothing);
      },
    );
  });

  group('Client password fallback', () {
    testWidgets('switching to Password se Continue hides the OTP fields', (
      tester,
    ) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(_wrap(repo));

      expect(find.text('Aap ka poora naam'), findsOneWidget);
      await tester.tap(find.text('Password se Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Aap ka poora naam'), findsNothing);
      expect(find.text('Aage Barhein'), findsOneWidget);
    });

    testWidgets('existing Client: phone check reveals the login sub-form', (
      tester,
    ) async {
      final repo = _FakeAuthRepository()
        ..phoneCheckResult = ClientPhoneStatus.client;
      await tester.pumpWidget(_wrap(repo));

      await tester.tap(find.text('Password se Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '03378372427');
      await tester.tap(find.text('Aage Barhein'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.phoneCheckCalls, 1);
      expect(find.text('Login Karein'), findsOneWidget);
      expect(find.text('Password Bhool Gaye?'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Login Karein'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.passwordLoginCalls, 1);
    });

    testWidgets('new phone: phone check reveals the registration sub-form', (
      tester,
    ) async {
      final repo = _FakeAuthRepository()
        ..phoneCheckResult = ClientPhoneStatus.newAccount;
      await tester.pumpWidget(_wrap(repo));

      await tester.tap(find.text('Password se Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '03378372427');
      await tester.tap(find.text('Aage Barhein'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Pura Naam'), findsOneWidget);
      expect(find.text('Password Dobara Likhein'), findsOneWidget);
      expect(find.text('Account Banayein'), findsOneWidget);
    });

    testWidgets('registration is rejected when confirm-password does not match', (
      tester,
    ) async {
      final repo = _FakeAuthRepository()
        ..phoneCheckResult = ClientPhoneStatus.newAccount;
      await tester.pumpWidget(_wrap(repo));

      await tester.tap(find.text('Password se Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '03378372427');
      await tester.tap(find.text('Aage Barhein'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), 'Ali Khan'); // Pura Naam
      await tester.enterText(fields.at(2), 'password123'); // Password
      await tester.enterText(fields.at(3), 'different-password'); // Confirm
      await tester.ensureVisible(find.text('Account Banayein'));
      await tester.tap(find.text('Account Banayein'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords match nahi karte.'), findsOneWidget);
      expect(repo.passwordRegisterCalls, 0);
    });

    testWidgets(
      'a Worker-owned phone in password mode is classified NEW (never '
      'WORKER) and the resulting registration attempt shows the generic '
      '"already registered" message — never a role-revealing redirect',
      (tester) async {
        final repo = _FakeAuthRepository()
          ..phoneCheckResult = ClientPhoneStatus.newAccount
          ..passwordRegisterFailure = const PhoneAlreadyRegisteredFailure('');
        await tester.pumpWidget(_wrap(repo));

        await tester.tap(find.text('Password se Continue'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, '03378372427');
        await tester.tap(find.text('Aage Barhein'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Classified exactly like a genuinely new number — the register
        // sub-form shows, never a Worker-specific redirect.
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(1), 'Ali Khan');
        await tester.enterText(fields.at(2), 'password123');
        await tester.enterText(fields.at(3), 'password123');
        await tester.ensureVisible(find.text('Account Banayein'));
        await tester.tap(find.text('Account Banayein'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Ye number pehle se registered hai.'), findsOneWidget);
        expect(find.text('Ustaad Login'), findsNothing);
      },
    );

    testWidgets(
      'the phone-check button disables itself while in flight (no duplicate submission)',
      (tester) async {
        final repo = _FakeAuthRepository();
        await tester.pumpWidget(_wrap(repo));

        await tester.tap(find.text('Password se Continue'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, '03378372427');
        await tester.tap(find.text('Aage Barhein'));
        await tester.pump();

        final button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(button.onPressed, isNull);
        expect(repo.phoneCheckCalls, 1);

        await tester.pump(const Duration(milliseconds: 60));
      },
    );

    testWidgets(
      'a genuine SMS provider failure on the OTP send shows the required fallback message',
      (tester) async {
        final repo = _FakeAuthRepository()
          ..requestOtpFailure = const SmsSendFailure('SMS bhejne mein masla hua.');
        await tester.pumpWidget(_wrap(repo));

        await tester.enterText(find.byType(TextFormField).at(0), 'Ali Khan');
        await tester.enterText(find.byType(TextFormField).at(1), '03378372427');
        await tester.tap(find.text('Code Bhejein'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.text(
            'OTP filhal send nahi ho saka. Password se continue karein ya thori dair baad dobara koshish karein.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
