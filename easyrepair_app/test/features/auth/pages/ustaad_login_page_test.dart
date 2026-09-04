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
import 'package:handygo_app/features/auth/presentation/pages/ustaad_login_page.dart';
import 'package:handygo_app/features/auth/presentation/pages/ustaad_register_step1_page.dart';
import 'package:handygo_app/features/auth/presentation/widgets/client_auth_widgets.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

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
  int workerOtpVerifyCalls = 0;
  String? lastWorkerVerifyPhone;
  String? lastWorkerVerifyOtp;
  Failure? workerOtpVerifyFailure;

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
    required String otp,
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
    required String phone,
    required String otp,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, WorkerRegistrationToken>> workerOtpVerify({
    required String phone,
    required String otp,
  }) async {
    workerOtpVerifyCalls++;
    lastWorkerVerifyPhone = phone;
    lastWorkerVerifyOtp = otp;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (workerOtpVerifyFailure != null) return Left(workerOtpVerifyFailure!);
    return Right(
      WorkerRegistrationToken(
        token: 'registration.token',
        expiresAt: DateTime.now().add(const Duration(minutes: 45)),
      ),
    );
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> workerOtpRegister({
    required String fullName,
    required String phone,
    String? otp,
    required String password,
    required String categoryId,
    String? registrationToken,
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

Widget _wrap(
  _FakeAuthRepository repo, {
  AppLocale locale = AppLocale.romanUrdu,
  ThemeData? theme,
}) {
  final router = GoRouter(
    initialLocation: UstaadLoginPage.route,
    routes: [
      GoRoute(
        path: UstaadLoginPage.route,
        builder: (_, _) => const UstaadLoginPage(),
      ),
      GoRoute(
        path: UstaadRegisterStep1Page.route,
        builder: (_, _) => const Scaffold(body: Text('USTAAD_REGISTER_1')),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const Scaffold(body: Text('FORGOT_PASSWORD')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: localizedRouterApp(router, locale: locale, theme: theme),
  );
}

/// Fills the form and taps Login, scrolling it into view first.
Future<void> _submit(
  WidgetTester tester, {
  String phone = '03378372427',
  String? password = 'password123',
}) async {
  await tester.enterText(find.byType(TextFormField).first, phone);
  if (password != null) {
    await tester.enterText(find.byType(TextFormField).last, password);
  }
  await tester.pump();
  await tester.ensureVisible(find.text('Login'));
  await tester.pump();
  await tester.tap(find.text('Login'), warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('login is phone + password, with no OTP step', () {
    testWidgets('the page offers no OTP entry, no "send code" action and no '
        'OTP login button', (tester) async {
      await tester.pumpWidget(_wrap(_FakeAuthRepository()));

      expect(find.text('OTP bhejein'), findsNothing);
      expect(find.text('Code se login karein'), findsNothing);
      expect(find.text('Code dobara bhejein'), findsNothing);
      // And no name/username either — login is authentication only.
      expect(find.text('Poora Naam · CNIC ke mutabiq'), findsNothing);
      // Phone + password, and no third entry field for a code.
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('requesting an OTP is never even attempted', (tester) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(_wrap(repo));

      await _submit(tester);

      expect(repo.requestOtpCalls, 0,
          reason: 'no SMS may be sent for an Ustaad login');
      expect(repo.workerOtpLoginCalls, 0,
          reason: 'the password-free login endpoint must never be called');
    });

    testWidgets('correct phone + password authenticates through the password '
        'endpoint', (tester) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(_wrap(repo));

      await _submit(tester);

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

      await _submit(tester, password: null);

      expect(repo.loginCalls, 0);
    });

    testWidgets('a malformed phone is rejected before any request',
        (tester) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(_wrap(repo));

      await _submit(tester, phone: '12345');

      expect(repo.loginCalls, 0);
    });

    testWidgets('a wrong password surfaces the server rejection and creates '
        'no session', (tester) async {
      final repo = _FakeAuthRepository()
        ..loginFailure = const UnauthorizedFailure('');
      await tester.pumpWidget(_wrap(repo));

      await _submit(tester, password: 'wrong-password');

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

      await _submit(tester);

      expect(find.text('Ye number registered nahi hai.'), findsOneWidget);
      expect(find.textContaining('Client'), findsNothing);
    },
  );

  group('the Ustaad login screen', () {
    testWidgets('shows the approved Roman Urdu copy', (tester) async {
      await tester.pumpWidget(_wrap(_FakeAuthRepository()));

      expect(find.text('Ustaad'), findsOneWidget);
      expect(find.text('HandyGo par kaam lein'), findsOneWidget);
      expect(find.text('Ustaad login'), findsOneWidget);
      expect(
        find.text('Kaam lene ke liye apne number se Login karein.'),
        findsOneWidget,
      );
      expect(find.text('Mobile number'), findsOneWidget);
      expect(find.text('Password bhool gaye?'), findsOneWidget);
      expect(
        find.text('Har Ustaad ka CNIC verify hota hai. Registration ke baad '
            '24 ghante mein approval.'),
        findsOneWidget,
      );
      expect(find.text('Naye Ustaad hain?'), findsOneWidget);
      expect(find.text('Register karein'), findsOneWidget);
    });

    testWidgets('becomes fully English under the English locale',
        (tester) async {
      await tester.pumpWidget(
        _wrap(_FakeAuthRepository(), locale: AppLocale.english),
      );

      expect(find.text('Work with HandyGo'), findsOneWidget);
      expect(
        find.text('Login with your mobile number to find work.'),
        findsOneWidget,
      );
      expect(find.text('New Ustaad?'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
      expect(find.text('HandyGo par kaam lein'), findsNothing);
    });

    testWidgets('keeps Login disabled until phone and password are valid',
        (tester) async {
      await tester.pumpWidget(_wrap(_FakeAuthRepository()));

      bool enabled() => tester
          .widget<ElevatedButton>(find.byType(ElevatedButton).last)
          .enabled;
      expect(enabled(), isFalse);

      await tester.enterText(find.byType(TextFormField).first, '0337');
      await tester.pump();
      expect(enabled(), isFalse);

      await tester.enterText(find.byType(TextFormField).first, '03378372427');
      await tester.pump();
      expect(enabled(), isFalse, reason: 'the password is still empty');

      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.pump();
      expect(enabled(), isTrue);
    });

    testWidgets('Show reveals the password without clearing it',
        (tester) async {
      await tester.pumpWidget(_wrap(_FakeAuthRepository()));
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.pump();

      EditableText field() =>
          tester.widget<EditableText>(find.byType(EditableText).last);
      expect(field().obscureText, isTrue);

      await tester.tap(find.text('Dikhayein'));
      await tester.pump();

      expect(field().obscureText, isFalse);
      expect(field().controller.text, 'password123');
    });

    testWidgets('Forgot Password opens the Ustaad reset flow', (tester) async {
      await tester.pumpWidget(_wrap(_FakeAuthRepository()));

      await tester.tap(find.text('Password bhool gaye?'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('FORGOT_PASSWORD'), findsOneWidget);
    });

    testWidgets('Register opens registration step 1', (tester) async {
      await tester.pumpWidget(_wrap(_FakeAuthRepository()));

      await tester.ensureVisible(find.text('Register karein'));
      await tester.pump();
      await tester.tap(find.text('Register karein'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('USTAAD_REGISTER_1'), findsOneWidget);
    });

    testWidgets('paints from the semantic palette, in both themes',
        (tester) async {
      await tester.pumpWidget(_wrap(_FakeAuthRepository()));
      final context = tester.element(find.byType(UstaadLoginPage));
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        context.semanticColors.background,
      );

      await tester.pumpWidget(
        _wrap(_FakeAuthRepository(), theme: AppTheme.darkTheme),
      );
      // MaterialApp animates theme changes through AnimatedTheme, so the
      // first frame after a swap is still mid-lerp.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppSemanticColors.dark.background,
      );
    });

    testWidgets('fits a 320x568 screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(_FakeAuthRepository()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(ClientPhoneField), findsOneWidget);
    });
  });
}
