import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/errors/failure_messages.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/storage/secure_storage_service.dart';
import 'package:handygo_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:handygo_app/features/auth/data/models/auth_response_model.dart';
import 'package:handygo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:handygo_app/features/auth/domain/entities/auth_tokens_entity.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:handygo_app/features/auth/presentation/pages/client_register_otp_page.dart';
import 'package:handygo_app/features/auth/presentation/pages/client_register_page.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_otp_providers.dart';
import 'package:handygo_app/features/auth/presentation/widgets/client_auth_widgets.dart';
import 'package:handygo_app/l10n/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

/// Client registration OTP — "Verify & Create Account".
///
/// The backend half of the reported failure is in
/// `backend/src/modules/auth/auth.client-otp-register.spec.ts`. This file
/// answers what only the app can answer: what is sent, whether a second tap
/// can produce a second account-creating request, whether the field resets on
/// resend, whether a success always leaves the page with tokens stored, and —
/// the reason every failure reads as "OTP wrong" — what the six boxes do.
///
/// Nothing here modifies production code; these are observations of the
/// shipped page.

const _phone = '03273359444';

class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({this.failure, this.loginSucceeds = true});

  /// When set, `clientPasswordRegister` returns this instead of succeeding.
  Failure? failure;

  /// Whether the recovery login finds a real account behind these
  /// credentials.
  bool loginSucceeds;

  final List<({String phone, String password})> logins = [];

  /// Holds the register call open, so a second tap or a resend can be
  /// attempted while the first is still in flight.
  Completer<void>? gate;

  final List<({String phone, String purpose})> requests = [];
  final List<({String phone, String otp, String fullName, String password})>
      registers = [];

  @override
  Future<Either<Failure, DateTime>> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  }) async {
    requests.add((phone: phone, purpose: purpose.apiValue));
    return Right(DateTime.now().add(const Duration(minutes: 5)));
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> clientPasswordRegister({
    required String fullName,
    required String phone,
    required String password,
    required String otp,
  }) async {
    registers.add((
      phone: phone,
      otp: otp,
      fullName: fullName,
      password: password,
    ));
    if (gate != null) await gate!.future;
    if (failure != null) return Left(failure!);
    return const Right(
      AuthTokensEntity(
        accessToken: 'access',
        refreshToken: 'refresh',
        user: UserEntity(
          id: 'u1',
          phone: '+923273359444',
          role: 'CLIENT',
          firstName: 'Ayesha',
          lastName: 'Malik',
        ),
      ),
    );
  }

  @override
  Future<Either<Failure, AuthTokensEntity>> clientPasswordLogin({
    required String phone,
    required String password,
  }) async {
    logins.add((phone: phone, password: password));
    if (!loginSucceeds) {
      return const Left(PhoneNotRegisteredFailure(''));
    }
    return const Right(
      AuthTokensEntity(
        accessToken: 'recovered-access',
        refreshToken: 'recovered-refresh',
        user: UserEntity(
          id: 'u1',
          phone: '+923273359444',
          role: 'CLIENT',
          firstName: 'Ayesha',
          lastName: 'Malik',
        ),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

late ProviderContainer _container;

Widget _app(_RecordingAuthRepository repo) {
  final router = GoRouter(
    initialLocation: ClientRegisterOtpPage.route,
    routes: [
      GoRoute(
        path: ClientRegisterOtpPage.route,
        builder: (_, _) => const ClientRegisterOtpPage(
          draft: ClientRegistrationDraft(
            fullName: 'Ayesha Malik',
            phone: _phone,
            password: 'password123',
          ),
        ),
      ),
      GoRoute(
        path: '/client/account-ready',
        builder: (_, _) => const Scaffold(body: Text('ACCOUNT_READY')),
      ),
    ],
  );

  _container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(_container.dispose);

  return UncontrolledProviderScope(
    container: _container,
    child: localizedRouterApp(router, locale: AppLocale.romanUrdu),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Drives the send the registration form performs, so the OTP page opens with
/// the live expiry it needs (`_codeLive` gates verification on it).
Future<void> _sendFirstCode() async {
  await _container
      .read(otpRequestNotifierProvider.notifier)
      .request(_phone, OtpPurpose.clientLoginRegister);
}

/// Rewinds the stored expiry so the derived 60s resend cooldown has elapsed.
void _elapseResendCooldown() {
  final expiry = _container.read(otpRequestNotifierProvider).valueOrNull!;
  _container.read(otpRequestNotifierProvider.notifier).state =
      AsyncData(expiry.subtract(const Duration(seconds: 61)));
}

Finder get _otpField => find.byType(EditableText).first;

Future<void> _typeOtp(WidgetTester tester, String code) async {
  await tester.enterText(_otpField, code);
  await _settle(tester);
}

void _sizeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<_RecordingAuthRepository> _open(
  WidgetTester tester, {
  Failure? failure,
  Completer<void>? gate,
  bool loginSucceeds = true,
}) async {
  _sizeView(tester);
  final repo = _RecordingAuthRepository(
    failure: failure,
    loginSucceeds: loginSucceeds,
  )..gate = gate;
  final widget = _app(repo);
  await _sendFirstCode();
  repo.requests.clear();
  await tester.pumpWidget(widget);
  await _settle(tester);
  return repo;
}

void main() {
  group('the payload', () {
    testWidgets('one call carries name, phone, password AND the code', (
      tester,
    ) async {
      final repo = await _open(tester);

      await _typeOtp(tester, '123456');
      await _settle(tester);

      expect(repo.registers, hasLength(1));
      final sent = repo.registers.single;
      expect(sent.phone, _phone, reason: 'the raw string the form collected');
      expect(sent.otp, '123456');
      expect(sent.fullName, 'Ayesha Malik');
      expect(
        sent.password,
        'password123',
        reason: 'the password is carried across the OTP screen in route extra '
            'and only leaves the device on this one call',
      );
      expect(
        repo.requests,
        isEmpty,
        reason: 'verification never asks for another code',
      );
    });

    testWidgets('resend re-sends the same phone under CLIENT_LOGIN_REGISTER', (
      tester,
    ) async {
      final repo = await _open(tester);

      _elapseResendCooldown();
      // The page repaints on its own 1s ticker, not on the provider.
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Dobara bhejein'));
      await _settle(tester);

      expect(repo.requests, hasLength(1));
      expect(repo.requests.single.phone, _phone);
      expect(
        repo.requests.single.purpose,
        'CLIENT_LOGIN_REGISTER',
        reason: 'must match the purpose clientPasswordRegister verifies under',
      );
    });
  });

  group('8 — double tap', () {
    testWidgets('a second tap while the first call is open creates nothing '
        'extra', (tester) async {
      final gate = Completer<void>();
      final repo = await _open(tester, gate: gate);

      await _typeOtp(tester, '123456');
      expect(repo.registers, hasLength(1));

      // While the call is open the CTA shows a spinner and reports itself
      // disabled — the first half of the guard.
      expect(find.text('Verify kar ke account banayein'), findsNothing);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton).first)
            .onPressed,
        isNull,
      );

      await tester.tap(find.byType(ElevatedButton).first, warnIfMissed: false);
      await _settle(tester);

      expect(
        repo.registers,
        hasLength(1),
        reason: '_verifyInFlight guards the CTA and the auto-submit together, '
            'so no second account-creating request can leave the device',
      );

      gate.complete();
      await _settle(tester);
    });
  });

  group('9 — navigation on success', () {
    testWidgets('leaves the OTP page for the account-ready screen', (
      tester,
    ) async {
      final repo = await _open(tester);

      await _typeOtp(tester, '123456');
      await tester.pumpAndSettle();

      expect(repo.registers, hasLength(1));
      expect(find.text('ACCOUNT_READY'), findsOneWidget);
      expect(find.byType(ClientRegisterOtpPage), findsNothing);
    });

    testWidgets('a failure stays on the page and creates nothing', (
      tester,
    ) async {
      final repo = await _open(
        tester,
        failure: const ValidationFailure('OTP ghalat hai.'),
      );

      await _typeOtp(tester, '123456');
      await _settle(tester);

      expect(repo.registers, hasLength(1));
      expect(find.text('ACCOUNT_READY'), findsNothing);
      expect(find.byType(ClientRegisterOtpPage), findsOneWidget);
    });
  });

  group('resend resets the OTP state', () {
    testWidgets('the typed digits are dropped and nothing auto-submits', (
      tester,
    ) async {
      final repo = await _open(
        tester,
        failure: const ValidationFailure('OTP ghalat hai.'),
      );

      await _typeOtp(tester, '111111');
      await _settle(tester);
      expect(repo.registers, hasLength(1));

      _elapseResendCooldown();
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Dobara bhejein'));
      await _settle(tester);

      expect(
        tester.widget<EditableText>(_otpField).controller.text,
        isEmpty,
        reason: 'the field is keyed on the expiry, so a new code rebuilds it',
      );
      expect(repo.registers, hasLength(1));
    });
  });

  group('lost-success recovery', () {
    testWidgets('a receive timeout triggers exactly ONE recovery login with '
        'the credentials already entered', (tester) async {
      final repo = await _open(
        tester,
        failure: const NetworkFailure('', code: FailureCode.timeout),
      );

      await _typeOtp(tester, '123456');
      await tester.pumpAndSettle();

      expect(repo.registers, hasLength(1));
      expect(
        repo.logins,
        hasLength(1),
        reason: 'the backend may already have created this account and spent '
            'the code, so registering again can never work — the session is '
            'recovered instead',
      );
      expect(repo.logins.single.phone, _phone);
      expect(repo.logins.single.password, 'password123');
    });

    testWidgets('a successful recovery reaches the account-ready screen', (
      tester,
    ) async {
      final repo = await _open(
        tester,
        failure: const NetworkFailure('', code: FailureCode.timeout),
      );

      await _typeOtp(tester, '123456');
      await tester.pumpAndSettle();

      expect(repo.logins, hasLength(1));
      expect(find.text('ACCOUNT_READY'), findsOneWidget);
      expect(find.byType(ClientRegisterOtpPage), findsNothing);
    });

    testWidgets('PHONE_ALREADY_REGISTERED also triggers exactly ONE recovery '
        'login — that is what a lost success looks like next time round', (
      tester,
    ) async {
      final repo = await _open(
        tester,
        failure: const PhoneAlreadyRegisteredFailure(''),
      );

      await _typeOtp(tester, '123456');
      await tester.pumpAndSettle();

      expect(repo.registers, hasLength(1));
      expect(repo.logins, hasLength(1));
      expect(find.text('ACCOUNT_READY'), findsOneWidget);
    });

    testWidgets('a FAILED recovery does not loop and leaves the original '
        'registration error on screen', (tester) async {
      final repo = await _open(
        tester,
        failure: const PhoneAlreadyRegisteredFailure(''),
        loginSucceeds: false,
      );

      await _typeOtp(tester, '123456');
      await _settle(tester);

      expect(repo.registers, hasLength(1), reason: 'no second registration');
      expect(repo.logins, hasLength(1), reason: 'exactly one attempt, no loop');
      expect(find.byType(ClientRegisterOtpPage), findsOneWidget);
      expect(find.text('ACCOUNT_READY'), findsNothing);
      expect(
        find.text('Ye number pehle se registered hai.'),
        findsOneWidget,
        reason: 'the ORIGINAL registration error, not the login failure — a '
            '"phone not registered" message here would be nonsense',
      );
    });

    testWidgets('a rejected CODE never attempts recovery', (tester) async {
      final repo = await _open(
        tester,
        failure: const OtpRejectedFailure('OTP ghalat hai.'),
      );

      await _typeOtp(tester, '123456');
      await _settle(tester);

      expect(
        repo.logins,
        isEmpty,
        reason: 'the code was wrong — there is no account to recover',
      );
      expect(find.byType(ClientRegisterOtpPage), findsOneWidget);
    });

    testWidgets('a plain server error attempts no recovery either', (
      tester,
    ) async {
      final repo = await _open(tester, failure: const ServerFailure(''));

      await _typeOtp(tester, '123456');
      await _settle(tester);

      expect(repo.logins, isEmpty);
      expect(find.byType(ClientRegisterOtpPage), findsOneWidget);
    });
  });

  group('the OTP boxes mark the CODE, and only the code', () {
    Future<bool> otpFieldIsRed(WidgetTester tester, Failure failure) async {
      await _open(tester, failure: failure, loginSucceeds: false);
      await _typeOtp(tester, '123456');
      await _settle(tester);
      return tester
          .widget<ClientOtpField>(find.byType(ClientOtpField))
          .hasError;
    }

    testWidgets('OTP_INVALID turns them red', (tester) async {
      expect(
        await otpFieldIsRed(tester, const OtpRejectedFailure('OTP ghalat hai.')),
        isTrue,
      );
    });

    testWidgets('OTP_EXPIRED turns them red', (tester) async {
      expect(
        await otpFieldIsRed(
          tester,
          const OtpRejectedFailure(
            'Code expire ho gaya hai. Naya code mangwayein.',
          ),
        ),
        isTrue,
      );
    });

    testWidgets('OTP_ATTEMPTS_EXCEEDED turns them red', (tester) async {
      expect(
        await otpFieldIsRed(
          tester,
          const OtpRejectedFailure(
            'Bohat zyada ghalat koshishein. Naya code mangwayein.',
          ),
        ),
        isTrue,
      );
    });

    testWidgets('PHONE_ALREADY_REGISTERED does NOT', (tester) async {
      expect(
        await otpFieldIsRed(tester, const PhoneAlreadyRegisteredFailure('')),
        isFalse,
        reason: 'nothing is wrong with the digits the Client typed, and '
            'painting them red is what made every failure read as '
            '"OTP wrong"',
      );
    });

    testWidgets('a timeout does NOT', (tester) async {
      expect(
        await otpFieldIsRed(
          tester,
          const NetworkFailure('', code: FailureCode.timeout),
        ),
        isFalse,
      );
    });

    testWidgets('a network failure does NOT', (tester) async {
      expect(
        await otpFieldIsRed(
          tester,
          const NetworkFailure('', code: FailureCode.noInternet),
        ),
        isFalse,
      );
    });

    testWidgets('a server failure does NOT', (tester) async {
      expect(await otpFieldIsRed(tester, const ServerFailure('')), isFalse);
    });
  });

  group('15 — the exact sentence each backend rejection produces', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(
        AppLocale.romanUrdu.locale,
      );
    });

    // The 400s carry a Roman-Urdu sentence the backend wrote; the mapper
    // passes a human message through verbatim.
    test('OTP_INVALID', () {
      expect(
        failureMessage(l10n, const ValidationFailure('OTP ghalat hai.')),
        'OTP ghalat hai.',
      );
    });

    test('OTP_EXPIRED', () {
      expect(
        failureMessage(
          l10n,
          const ValidationFailure('Code expire ho gaya hai. Naya code mangwayein.'),
        ),
        'Code expire ho gaya hai. Naya code mangwayein.',
      );
    });

    test('OTP_ATTEMPTS_EXCEEDED', () {
      expect(
        failureMessage(
          l10n,
          const ValidationFailure(
            'Bohat zyada ghalat koshishein. Naya code mangwayein.',
          ),
        ),
        'Bohat zyada ghalat koshishein. Naya code mangwayein.',
      );
    });

    // The 409 carries an EMPTY message by design, so the app supplies the
    // wording — and it is the only one that does not mention the code at all.
    test('PHONE_ALREADY_REGISTERED', () {
      expect(
        failureMessage(l10n, const PhoneAlreadyRegisteredFailure('')),
        'Ye number pehle se registered hai.',
      );
    });

    test('timeout — the case where the account may already exist', () {
      expect(
        failureMessage(
          l10n,
          const NetworkFailure('', code: FailureCode.timeout),
        ),
        'Connection ka waqt khatam ho gaya. Dobara koshish karein.',
      );
    });
  });

  group('12 — a lost response leaves no tokens, even though the account was '
      'created', () {
    test('the repository only stores tokens on a response it actually saw', () async {
      final storage = _FakeStorage();
      final datasource = _ThrowingDatasource();
      final repo = AuthRepositoryImpl(datasource, storage);

      final result = await repo.clientPasswordRegister(
        fullName: 'Ayesha Malik',
        phone: _phone,
        password: 'password123',
        otp: '123456',
      );

      expect(result.isLeft(), isTrue);
      expect(
        storage.saved,
        isEmpty,
        reason: 'the backend has already created the account and consumed the '
            'code by this point — the app simply never learns it',
      );
    });

    test('the RECOVERY login stores its tokens through the same repository, '
        'so a recovered session is a real one', () async {
      final storage = _FakeStorage();
      final repo = AuthRepositoryImpl(_RecoveringDatasource(), storage);

      final result = await repo.clientPasswordLogin(
        phone: _phone,
        password: 'password123',
      );

      expect(result.isRight(), isTrue);
      expect(storage.saved, ['recovered-access|recovered-refresh']);
    });

    test('a response it does see is stored before success is reported', () async {
      final storage = _FakeStorage();
      final datasource = _SucceedingDatasource();
      final repo = AuthRepositoryImpl(datasource, storage);

      final result = await repo.clientPasswordRegister(
        fullName: 'Ayesha Malik',
        phone: _phone,
        password: 'password123',
        otp: '123456',
      );

      expect(result.isRight(), isTrue);
      expect(storage.saved, ['access|refresh']);
    });
  });
}

