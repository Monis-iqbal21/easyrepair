import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:handygo_app/features/auth/domain/entities/auth_tokens_entity.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:handygo_app/features/auth/presentation/pages/client_account_ready_page.dart';
import 'package:handygo_app/features/auth/presentation/pages/client_login_page.dart';
import 'package:handygo_app/features/auth/presentation/pages/client_register_otp_page.dart';
import 'package:handygo_app/features/auth/presentation/pages/client_register_page.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:handygo_app/features/auth/presentation/widgets/client_auth_widgets.dart';
import 'package:handygo_app/features/auth/presentation/widgets/otp_input_section.dart'
    show otpLength;

/// The four CLIENT auth screens: their bilingual copy, that every navigation
/// target and API call is the one that already existed, and that nothing on
/// them names a colour.
///
/// Only two languages reach these screens through onboarding — Roman Urdu +
/// Easy English and English — so those are the two asserted. The Urdu locale
/// still exists in the ARB files and is covered by the l10n parity tests.

// ── Approved copy, spelled out verbatim ─────────────────────────────────────
// Deliberately not read back from AppLocalizations: reading the same source
// the pages read would pass whatever the wording became.
const _ru = (
  loginHeading: 'Khush aamdeed',
  loginSubtitle: 'Apna number aur password daalein.',
  phoneLabel: 'Mobile number',
  passwordLabel: 'Password',
  show: 'Dikhayein',
  forgot: 'Password bhool gaye?',
  login: 'Login',
  or: 'ya',
  otpLogin: 'Code se login karein',
  otpHelp: 'Code aap ke number par SMS aa jayega.',
  loginWithPassword: 'Password se login karein',
  noAccountFound:
      'Is number ka Client account nahi mila. Account banayein.',
  expiresIn: 'Code {t} mein expire hoga',
  expired: 'Code expire ho gaya hai. Naya code mangwayein.',
  newHere: 'Naye hain?',
  createAccount: 'Account banayein',
  registerSubtitle:
      'Sirf aik dafa. Aage se number aur password kaafi.',
  fullNameLabel: 'Poora naam',
  fullNameHint: 'Aap ka poora naam',
  mobileLabel: 'Mobile number',
  createPasswordLabel: 'Password banayein',
  createPasswordHint: 'Kam az kam 8 harf',
  confirmPasswordLabel: 'Password dobara',
  confirmPasswordHint: 'Password dobara likhein',
  infoBox: 'Pata abhi nahi chahiye. Pehli booking par poochenge.',
  sendOtp: 'Code bhejein',
  haveAccount: 'Pehle se account hai?',
  loginAction: 'Login karein',
  verifyHeading: 'Number verify karein',
  resendPrompt: 'Code nahi mila?',
  resend: 'Dobara bhejein',
  verifyButton: 'Verify kar ke account banayein',
  readyHeading: 'Account ready hai',
  readySubtitle: 'Welcome to HandyGo. Ab aap service book kar sakte hain.',
  accountCardLabel: 'AAP KA ACCOUNT',
  customer: 'Customer',
  goHome: 'Home par jayein',
);

const _en = (
  loginHeading: 'Welcome Back',
  loginSubtitle: 'Login with your mobile number and password.',
  phoneLabel: 'Mobile Number',
  passwordLabel: 'Password',
  show: 'Show',
  forgot: 'Forgot Password?',
  login: 'Login',
  or: 'OR',
  otpLogin: 'Login with OTP',
  otpHelp: 'An OTP will be sent to your registered mobile number.',
  loginWithPassword: 'Login with Password',
  noAccountFound:
      'No Client account was found for this number. Create an account.',
  expiresIn: 'Code expires in {t}',
  expired: 'The code has expired. Request a new one.',
  newHere: 'New here?',
  createAccount: 'Create Account',
  registerSubtitle:
      'Create your account once. After that, login with your mobile number and password.',
  fullNameLabel: 'Full name',
  fullNameHint: 'Enter your full name',
  mobileLabel: 'Mobile number',
  createPasswordLabel: 'Create password',
  createPasswordHint: 'At least 8 characters',
  confirmPasswordLabel: 'Confirm password',
  confirmPasswordHint: 'Enter your password again',
  infoBox:
      'We do not need your address yet. We will ask for it when you make your first booking.',
  sendOtp: 'Send OTP',
  haveAccount: 'Already have an account?',
  loginAction: 'Login',
  verifyHeading: 'Verify Mobile Number',
  resendPrompt: "Didn't receive the code?",
  resend: 'Resend',
  verifyButton: 'Verify & Create Account',
  readyHeading: 'Your account is ready',
  readySubtitle: 'Welcome to HandyGo. You can now book a service.',
  accountCardLabel: 'YOUR ACCOUNT',
  customer: 'Customer',
  goHome: 'Go to Home',
);

const _validPhone = '03378372427';
const _validPassword = 'password123';

class _FakeAuthRepository implements AuthRepository {
  int workerOtpVerifyCalls = 0;
  String? lastWorkerVerifyPhone;
  String? lastWorkerVerifyOtp;
  Failure? workerOtpVerifyFailure;

  int requestOtpCalls = 0;
  int clientOtpLoginCalls = 0;
  int passwordLoginCalls = 0;
  int passwordRegisterCalls = 0;

  Failure? requestOtpFailure;
  Failure? clientOtpLoginFailure;
  Failure? passwordLoginFailure;
  Failure? passwordRegisterFailure;

  String? lastLoginPhone;
  String? lastLoginPassword;
  String? lastRegisterName;
  String? lastRegisterPhone;
  String? lastRegisterPassword;
  String? lastOtp;
  String? lastRegisterOtp;
  OtpPurpose? lastOtpPurpose;
  String? lastPhoneChecked;

  int phoneCheckCalls = 0;
  ClientPhoneStatus phoneCheckResult = ClientPhoneStatus.client;
  Failure? phoneCheckFailure;

