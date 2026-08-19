import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/auth/presentation/widgets/client_auth_widgets.dart';
import 'package:handygo_app/features/auth/presentation/widgets/otp_input_section.dart' show otpLength;
import 'package:pinput/pinput.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:handygo_app/features/auth/domain/entities/auth_tokens_entity.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:handygo_app/features/auth/presentation/pages/forgot_password_page.dart';

class _FakeAuthRepository implements AuthRepository {
  int workerOtpVerifyCalls = 0;
  String? lastWorkerVerifyPhone;
  String? lastWorkerVerifyOtp;
  Failure? workerOtpVerifyFailure;

  int requestCalls = 0;
  int resetCalls = 0;
  int loginCalls = 0;
  Failure? requestFailure;
  Failure? resetFailure;

  /// How far ahead the next requested code expires. Shortening it is how a
  /// test reaches the "cooldown elapsed" or "already expired" state without
  /// waiting on a real timer.
  Duration nextExpiresIn = const Duration(minutes: 5);

  String? lastForgotPhone;
  String? lastResetPhone;
  String? lastResetOtp;
  String? lastResetPassword;

  int get forgotRequestCalls => requestCalls;
  int get forgotResetCalls => resetCalls;

  @override
  Future<Either<Failure, DateTime>> forgotPasswordRequest(String phone) async {
    requestCalls++;
    lastForgotPhone = phone;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (requestFailure != null) return Left(requestFailure!);
    return Right(DateTime.now().add(nextExpiresIn));
  }

  @override
  Future<Either<Failure, void>> forgotPasswordReset({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    resetCalls++;
    lastResetPhone = phone;
    lastResetOtp = otp;
    lastResetPassword = newPassword;
    await Future<void>.delayed(const Duration(milliseconds: 30));
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
}

Widget _wrap(
  _FakeAuthRepository repo, {
  AppLocale locale = AppLocale.romanUrdu,
  ThemeData? theme,
}) {
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
    child: MaterialApp.router(
      theme: theme ?? AppTheme.lightTheme,
      routerConfig: router,
      locale: locale.locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      localeResolutionCallback: (_, _) => locale.locale,
    ),
  );
}

/// Bounded pumps instead of `pumpAndSettle`: the OTP boxes autofocus, and a
/// focused text field animates forever.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _settle(tester);
  await tester.tap(finder);
  await _settle(tester);
}

bool _ctaEnabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byType(ElevatedButton).last).enabled;

/// Walks the phone step and lands on the code step.
Future<_FakeAuthRepository> _toCodeStep(
  WidgetTester tester, {
  _FakeAuthRepository? repo,
  AppLocale locale = AppLocale.romanUrdu,
  ThemeData? theme,
}) async {
  final r = repo ?? _FakeAuthRepository();
  await tester.pumpWidget(_wrap(r, locale: locale, theme: theme));
  await _settle(tester);
  await tester.enterText(find.byType(TextFormField).first, '03378372427');
  await tester.pump();
  await _tap(tester, find.text('OTP bhejein'));
  return r;
}

