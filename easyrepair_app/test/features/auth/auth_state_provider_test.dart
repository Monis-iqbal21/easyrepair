import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/storage/secure_storage_service.dart';
import 'package:handygo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:handygo_app/features/auth/domain/entities/auth_tokens_entity.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';

/// Covers AuthStateNotifier's core contract: a genuine authentication
/// rejection is the only thing that resolves to "logged out". Every other
/// failure from /auth/me (no internet, a timeout, a 5xx) is transient —
/// AuthInterceptor never clears stored tokens for those — so it must leave a
/// previously-confirmed session alone rather than logging the user out.

class _FakeSecureStorage extends SecureStorageService {
  _FakeSecureStorage({this.accessToken}) : super(const FlutterSecureStorage());
  final String? accessToken;

  @override
  Future<String?> getAccessToken() async => accessToken;
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._getCurrentUser);
  final Future<Either<Failure, UserEntity>> Function() _getCurrentUser;

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() => _getCurrentUser();

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

const _user = UserEntity(
  id: 'u1',
  phone: '+923001234567',
  role: 'CLIENT',
  firstName: 'Ali',
  lastName: 'Khan',
);

ProviderContainer _containerFor({
  String? accessToken = 'a-token',
  required Future<Either<Failure, UserEntity>> Function() getCurrentUser,
}) {
  final container = ProviderContainer(
    overrides: [
      secureStorageServiceProvider.overrideWithValue(
        _FakeSecureStorage(accessToken: accessToken),
      ),
      authRepositoryProvider.overrideWithValue(
        _FakeAuthRepository(getCurrentUser),
      ),
    ],
  );
  return container;
}

void main() {
  group('AuthStateNotifier', () {
    test('no access token in storage resolves to null (logged out)', () async {
      final container = _containerFor(
        accessToken: null,
        getCurrentUser: () async => fail('must not call /auth/me without a token'),
      );
      addTearDown(container.dispose);

      final result = await container.read(authStateProvider.future);

      expect(result, isNull);
    });

    test('a genuine UnauthorizedFailure resolves to null (logged out)', () async {
      final container = _containerFor(
        getCurrentUser: () async => const Left(UnauthorizedFailure('')),
      );
      addTearDown(container.dispose);

      final result = await container.read(authStateProvider.future);

      expect(result, isNull);
    });

    test('a confirmed user resolves normally', () async {
      final container = _containerFor(
        getCurrentUser: () async => const Right(_user),
      );
      addTearDown(container.dispose);

      final result = await container.read(authStateProvider.future);

      expect(result, _user);
    });

    test(
      'a network failure after a previously-confirmed user keeps that user '
      'visible (hasValue stays true) instead of logging out',
      () async {
        var callCount = 0;
        final container = _containerFor(
          getCurrentUser: () async {
            callCount++;
            if (callCount == 1) return const Right(_user);
            return const Left(NetworkFailure('', code: FailureCode.noInternet));
          },
        );
        addTearDown(container.dispose);

        // First resolution: confirms the user.
        await container.read(authStateProvider.future);
        expect(container.read(authStateProvider).valueOrNull, _user);

        // Something re-triggers the check (e.g. app resume) and this time
        // the network is down. Riverpod is lazy — invalidating alone
        // doesn't rebuild; reading `.future` again both triggers and
        // awaits the rebuild through to its (thrown) conclusion.
        container.invalidate(authStateProvider);
        await expectLater(
          container.read(authStateProvider.future),
          throwsA(isA<NetworkFailure>()),
        );

        final after = container.read(authStateProvider);
        expect(after.hasError, isTrue);
        // The previously-confirmed user must still be visible — this is
        // exactly what stops the router from treating a network blip as a
        // logout.
        expect(after.hasValue, isTrue);
        expect(after.valueOrNull, _user);
      },
    );

    test(
      'a 5xx failure after a previously-confirmed user keeps that user '
      'visible instead of logging out',
      () async {
        var callCount = 0;
        final container = _containerFor(
          getCurrentUser: () async {
            callCount++;
            if (callCount == 1) return const Right(_user);
            return const Left(ServerFailure(''));
          },
        );
        addTearDown(container.dispose);

        await container.read(authStateProvider.future);
        container.invalidate(authStateProvider);
        await expectLater(
          container.read(authStateProvider.future),
          throwsA(isA<ServerFailure>()),
        );

        final after = container.read(authStateProvider);
        expect(after.hasError, isTrue);
        expect(after.hasValue, isTrue);
        expect(after.valueOrNull, _user);
      },
    );

    test(
      'a transient failure on the very first check (nothing previously '
      'confirmed) surfaces as an error with no fabricated user — the router '
      'treats this like "still resolving", never like a confirmed logout',
      () async {
        final container = _containerFor(
          getCurrentUser: () async =>
              const Left(NetworkFailure('', code: FailureCode.timeout)),
        );
        addTearDown(container.dispose);

        await expectLater(
          container.read(authStateProvider.future),
          throwsA(isA<NetworkFailure>()),
        );

        final state = container.read(authStateProvider);
        expect(state.hasError, isTrue);
        expect(state.hasValue, isFalse);
        expect(state.valueOrNull, isNull);
      },
    );
  });
}