  Duration nextExpiresIn = const Duration(minutes: 5);

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
  Future<Either<Failure, AuthTokensEntity>> clientPasswordLogin({
    required String phone,
    required String password,
  }) async {
    passwordLoginCalls++;
    lastLoginPhone = phone;
    lastLoginPassword = password;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (passwordLoginFailure != null) return Left(passwordLoginFailure!);
    return Right(_tokens());
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> clientPasswordRegister({
    required String fullName,
    required String phone,
    required String password,
    required String otp,
  }) async {
    passwordRegisterCalls++;
    lastRegisterName = fullName;
    lastRegisterPhone = phone;
    lastRegisterPassword = password;
    lastRegisterOtp = otp;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (passwordRegisterFailure != null) return Left(passwordRegisterFailure!);
    return Right(_tokens());
  }

  @override
  Future<Either<Failure, DateTime>> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  }) async {
    requestOtpCalls++;
    lastOtpPurpose = purpose;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (requestOtpFailure != null) return Left(requestOtpFailure!);
    return Right(DateTime.now().add(nextExpiresIn));
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> clientOtpLogin({
    required String phone,
    required String otp,
  }) async {
    clientOtpLoginCalls++;
    lastOtp = otp;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (clientOtpLoginFailure != null) return Left(clientOtpLoginFailure!);
    return Right(_tokens());
  }

  /// The backend's authoritative answer to "does this number have a Client
  /// account?". A Worker-owned number reports NEW, exactly like an unknown
  /// one — the privacy rule the real endpoint enforces.
  @override
  Future<Either<Failure, ClientPhoneStatus>> checkClientPhoneStatus(
    String phone,
  ) async {
    phoneCheckCalls++;
    lastPhoneChecked = phone;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (phoneCheckFailure != null) return Left(phoneCheckFailure!);
    return Right(phoneCheckResult);
  }
  @override
  Future<Either<Failure, DateTime>> clientForgotPasswordRequest(String p) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, void>> clientForgotPasswordReset({
    required String phone,
    required String otp,
    required String newPassword,
  }) =>
      throw UnimplementedError();
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
  }) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, AuthTokensEntity>> workerOtpLogin({
    required String phone,
    required String otp,
  }) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, AuthTokensEntity>> register({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String? categoryId,
  }) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, AuthTokensEntity>> login({
    required String phone,
    required String password,
  }) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, void>> logout() => throw UnimplementedError();
  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, DateTime>> forgotPasswordRequest(String p) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, void>> forgotPasswordReset({
    required String phone,
    required String otp,
    required String newPassword,
  }) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, void>> deleteAccount() => throw UnimplementedError();
}

/// Reports what the session says, without any network — the success screen
/// reads this for the real account details.
class _FakeAuthState extends AuthStateNotifier {
  _FakeAuthState(this._user);
  final UserEntity? _user;
  @override
  Future<UserEntity?> build() async => _user;
}

/// The real routes the flow uses, plus stubs for everything it can leave to.
GoRouter _router(String initialLocation, {Object? extra}) => GoRouter(
      initialLocation: initialLocation,
      initialExtra: extra,
      routes: [
        GoRoute(
          path: ClientLoginPage.route,
          builder: (_, _) => const ClientLoginPage(),
        ),
        GoRoute(
          // Kept as a redirect so an old deep link still lands somewhere sane.
          path: '/auth/client/otp-login',
          redirect: (_, _) => ClientLoginPage.route,
        ),
        GoRoute(
          path: ClientRegisterPage.route,
          builder: (_, _) => const ClientRegisterPage(),
        ),
        GoRoute(
          path: ClientRegisterOtpPage.route,
          builder: (_, state) => ClientRegisterOtpPage(
            draft: state.extra! as ClientRegistrationDraft,
          ),
        ),
        GoRoute(
          path: ClientAccountReadyPage.route,
          builder: (_, state) => ClientAccountReadyPage(
            summary: state.extra as ClientAccountSummary?,
          ),
        ),
        GoRoute(
          path: '/auth/client/forgot-password',
          builder: (_, _) => const Scaffold(body: Text('FORGOT_PASSWORD')),
        ),
        GoRoute(
          path: '/client/home',
          builder: (_, _) => const Scaffold(body: Text('CLIENT_HOME')),
        ),
      ],
    );

Future<_FakeAuthRepository> _pump(
  WidgetTester tester, {
  String at = ClientLoginPage.route,
  Object? extra,
  AppLocale locale = AppLocale.romanUrdu,
  ThemeData? theme,
  Size size = const Size(390, 844),
  double textScale = 1.0,
  UserEntity? user,
  _FakeAuthRepository? repo,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repository = repo ?? _FakeAuthRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        authStateProvider.overrideWith(() => _FakeAuthState(user)),
      ],
      child: MaterialApp.router(
        theme: theme ?? AppTheme.lightTheme,
        routerConfig: _router(at, extra: extra),
        locale: locale.locale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        localeResolutionCallback: (_, _) => locale.locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await _settle(tester);
  return repository;
}

ClientRegistrationDraft _draft() => const ClientRegistrationDraft(
      fullName: 'Ali Khan',
      phone: _validPhone,
      password: _validPassword,
    );

/// Advances a bounded number of frames instead of `pumpAndSettle`.
///
/// The OTP screens autofocus a Pinput field, and an focused text field is a
/// perpetual animation, so `pumpAndSettle` never returns there — the same
/// reason `otp_input_section_test.dart` never calls it either. Bounded pumps
/// cover the fake repository's 30ms latency and GoRouter's transition with
/// room to spare.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Asserts the rendered expiry line shows a real MM:SS clock.
///
/// The exact seconds are wall-clock dependent — asserting "04:5x" makes the
/// test flaky the moment the machine is busy — so this checks the shape and
/// that it is counting within the code's five-minute validity.
void _expectCountdown(WidgetTester tester) {
  final clock = RegExp(r'0[0-5]:[0-5][0-9]');
  final lines = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where(clock.hasMatch)
      .toList();

  expect(lines, hasLength(1), reason: 'exactly one countdown is on screen');
}

/// Walks registration step 1 in the dark theme so the OTP screen it opens
/// has a real backend expiry behind it.
Future<void> _pumpRegisterOtpDark(WidgetTester tester) async {
  await _pump(
    tester,
    at: ClientRegisterPage.route,
    theme: AppTheme.darkTheme,
  );
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Ali Khan');
  await tester.enterText(fields.at(1), _validPhone);
  await tester.enterText(fields.at(2), _validPassword);
  await tester.enterText(fields.at(3), _validPassword);
  await tester.pump();
  await tester.ensureVisible(find.text(_ru.sendOtp));
  await _settle(tester);
  await tester.tap(find.text(_ru.sendOtp));
  await _settle(tester);

  expect(tester.takeException(), isNull);
  expect(find.byType(ClientRegisterOtpPage), findsOneWidget);
  expect(
    tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
    AppSemanticColors.dark.background,
  );
}

/// Scrolls [finder] into view, then taps it — these forms are taller than a
/// small phone by design, so the CTA and footer legitimately live below the
/// fold until the user scrolls.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _settle(tester);
  await tester.tap(finder);
  await _settle(tester);
}