// ── Fakes for the repository-level tests ────────────────────────────────────

class _FakeStorage implements SecureStorageService {
  final List<String> saved = [];

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    saved.add('$accessToken|$refreshToken');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The 201 that never arrives — a receive timeout on a request the backend
/// has already committed.
class _ThrowingDatasource implements AuthRemoteDatasource {
  @override
  Future<AuthResponseModel> clientPasswordRegister({
    required String fullName,
    required String phone,
    required String password,
    required String otp,
  }) async {
    throw DioException(
      requestOptions: RequestOptions(path: '/auth/client/password-register'),
      type: DioExceptionType.receiveTimeout,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The existing Client password-login endpoint, as the recovery path uses it.
class _RecoveringDatasource implements AuthRemoteDatasource {
  @override
  Future<AuthResponseModel> clientPasswordLogin({
    required String phone,
    required String password,
  }) async {
    return AuthResponseModel.fromJson(const {
      'data': {
        'accessToken': 'recovered-access',
        'refreshToken': 'recovered-refresh',
        'user': {
          'id': 'u1',
          'phone': '+923273359444',
          'role': 'CLIENT',
          'firstName': 'Ayesha',
          'lastName': 'Malik',
        },
      },
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _SucceedingDatasource implements AuthRemoteDatasource {
  @override
  Future<AuthResponseModel> clientPasswordRegister({
    required String fullName,
    required String phone,
    required String password,
    required String otp,
  }) async {
    return AuthResponseModel.fromJson(const {
      'data': {
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'user': {
          'id': 'u1',
          'phone': '+923273359444',
          'role': 'CLIENT',
          'firstName': 'Ayesha',
          'lastName': 'Malik',
        },
      },
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