void main() {
  setUp(() {
    // The OTP boxes autofocus; a blinking cursor is an animation that never
    // ends, which pumpAndSettle would wait on forever.
    EditableText.debugDeterministicCursor = true;
  });
  tearDown(() => EditableText.debugDeterministicCursor = false);

  group('Ustaad password reset — the phone step', () {
    testWidgets('shows the approved Roman Urdu copy', (tester) async {
      await tester.pumpWidget(_wrap(_FakeAuthRepository()));
      await _settle(tester);

      expect(find.text('Password reset karein'), findsOneWidget);
      expect(
        find.text('Apna registered mobile number likhein.'),
        findsOneWidget,
      );
      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.text('OTP bhejein'), findsOneWidget);
      // Authentication only — nothing about identity is asked for.
      expect(find.text('Poora Naam · CNIC ke mutabiq'), findsNothing);
      expect(find.text('CNIC Number'), findsNothing);
    });

    testWidgets('becomes fully English under the English locale',
        (tester) async {
      await tester.pumpWidget(
        _wrap(_FakeAuthRepository(), locale: AppLocale.english),
      );
      await _settle(tester);

      expect(find.text('Reset Password'), findsOneWidget);
      expect(
        find.text('Enter your registered mobile number.'),
        findsOneWidget,
      );
      expect(find.text('Password reset karein'), findsNothing);
    });

    testWidgets('the phone is required — the CTA stays disabled and nothing '
        'is requested', (tester) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(_wrap(repo));
      await _settle(tester);
      expect(_ctaEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextFormField).first, '12345');
      await tester.pump();
      expect(_ctaEnabled(tester), isFalse);
      expect(repo.forgotRequestCalls, 0);
    });

    testWidgets('a valid Worker phone requests the reset code once, even on a '
        'double tap', (tester) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(_wrap(repo));
      await _settle(tester);
      await tester.enterText(find.byType(TextFormField).first, '03378372427');
      await tester.pump();

      await tester.ensureVisible(find.text('OTP bhejein'));
      await _settle(tester);
      await tester.tap(find.text('OTP bhejein'));
      await tester.tap(find.text('OTP bhejein'));
      await _settle(tester);

      expect(repo.forgotRequestCalls, 1);
      expect(repo.lastForgotPhone, '03378372427');
    });

    testWidgets('renders under the dark theme', (tester) async {
      await tester.pumpWidget(
        _wrap(_FakeAuthRepository(), theme: AppTheme.darkTheme),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
        AppSemanticColors.dark.background,
      );
    });
  });

  group('Ustaad password reset — the code step', () {
    testWidgets('shows six boxes, the expiry and the resend cooldown',
        (tester) async {
      await _toCodeStep(tester);

      expect(find.text('Code verify karein'), findsOneWidget);
      expect(find.textContaining('par code bheja gaya.'), findsOneWidget);
      expect(otpLength, 6);
      expect(tester.widget<Pinput>(find.byType(Pinput)).length, 6);
      expect(find.textContaining('mein expire hoga'), findsOneWidget);
      // A code was just sent, so the backend cooldown is running.
      expect(find.textContaining('Code dobara bhejein ('), findsOneWidget);
      expect(find.text('Resend'), findsNothing);
    });

    testWidgets('Verify is disabled below six digits and enabled at six',
        (tester) async {
      await _toCodeStep(tester);
      expect(_ctaEnabled(tester), isFalse);

      await tester.enterText(find.byType(EditableText).last, '12345');
      await _settle(tester);
      expect(_ctaEnabled(tester), isFalse);

      await tester.enterText(find.byType(EditableText).last, '123456');
      await _settle(tester);
      expect(_ctaEnabled(tester), isTrue);
    });

    testWidgets('an expired code cannot continue', (tester) async {
      final repo = _FakeAuthRepository()
        ..nextExpiresIn = const Duration(seconds: -1);
      await _toCodeStep(tester, repo: repo);

      await tester.enterText(find.byType(EditableText).last, '123456');
      await _settle(tester);

      expect(find.textContaining('expire ho gaya'), findsOneWidget);
      expect(_ctaEnabled(tester), isFalse);
    });

    testWidgets('resend is blocked during the cooldown and requests one new '
        'code once it has elapsed', (tester) async {
      // An expiry ten seconds out means the request happened 4m50s ago, so
      // the 60-second cooldown is long gone — the trick the shared OTP
      // widget's own tests use to avoid waiting on a real timer.
      final repo = _FakeAuthRepository()
        ..nextExpiresIn = const Duration(seconds: 10);
      await _toCodeStep(tester, repo: repo);
      expect(repo.forgotRequestCalls, 1);

      await _tap(tester, find.text('Resend'));

      expect(repo.forgotRequestCalls, 2);
      // Still on the code step — a resend must not skip ahead.
      expect(find.text('Code verify karein'), findsOneWidget);
    });

    testWidgets('Back returns to the number rather than abandoning the reset, '
        'and sends nothing on the way', (tester) async {
      final repo = await _toCodeStep(tester);

      await _tap(tester, find.byIcon(Icons.arrow_back_rounded));

      expect(find.text('Password reset karein'), findsOneWidget);
      expect(find.byType(ClientOtpField), findsNothing);
      expect(repo.forgotRequestCalls, 1,
          reason: 'stepping back must never send another code');
    });

    testWidgets('editing the number after stepping back invalidates the old '
        'code', (tester) async {
      final repo = await _toCodeStep(tester);
      await _tap(tester, find.byIcon(Icons.arrow_back_rounded));

      await tester.enterText(find.byType(TextFormField).first, '03001234567');
      await _settle(tester);

      // Still on the number step, with no live code behind it.
      expect(find.text('Password reset karein'), findsOneWidget);
      expect(repo.forgotRequestCalls, 1,
          reason: 'editing must never auto-send another code');
    });

    testWidgets('renders under the dark theme', (tester) async {
      await _toCodeStep(tester, theme: AppTheme.darkTheme);

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
        AppSemanticColors.dark.background,
      );
    });
  });

  group('Ustaad password reset — the password step', () {
    Future<_FakeAuthRepository> toPasswordStep(
      WidgetTester tester, {
      _FakeAuthRepository? repo,
      ThemeData? theme,
    }) async {
      final r = await _toCodeStep(tester, repo: repo, theme: theme);
      await tester.enterText(find.byType(EditableText).last, '123456');
      await _settle(tester);
      await _tap(tester, find.text('Verify karein'));
      return r;
    }

    testWidgets('shows the approved copy and both fields', (tester) async {
      await toPasswordStep(tester);

      expect(find.text('Naya password banayein'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Password change karein'), findsOneWidget);
    });

    testWidgets('the CTA needs a long enough password AND a match',
        (tester) async {
      await toPasswordStep(tester);
      expect(_ctaEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextFormField).at(0), 'short12');
      await tester.enterText(find.byType(TextFormField).at(1), 'short12');
      await tester.pump();
      expect(_ctaEnabled(tester), isFalse, reason: 'under eight characters');

      await tester.enterText(find.byType(TextFormField).at(0), 'password123');
      await tester.enterText(find.byType(TextFormField).at(1), 'different99');
      await tester.pump();
      expect(_ctaEnabled(tester), isFalse, reason: 'the two do not match');

      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.pump();
      expect(_ctaEnabled(tester), isTrue);
    });

    testWidgets('resetting sends the phone, the code and the new password '
        'together — once', (tester) async {
      final repo = await toPasswordStep(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'password123');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.pump();
      await tester.ensureVisible(find.text('Password change karein'));
      await _settle(tester);
      await tester.tap(find.text('Password change karein'));
      await tester.tap(find.text('Password change karein'));
      await _settle(tester);

      expect(repo.forgotResetCalls, 1);
      expect(repo.lastResetPhone, '03378372427');
      expect(repo.lastResetOtp, '123456');
      expect(repo.lastResetPassword, 'password123');
    });

    testWidgets('success shows the confirmation, and Go to Login returns to '
        'the Ustaad login — never signed in', (tester) async {
      final repo = await toPasswordStep(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'password123');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.pump();
      await _tap(tester, find.text('Password change karein'));

      expect(find.text('Password change ho gaya'), findsOneWidget);
      expect(
        find.text('Ab apne naye password se Login karein.'),
        findsOneWidget,
      );
      // The reset endpoint issues no tokens, so nothing authenticated here.
      expect(repo.loginCalls, 0);

      await _tap(tester, find.text('Login par jayein'));
      expect(find.text('WORKER_LOGIN_PAGE'), findsOneWidget);
    });

    testWidgets('renders under the dark theme', (tester) async {
      await toPasswordStep(tester, theme: AppTheme.darkTheme);

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
        AppSemanticColors.dark.background,
      );
    });
  });

  group('responsive', () {
    for (final size in const [Size(320, 568), Size(360, 640)]) {
      testWidgets('the code step fits ${size.width.toInt()}x'
          '${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await _toCodeStep(tester);

        expect(tester.takeException(), isNull);
        expect(find.byType(ClientOtpField), findsOneWidget);
      });
    }

    testWidgets('a large text scale still lays out', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(_FakeAuthRepository()));
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _wrap(_FakeAuthRepository()),
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
    });
  });

  test('the reset screen names no palette literal of its own', () {
    final source = File(
      'lib/features/auth/presentation/pages/forgot_password_page.dart',
    )
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join(' ');

    for (final banned in const [
      'Color(0x',
      'Colors.orange',
      'Colors.teal',
      'Colors.green',
      'Colors.white',
      'Colors.black',
      'Colors.grey',
      'Brightness.dark',
    ]) {
      expect(source, isNot(contains(banned)), reason: 'names $banned');
    }
  });
}