/// The enabled/disabled state of the visible screen's primary CTA.
///
/// `.last`, because a pushed route leaves the previous page in the tree
/// beneath it — the topmost route's widgets come last.
bool _primaryEnabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byType(ElevatedButton).last).enabled;

AppSemanticColors _colors(WidgetTester tester, Type page) =>
    tester.element(find.byType(page)).semanticColors;

Future<void> _enterOtp(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(EditableText).last, code);
  await _settle(tester);
}

void main() {
  setUp(() {
    // The OTP boxes autofocus, and a blinking text cursor is an animation
    // that never ends — pumpAndSettle would wait for it forever. This is
    // Flutter's documented switch for exactly that.
    EditableText.debugDeterministicCursor = true;
  });
  tearDown(() => EditableText.debugDeterministicCursor = false);

  // ══ SCREEN 1 — LOGIN ═══════════════════════════════════════════════════
  group('Client login — copy', () {
    testWidgets('Roman Urdu matches the approved wording exactly',
        (tester) async {
      await _pump(tester);

      for (final text in [
        _ru.loginHeading,
        _ru.loginSubtitle,
        _ru.phoneLabel,
        _ru.forgot,
        _ru.login,
        _ru.or,
        _ru.otpLogin,
        _ru.otpHelp,
        _ru.newHere,
        _ru.createAccount,
      ]) {
        expect(find.text(text), findsWidgets, reason: 'missing: $text');
      }
      // The password label and its placeholder are the same word.
      expect(find.text(_ru.passwordLabel), findsWidgets);
      expect(find.text(_ru.show), findsOneWidget);
      expect(find.text(kPkDialCode), findsOneWidget);
      expect(find.text(kPkPhoneHint), findsOneWidget);
    });

    testWidgets('English is fully English', (tester) async {
      await _pump(tester, locale: AppLocale.english);

      expect(find.text(_en.loginSubtitle), findsOneWidget);
      expect(find.text(_en.otpHelp), findsOneWidget);
      expect(find.text(_ru.loginSubtitle), findsNothing);
      expect(find.text(_ru.otpHelp), findsNothing);
    });

    testWidgets('no Urdu script leaks into the Roman Urdu screen',
        (tester) async {
      await _pump(tester);

      final urduScript = RegExp(r'[؀-ۿ]');
      final leaked = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where(urduScript.hasMatch)
          .toList();
      expect(leaked, isEmpty);
    });
  });

  group('Client login — behaviour', () {
    testWidgets('the CTA is disabled until phone and password are both valid',
        (tester) async {
      await _pump(tester);
      expect(_primaryEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextFormField).first, '0300');
      await tester.pump();
      expect(_primaryEnabled(tester), isFalse,
          reason: 'an incomplete number must not enable it');

      await tester.enterText(find.byType(TextFormField).first, _validPhone);
      await tester.pump();
      expect(_primaryEnabled(tester), isFalse,
          reason: 'the password is still empty');

      await tester.enterText(find.byType(TextFormField).at(1), _validPassword);
      await tester.pump();
      expect(_primaryEnabled(tester), isTrue);
    });

    testWidgets('submitting calls the existing password-login API, once',
        (tester) async {
      final repo = await _pump(tester);

      await tester.enterText(find.byType(TextFormField).first, _validPhone);
      await tester.enterText(find.byType(TextFormField).at(1), _validPassword);
      await tester.pump();

      await tester.ensureVisible(find.text(_ru.login));
      await _settle(tester);
      await tester.tap(find.text(_ru.login));
      await tester.tap(find.text(_ru.login)); // second tap, request in flight
      await _settle(tester);

      expect(repo.passwordLoginCalls, 1);
      expect(repo.lastLoginPhone, _validPhone);
      expect(repo.lastLoginPassword, _validPassword);
    });

    testWidgets('Show reveals the password without clearing it',
        (tester) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextFormField).at(1), _validPassword);
      await tester.pump();

      EditableText field() => tester.widget<EditableText>(
            find.byType(EditableText).at(1),
          );
      expect(field().obscureText, isTrue);

      await _tap(tester, find.text(_ru.show));

      expect(field().obscureText, isFalse);
      expect(field().controller.text, _validPassword,
          reason: 'toggling visibility must never touch the value');
    });

    testWidgets('Forgot Password opens the existing Client reset route',
        (tester) async {
      await _pump(tester);

      await _tap(tester, find.text(_ru.forgot));

      expect(find.text('FORGOT_PASSWORD'), findsOneWidget);
    });

    testWidgets('Login with OTP switches THIS page into OTP mode — it never '
        'pushes another page', (tester) async {
      final repo = await _pump(tester);
      repo.phoneCheckResult = ClientPhoneStatus.client;
      await tester.enterText(find.byType(TextFormField).first, _validPhone);
      await tester.pump();

      await _tap(tester, find.text(_ru.otpLogin));

      expect(repo.requestOtpCalls, 1);
      expect(find.byType(ClientLoginPage), findsOneWidget,
          reason: 'still the same screen');
      expect(find.text(_ru.loginWithPassword), findsOneWidget);
    });

    testWidgets('Create Account opens the registration flow', (tester) async {
      await _pump(tester);

      await _tap(tester, find.text(_ru.createAccount));

      expect(find.byType(ClientRegisterPage), findsOneWidget);
    });
  });

  // ══ INLINE OTP LOGIN MODE ══════════════════════════════════════════════
  group('Client login — inline OTP mode', () {
    /// Types a valid number and taps "Login with OTP", leaving the page in
    /// OTP mode with a live code.
    Future<_FakeAuthRepository> enterOtpMode(
      WidgetTester tester, {
      _FakeAuthRepository? repo,
      Size size = const Size(390, 844),
      ThemeData? theme,
      AppLocale locale = AppLocale.romanUrdu,
    }) async {
      final r = await _pump(tester, repo: repo, size: size, theme: theme,
          locale: locale);
      r.phoneCheckResult = ClientPhoneStatus.client;
      await tester.enterText(find.byType(TextFormField).first, _validPhone);
      await tester.pump();
      // The CTA is localised, so the label to tap depends on [locale]. Tapping
      // the Roman Urdu one unconditionally only ever worked because the Roman
      // Urdu string *was* the untranslated English "Login with OTP" — the
      // exact leftover this wording pass removed.
      final otpLoginLabel =
          locale == AppLocale.english ? _en.otpLogin : _ru.otpLogin;
      await _tap(tester, find.text(otpLoginLabel));
      return r;
    }

    testWidgets('the page opens in password mode', (tester) async {
      await _pump(tester);

      expect(find.text(_ru.passwordLabel), findsWidgets);
      expect(find.text(_ru.forgot), findsOneWidget);
      expect(find.text(_ru.otpLogin), findsOneWidget);
      expect(find.byType(ClientOtpField), findsNothing);
      expect(find.text(_ru.loginWithPassword), findsNothing);
    });

    testWidgets('the login screen has no name field, in either mode',
        (tester) async {
      final repo = await _pump(tester);

      // Password mode: phone + password, nothing else.
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text(_ru.fullNameLabel), findsNothing);
      expect(find.text(_ru.fullNameHint), findsNothing);

      await tester.enterText(find.byType(TextFormField).first, _validPhone);
      await tester.pump();
      repo.phoneCheckResult = ClientPhoneStatus.client;
      await _tap(tester, find.text(_ru.otpLogin));

      // OTP mode: phone + the code boxes, still no name.
      expect(find.text(_ru.fullNameLabel), findsNothing);
      expect(find.text(_ru.fullNameHint), findsNothing);
      expect(find.byType(ClientOtpField), findsOneWidget);
    });

    testWidgets('logging in by OTP sends only the phone and the code — no '
        'name, and never the phone standing in for one', (tester) async {
      final repo = await enterOtpMode(tester);

      await _enterOtp(tester, '123456');

      expect(repo.clientOtpLoginCalls, 1);
      expect(repo.lastOtp, '123456');
      // The old contract took a fullName and the page passed the phone as
      // one. There is no name on this call any more — the repository method
      // does not have the parameter, which is what this asserts by compiling.
      expect(repo.lastRegisterName, isNull,
          reason: 'login must never touch registration data');
      expect(repo.passwordRegisterCalls, 0);
    });

    testWidgets('a number with no Client account never gets a code, and is '
        'pointed at registration instead', (tester) async {
      final repo = await _pump(tester);
      repo.phoneCheckResult = ClientPhoneStatus.newAccount;
      await tester.enterText(find.byType(TextFormField).first, _validPhone);
      await tester.pump();

      await _tap(tester, find.text(_ru.otpLogin));

      expect(repo.phoneCheckCalls, 1);
      expect(repo.requestOtpCalls, 0, reason: 'no SMS for a non-Client');
      expect(find.byType(ClientOtpField), findsNothing);
      expect(find.text(_ru.noAccountFound), findsOneWidget);
      expect(find.text(_ru.createAccount), findsWidgets,
          reason: 'the message offers the way forward');
    });

    testWidgets('a Worker-owned number is indistinguishable from an unknown '
        'one', (tester) async {
      // The backend reports a Worker-owned number as NEW; the app must not
      // render anything role-specific on top of that.
      final repo = await _pump(tester);
      repo.phoneCheckResult = ClientPhoneStatus.newAccount;
      await tester.enterText(find.byType(TextFormField).first, _validPhone);
      await tester.pump();

      await _tap(tester, find.text(_ru.otpLogin));

      expect(repo.requestOtpCalls, 0);
      expect(find.text(_ru.noAccountFound), findsOneWidget);
      expect(find.textContaining('Ustaad'), findsNothing);
      expect(find.textContaining('Worker'), findsNothing);
    });

    testWidgets('an existing Client is confirmed by the backend before the '
        'code is sent', (tester) async {
      final repo = await enterOtpMode(tester);

      expect(repo.phoneCheckCalls, 1);
      expect(repo.lastPhoneChecked, _validPhone);
      expect(repo.requestOtpCalls, 1);
      expect(find.byType(ClientOtpField), findsOneWidget);
    });

    testWidgets('an invalid phone requests nothing and shows the existing '
        'validation message', (tester) async {
      final repo = await _pump(tester);
      await tester.enterText(find.byType(TextFormField).first, '0300');
      await tester.pump();

      await _tap(tester, find.text(_ru.otpLogin));

      expect(repo.phoneCheckCalls, 0,
          reason: 'a malformed number never reaches the network at all');
      expect(repo.requestOtpCalls, 0);
      expect(find.byType(ClientOtpField), findsNothing,
          reason: 'an invalid number must not open OTP mode');
      expect(
        find.text('Sahi Pakistani mobile number likhein.'),
        findsOneWidget,
      );
    });

    testWidgets('OTP mode hides the password field and Forgot Password',
        (tester) async {
      await enterOtpMode(tester);

      expect(find.text(_ru.forgot), findsNothing);
      expect(find.text(_ru.show), findsNothing);
      expect(find.byType(ClientOtpField), findsOneWidget);
    });

    testWidgets('OTP mode renders exactly six boxes', (tester) async {
      await enterOtpMode(tester);

      // Pinput draws one EditableText plus one box per digit; the length it
      // uses is the shared backend-owned constant.
      expect(otpLength, 6);
      final field = tester.widget<ClientOtpField>(find.byType(ClientOtpField));
      expect(field.hasError, isFalse);
      expect(find.byType(Pinput), findsOneWidget);
      expect(tester.widget<Pinput>(find.byType(Pinput)).length, 6);
    });

    testWidgets('OTP mode shows the expiry countdown from the backend expiry',
        (tester) async {
      await enterOtpMode(tester);

      expect(find.textContaining('mein expire hoga'), findsOneWidget);
      _expectCountdown(tester);
    });

    testWidgets('the Login button is disabled below six digits and enabled at '
        'six', (tester) async {
      await enterOtpMode(tester);
      expect(_primaryEnabled(tester), isFalse);

      await _enterOtp(tester, '12345');
      expect(_primaryEnabled(tester), isFalse);

      await _enterOtp(tester, '123456');
      expect(_primaryEnabled(tester), isTrue);
    });

    testWidgets('a completed code submits through the existing Client OTP '
        'notifier', (tester) async {
      final repo = await enterOtpMode(tester);

      // Entering the last digit auto-submits — the same courtesy the Ustaad
      // and password-reset OTP screens have always had.
      await _enterOtp(tester, '123456');

      expect(repo.clientOtpLoginCalls, 1);
      expect(repo.lastOtp, '123456');
    });

    testWidgets('the Login button submits the same way', (tester) async {
      final repo = _FakeAuthRepository()
        ..clientOtpLoginFailure = const ServerFailure('bad code');
      await enterOtpMode(tester, repo: repo);

      await _enterOtp(tester, '123456'); // auto-submit, rejected
      expect(repo.clientOtpLoginCalls, 1);

      repo.clientOtpLoginFailure = null;
      await _tap(tester, find.text(_ru.login));

      expect(repo.clientOtpLoginCalls, 2,
          reason: 'the button retries through the very same notifier');
    });

    testWidgets('an expired code disables Login and says so', (tester) async {
      final repo = _FakeAuthRepository()
        // Already past its expiry the moment it arrives.
        ..nextExpiresIn = const Duration(seconds: -1);
      await enterOtpMode(tester, repo: repo);

      await _enterOtp(tester, '123456');

      expect(find.text(_ru.expired), findsOneWidget);
      expect(_primaryEnabled(tester), isFalse,
          reason: 'an expired code must never be submittable');
    });

    testWidgets('Resend is unavailable during the backend cooldown',
        (tester) async {
      final repo = await enterOtpMode(tester);

      // A code was just requested, so the 60s cooldown is running.
      expect(find.textContaining('Code dobara bhejein ('), findsOneWidget);
      expect(find.text(_ru.resend), findsNothing);

      await _tap(tester, find.textContaining('Code dobara bhejein ('));
      expect(repo.requestOtpCalls, 1, reason: 'the tap must be inert');
    });

    testWidgets('Resend becomes available once the cooldown has elapsed, and '
        'requests exactly one new code', (tester) async {
      // An expiry only 10s out means the request was made 4m50s ago, so the
      // 60-second cooldown is long gone — the same trick OtpInputSection's
      // own tests use to avoid waiting on a real timer.
      final repo = _FakeAuthRepository()
        ..nextExpiresIn = const Duration(seconds: 10);
      await enterOtpMode(tester, repo: repo);

      expect(find.text(_ru.resend), findsOneWidget);

      await _tap(tester, find.text(_ru.resend));

      expect(repo.requestOtpCalls, 2);
      expect(repo.lastOtpPurpose, OtpPurpose.clientLoginRegister);
    });

    testWidgets('rapid taps cannot fire two OTP requests', (tester) async {
      final repo = await _pump(tester);
      repo.phoneCheckResult = ClientPhoneStatus.client;
      await tester.enterText(find.byType(TextFormField).first, _validPhone);
      await tester.pump();

      await tester.ensureVisible(find.text(_ru.otpLogin));
      await _settle(tester);
      await tester.tap(find.text(_ru.otpLogin));
      await tester.tap(find.text(_ru.otpLogin));
      await _settle(tester);

      expect(repo.requestOtpCalls, 1);
    });

    testWidgets('editing the phone invalidates the code requested for the old '
        'number', (tester) async {
      final repo = await enterOtpMode(tester);
      await _enterOtp(tester, '123456');
      expect(find.byType(ClientOtpField), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '03001234567');
      await _settle(tester);

      expect(find.byType(ClientOtpField), findsNothing,
          reason: 'the old code does not belong to the new number');
      expect(find.textContaining('mein expire hoga'), findsNothing,
          reason: 'and neither does its countdown');
      expect(repo.requestOtpCalls, 1,
          reason: 'editing must never auto-send another code');
    });

    testWidgets('Login with Password returns the same page to password mode, '
        'keeping the phone', (tester) async {
      await enterOtpMode(tester);

      await _tap(tester, find.text(_ru.loginWithPassword));

      expect(find.byType(ClientLoginPage), findsOneWidget);
      expect(find.byType(ClientOtpField), findsNothing);
      expect(find.text(_ru.forgot), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText).first).controller.text,
        _validPhone,
        reason: 'the typed number survives the switch',
      );
    });

    testWidgets('a password typed before switching to OTP mode is still there '
        'on the way back', (tester) async {
      await _pump(tester);
      await tester.enterText(find.byType(TextFormField).first, _validPhone);
      await tester.enterText(find.byType(TextFormField).at(1), _validPassword);
      await tester.pump();

      await _tap(tester, find.text(_ru.otpLogin));
      await _tap(tester, find.text(_ru.loginWithPassword));

      expect(
        tester.widget<EditableText>(find.byType(EditableText).at(1)).controller.text,
        _validPassword,
      );
    });

    testWidgets('English wording for the OTP mode controls', (tester) async {
      await enterOtpMode(tester, locale: AppLocale.english);

      expect(find.text(_en.loginWithPassword), findsOneWidget);
      expect(find.text(_en.resendPrompt), findsOneWidget);
      expect(find.textContaining('Code expires in'), findsOneWidget);
    });

    testWidgets('OTP mode renders from the dark palette', (tester) async {
      await enterOtpMode(tester, theme: AppTheme.darkTheme);

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppSemanticColors.dark.background,
      );
    });

    testWidgets('OTP mode fits a 320x568 screen without overflowing',
        (tester) async {
      await enterOtpMode(tester, size: const Size(320, 568));

      expect(tester.takeException(), isNull);
      expect(find.byType(ClientOtpField), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  // ══ SCREEN 2 — REGISTER STEP 1 ═════════════════════════════════════════
  group('Client registration step 1 — copy', () {
    testWidgets('Roman Urdu matches the approved wording exactly',
        (tester) async {
      await _pump(tester, at: ClientRegisterPage.route);

      for (final text in [
        _ru.createAccount,
        _ru.registerSubtitle,
        _ru.fullNameLabel,
        _ru.fullNameHint,
        _ru.mobileLabel,
        _ru.createPasswordLabel,
        _ru.createPasswordHint,
        _ru.confirmPasswordLabel,
        _ru.confirmPasswordHint,
        _ru.infoBox,
        _ru.sendOtp,
        _ru.haveAccount,
        _ru.loginAction,
      ]) {
        expect(find.text(text), findsWidgets, reason: 'missing: $text');
      }
    });

    testWidgets('English matches the approved wording exactly', (tester) async {
      await _pump(
        tester,
        at: ClientRegisterPage.route,
        locale: AppLocale.english,
      );

      for (final text in [
        _en.registerSubtitle,
        _en.fullNameHint,
        _en.createPasswordHint,
        _en.confirmPasswordHint,
        _en.infoBox,
        _en.haveAccount,
      ]) {
        expect(find.text(text), findsWidgets, reason: 'missing: $text');
      }
      expect(find.text(_ru.registerSubtitle), findsNothing);
    });
  });

  group('Client registration step 1 — validation is unchanged', () {
    Future<void> fill(
      WidgetTester tester, {
      String name = 'Ali Khan',
      String phone = _validPhone,
      String password = _validPassword,
      String? confirm,
    }) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), name);
      await tester.enterText(fields.at(1), phone);
      await tester.enterText(fields.at(2), password);
      await tester.enterText(fields.at(3), confirm ?? password);
      await tester.pump();
    }

    testWidgets('Send OTP stays disabled until every rule is satisfied',
        (tester) async {
      await _pump(tester, at: ClientRegisterPage.route);
      expect(_primaryEnabled(tester), isFalse);

      await fill(tester, name: '');
      expect(_primaryEnabled(tester), isFalse, reason: 'name is required');

      await fill(tester, phone: '0300');
      expect(_primaryEnabled(tester), isFalse, reason: 'phone must be valid');

      await fill(tester, password: 'short12');
      expect(_primaryEnabled(tester), isFalse,
          reason: 'password must be at least 8 characters');

      await fill(tester, confirm: 'different1');
      expect(_primaryEnabled(tester), isFalse,
          reason: 'confirmation must match');

      await fill(tester);
      expect(_primaryEnabled(tester), isTrue);
    });

    testWidgets('Send OTP uses the existing request API and purpose, once',
        (tester) async {
      final repo = await _pump(tester, at: ClientRegisterPage.route);
      await fill(tester);

      await tester.ensureVisible(find.text(_ru.sendOtp));
      await _settle(tester);
      await tester.tap(find.text(_ru.sendOtp));
      await tester.tap(find.text(_ru.sendOtp));
      await _settle(tester);

      expect(repo.requestOtpCalls, 1);
      expect(repo.lastOtpPurpose, OtpPurpose.clientLoginRegister);
      expect(find.byType(ClientRegisterOtpPage), findsOneWidget);
    });

    testWidgets('a failed request stays on the form and creates nothing',
        (tester) async {
      final repo = _FakeAuthRepository()
        ..requestOtpFailure = const ServerFailure('nope');
      await _pump(tester, at: ClientRegisterPage.route, repo: repo);
      await fill(tester);

      await _tap(tester, find.text(_ru.sendOtp));

      expect(find.byType(ClientRegisterOtpPage), findsNothing);
      expect(repo.passwordRegisterCalls, 0);
    });

    testWidgets('the login footer action returns to login', (tester) async {
      await _pump(tester);
      await _tap(tester, find.text(_ru.createAccount));
      await _tap(tester, find.text(_ru.loginAction));

      expect(find.byType(ClientLoginPage), findsOneWidget);
    });
  });

  // ══ SCREEN 3 — REGISTRATION OTP ════════════════════════════════════════
  group('Client registration OTP', () {
    /// Fills step 1 and taps Send OTP, landing on the OTP screen with a live
    /// backend expiry — the only way a user ever reaches it.
    Future<_FakeAuthRepository> reachRegisterOtp(
      WidgetTester tester, {
      _FakeAuthRepository? repo,
      AppLocale locale = AppLocale.romanUrdu,
      ThemeData? theme,
      Size size = const Size(390, 844),
    }) async {
      final r = await _pump(
        tester,
        at: ClientRegisterPage.route,
        repo: repo,
        locale: locale,
        theme: theme,
        size: size,
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Ali Khan');
      await tester.enterText(fields.at(1), _validPhone);
      await tester.enterText(fields.at(2), _validPassword);
      await tester.enterText(fields.at(3), _validPassword);
      await tester.pump();
      await _tap(tester, find.text(_ru.sendOtp));
      return r;
    }

    testWidgets('Roman Urdu wording, with the real number rendered',
        (tester) async {
      await _pump(
        tester,
        at: ClientRegisterOtpPage.route,
        extra: _draft(),
      );

      expect(find.text(_ru.verifyHeading), findsOneWidget);
      expect(find.text(_ru.resendPrompt), findsOneWidget);
      expect(find.text(_ru.resend), findsOneWidget);
      expect(find.text(_ru.verifyButton), findsOneWidget);
      expect(
        find.text('$otpLength-digit code +92 337 837 2427 par bheja gaya.'),
        findsOneWidget,
        reason: 'the number is formatted from the draft, never hardcoded',
      );
    });

    testWidgets('English wording, with the same real number', (tester) async {
      await _pump(
        tester,
        at: ClientRegisterOtpPage.route,
        extra: _draft(),
        locale: AppLocale.english,
      );

      expect(find.text(_en.resendPrompt), findsOneWidget);
      expect(
        find.text('A $otpLength-digit code was sent to +92 337 837 2427.'),
        findsOneWidget,
      );
    });

    testWidgets('renders exactly one box per backend OTP digit',
        (tester) async {
      await _pump(tester, at: ClientRegisterOtpPage.route, extra: _draft());

      // Pinput renders its boxes from the shared, backend-owned length.
      expect(
        tester.widgetList(find.byType(ClientOtpField)).length,
        1,
      );
      final field = tester.widget<ClientOtpField>(find.byType(ClientOtpField));
      expect(field.hasError, isFalse);
      expect(otpLength, 6,
          reason: 'AuthService issues 6 digits and every verify DTO '
              'rejects anything else');
    });

    testWidgets('verify is disabled until the code is complete, then enabled',
        (tester) async {
      final repo = _FakeAuthRepository()
        // Rejected, so the auto-submit on the sixth digit leaves the button
        // visible and enabled instead of navigating away.
        ..clientOtpLoginFailure = const ServerFailure('bad code');
      await reachRegisterOtp(tester, repo: repo);
      expect(_primaryEnabled(tester), isFalse);

      await _enterOtp(tester, '123');
      expect(_primaryEnabled(tester), isFalse);

      await _enterOtp(tester, '1' * otpLength);
      expect(_primaryEnabled(tester), isTrue);

      // The rejection raised a SnackBar; let it retire so the test does not
      // end with its timer still pending.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('shows the expiry countdown and the resend cooldown from the '
        'backend expiry', (tester) async {
      await reachRegisterOtp(tester);

      expect(find.textContaining('mein expire hoga'), findsOneWidget);
      _expectCountdown(tester);
      expect(find.text(_ru.resendPrompt), findsOneWidget);
      expect(find.textContaining('Code dobara bhejein ('), findsOneWidget,
          reason: 'a code was just sent, so resend is on cooldown');
    });

    testWidgets('an expired code disables Verify & Create Account',
        (tester) async {
      final repo = _FakeAuthRepository()
        ..nextExpiresIn = const Duration(seconds: -1);
      await reachRegisterOtp(tester, repo: repo);

      await _enterOtp(tester, '1' * otpLength);

      expect(find.text(_ru.expired), findsOneWidget);
      expect(_primaryEnabled(tester), isFalse);
      expect(repo.passwordRegisterCalls, 0,
          reason: 'an expired code must never start account creation');
    });

    testWidgets('the step-1 details survive the OTP stage', (tester) async {
      final repo = await reachRegisterOtp(tester);

      await _enterOtp(tester, '1' * otpLength);
      await _settle(tester);

      expect(repo.lastRegisterName, 'Ali Khan');
      expect(repo.lastRegisterPhone, _validPhone);
      expect(repo.lastRegisterPassword, _validPassword);
      expect(repo.lastRegisterOtp, '1' * otpLength);
    });

    testWidgets('registration still collects a full name — the field login '
        'must never have', (tester) async {
      await _pump(tester, at: ClientRegisterPage.route);

      expect(find.text(_ru.fullNameLabel), findsOneWidget);
      expect(find.text(_ru.fullNameHint), findsOneWidget);
    });

    testWidgets(
        'a complete code creates the account with the chosen password, then '
        'verifies the number, then lands on the success screen',
        (tester) async {
      final repo = await reachRegisterOtp(tester);

      await _enterOtp(tester, '1' * otpLength);
      await _settle(tester);

      expect(repo.passwordRegisterCalls, 1);
      expect(repo.lastRegisterName, 'Ali Khan');
      expect(repo.lastRegisterPhone, _validPhone);
      expect(repo.lastRegisterPassword, _validPassword,
          reason: 'the password the user chose must actually be set');
      expect(repo.lastRegisterOtp, '1' * otpLength,
          reason: 'the code travels with the registration, in one call');
      expect(repo.clientOtpLoginCalls, 0,
          reason: 'registration no longer borrows the login endpoint');
      expect(find.byType(ClientAccountReadyPage), findsOneWidget);
    });

    testWidgets('a rejected code creates nothing, and the retry succeeds',
        (tester) async {
      final repo = _FakeAuthRepository()
        ..passwordRegisterFailure = const ServerFailure('bad code');
      await reachRegisterOtp(tester, repo: repo);

      await _enterOtp(tester, '1' * otpLength);
      await _settle(tester);
      expect(find.byType(ClientAccountReadyPage), findsNothing,
          reason: 'a rejected code must not produce an account');

      repo.passwordRegisterFailure = null;
      await _enterOtp(tester, '2' * otpLength);
      await _settle(tester);

      expect(repo.lastRegisterOtp, '2' * otpLength);
      expect(find.byType(ClientAccountReadyPage), findsOneWidget);

      // Let the rejection SnackBar retire before the test ends.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Resend is blocked during the cooldown and reuses the existing '
        'OTP provider once it elapses', (tester) async {
      // A 10-second expiry means the request happened 4m50s ago, so the
      // 60-second cooldown is long past — the same trick the shared OTP
      // widget's own tests use to avoid waiting on a real timer.
      final repo = _FakeAuthRepository()
        ..nextExpiresIn = const Duration(seconds: 10);
      await reachRegisterOtp(tester, repo: repo);
      expect(repo.requestOtpCalls, 1);

      await _tap(tester, find.text(_ru.resend));

      expect(repo.requestOtpCalls, 2);
      expect(repo.lastOtpPurpose, OtpPurpose.clientLoginRegister);
    });
  });

  // ══ SCREEN 4 — ACCOUNT READY ═══════════════════════════════════════════
  group('Client account ready', () {
    const summary = ClientAccountSummary(
      fullName: 'Ali Khan',
      phone: _validPhone,
    );
    const sessionUser = UserEntity(
      id: 'u1',
      phone: '+923378372427',
      role: 'CLIENT',
      firstName: 'Ali',
      lastName: 'Khan',
    );

    testWidgets('Roman Urdu wording', (tester) async {
      await _pump(
        tester,
        at: ClientAccountReadyPage.route,
        extra: summary,
        user: sessionUser,
      );

      expect(find.text(_ru.readyHeading), findsOneWidget);
      expect(find.text(_ru.readySubtitle), findsOneWidget);
      expect(find.text(_ru.accountCardLabel), findsOneWidget);
      expect(find.text(_ru.goHome), findsOneWidget);
    });

    testWidgets('English wording', (tester) async {
      await _pump(
        tester,
        at: ClientAccountReadyPage.route,
        extra: summary,
        user: sessionUser,
        locale: AppLocale.english,
      );

      expect(find.text(_en.readyHeading), findsOneWidget);
      expect(find.text(_en.readySubtitle), findsOneWidget);
      expect(find.text(_en.accountCardLabel), findsOneWidget);
    });

    testWidgets('shows the real account, not the mock from the design',
        (tester) async {
      await _pump(
        tester,
        at: ClientAccountReadyPage.route,
        extra: summary,
        user: sessionUser,
      );

      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('+92 337 837 2427 · ${_ru.customer}'), findsOneWidget);
      expect(find.text('monis'), findsNothing);
      expect(find.textContaining('338 939 3923'), findsNothing);
    });

    testWidgets('falls back to the just-registered details before the session '
        'resolves', (tester) async {
      await _pump(
        tester,
        at: ClientAccountReadyPage.route,
        extra: summary,
      );

      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('+92 337 837 2427 · ${_ru.customer}'), findsOneWidget);
    });

    testWidgets('Go to Home uses the existing Client home route',
        (tester) async {
      await _pump(
        tester,
        at: ClientAccountReadyPage.route,
        extra: summary,
        user: sessionUser,
      );

      await _tap(tester, find.text(_ru.goHome));

      expect(find.text('CLIENT_HOME'), findsOneWidget);
    });

    testWidgets('the success mark and card paint from semantic tokens',
        (tester) async {
      await _pump(
        tester,
        at: ClientAccountReadyPage.route,
        extra: summary,
        user: sessionUser,
      );
      final colors = _colors(tester, ClientAccountReadyPage);

      expect(
        tester.widget<Icon>(find.byIcon(Icons.check_rounded)).color,
        colors.success,
      );
      final tile = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.check_rounded),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((tile.decoration! as BoxDecoration).color, colors.softTeal);
    });
  });

  // ══ COLOUR, THEME, LAYOUT ══════════════════════════════════════════════
  group('colour architecture', () {
    testWidgets('the login canvas is the semantic background', (tester) async {
      await _pump(tester);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        _colors(tester, ClientLoginPage).background,
      );
    });

    testWidgets('the primary CTA paints from primary/onPrimary and its '
        'disabled state from the muted surface', (tester) async {
      await _pump(tester);
      final colors = _colors(tester, ClientLoginPage);
      final style =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;

      expect(style.backgroundColor!.resolve(const {}), colors.primary);
      expect(style.foregroundColor!.resolve(const {}), colors.onPrimary);
      expect(
        style.backgroundColor!.resolve(const {WidgetState.disabled}),
        colors.surfaceSubtle,
      );
    });

    testWidgets('the registration info box uses the soft brand surface',
        (tester) async {
      await _pump(tester, at: ClientRegisterPage.route);
      final colors = _colors(tester, ClientRegisterPage);

      final box = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.shield_outlined),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((box.decoration! as BoxDecoration).color, colors.softTeal);
    });

    test('no Client auth production file names a palette literal, and no '
        'login file carries a fake name', () {
      // A source audit: a widget test cannot observe a colour that was never
      // used, and these files' whole contract is that they use none. Comments
      // are stripped so prose about the rule does not read as a use.
      const files = [
        'lib/features/auth/presentation/pages/client_login_page.dart',
        'lib/features/auth/presentation/pages/client_register_page.dart',
        'lib/features/auth/presentation/pages/client_register_otp_page.dart',
        'lib/features/auth/presentation/pages/client_account_ready_page.dart',
        'lib/features/auth/presentation/widgets/client_auth_widgets.dart',
      ];
      const banned = [
        'Color(0x',
        'Colors.orange',
        'Colors.teal',
        'Colors.green',
        'Colors.white',
        'Colors.black',
        'Colors.grey',
        'kAuthAccent',
        'kAuthDark',
        'kAuthGray',
        'kAuthBorder',
        'kAuthBg',
        'Brightness.dark',
      ];
      // The workaround this split removed: a login call that carried a name,
      // with the phone number standing in for one.
      const bannedNameWorkarounds = [
        'verify(phone, phone',
        'fullName: phone',
        "fullName: ''",
        'clientOtpLogin(fullName',
        'fullName: _phoneCtrl',
      ];

      for (final path in files) {
        final source = File(path)
            .readAsLinesSync()
            .where((line) => !line.trimLeft().startsWith('//'))
            .join(' ');
        for (final token in banned) {
          expect(source, isNot(contains(token)),
              reason: '$path names $token');
        }
        for (final token in bannedNameWorkarounds) {
          expect(source, isNot(contains(token)),
              reason: '$path still carries the fake-name workaround: $token');
        }
      }
    });
  });

  group('dark theme needs no page-level logic', () {
    for (final entry in <String, ({String route, Object? extra, Type page})>{
      'login': (route: ClientLoginPage.route, extra: null, page: ClientLoginPage),
      'register': (
        route: ClientRegisterPage.route,
        extra: null,
        page: ClientRegisterPage
      ),
      'register OTP': (
        route: ClientRegisterOtpPage.route,
        extra: null,
        page: ClientRegisterOtpPage
      ),
      'account ready': (
        route: ClientAccountReadyPage.route,
        extra: null,
        page: ClientAccountReadyPage
      ),
    }.entries) {
      testWidgets('${entry.key} renders from the dark palette', (tester) async {
        if (entry.value.route == ClientRegisterOtpPage.route) {
          // This screen is only ever reached with a live code behind it.
          await _pumpRegisterOtpDark(tester);
          return;
        }
        await _pump(
          tester,
          at: entry.value.route,
          extra: entry.value.route == ClientRegisterOtpPage.route
              ? _draft()
              : entry.value.route == ClientAccountReadyPage.route
                  ? const ClientAccountSummary(
                      fullName: 'Ali Khan',
                      phone: _validPhone,
                    )
                  : null,
          theme: AppTheme.darkTheme,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(entry.value.page), findsOneWidget);
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          AppSemanticColors.dark.background,
        );
      });
    }
  });

  group('responsive and keyboard', () {
    const sizes = <String, Size>{
      'small 320x568': Size(320, 568),
      'common 360x640': Size(360, 640),
      'iPhone 14 390x844': Size(390, 844),
      'large 430x932': Size(430, 932),
      'tablet-ish 768x1024': Size(768, 1024),
    };

    sizes.forEach((name, size) {
      testWidgets('login lays out at $name without overflow', (tester) async {
        await _pump(tester, size: size);
        expect(tester.takeException(), isNull);
        expect(find.text(_ru.login), findsOneWidget);
      });

      testWidgets('registration lays out at $name without overflow',
          (tester) async {
        await _pump(tester, at: ClientRegisterPage.route, size: size);
        expect(tester.takeException(), isNull);
        expect(find.text(_ru.sendOtp), findsOneWidget);
      });
    });

    for (final scale in const [1.3, 1.6, 2.0]) {
      testWidgets('registration survives text scale ${scale}x on a small phone',
          (tester) async {
        await _pump(
          tester,
          at: ClientRegisterPage.route,
          size: const Size(320, 568),
          textScale: scale,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });
    }

    testWidgets('the form scrolls rather than overflowing when the keyboard '
        'takes half the screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            authStateProvider.overrideWith(() => _FakeAuthState(null)),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: _router(ClientRegisterPage.route),
            locale: AppLocale.romanUrdu.locale,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            localeResolutionCallback: (_, _) => AppLocale.romanUrdu.locale,
          ),
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
