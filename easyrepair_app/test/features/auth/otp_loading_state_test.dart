import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/network/api_client.dart';
import 'package:handygo_app/core/storage/secure_storage_service.dart';
import 'package:handygo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:handygo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_otp_providers.dart';

/// The OTP request must always settle.
///
/// The reported symptom was a screen that "keeps loading" with no code and no
/// error. Whatever the backend or the SMS provider does, the notifier has to
/// leave `AsyncLoading` — a spinner that never resolves gives the Ustaad
/// nothing to react to and no way to retry.

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._result);

  final Either<Failure, DateTime> Function() _result;
  int calls = 0;
  String? lastPhone;
  OtpPurpose? lastPurpose;

  @override
  Future<Either<Failure, DateTime>> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  }) async {
    calls++;
    lastPhone = phone;
    lastPurpose = purpose;
    return _result();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

ProviderContainer _containerFor(_FakeAuthRepository repo) {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('OtpRequestNotifier always settles', () {
    test('a success ends in AsyncData carrying the expiry', () async {
      final expiry = DateTime.utc(2026, 8, 3, 12, 5);
      final repo = _FakeAuthRepository(() => Right(expiry));
      final container = _containerFor(repo);

      final ok = await container
          .read(otpRequestNotifierProvider.notifier)
          .request('03378372427', OtpPurpose.workerLogin);

      expect(ok, isTrue);
      final state = container.read(otpRequestNotifierProvider);
      expect(state.isLoading, isFalse);
      expect(state.valueOrNull, expiry);
    });

    test('a provider failure (503) ends in AsyncError, not a spinner',
        () async {
      // SMS_SEND_FAILED — what the backend returns when VeevoTech rejects the
      // message, which is exactly the case that used to look like a hang.
      final repo = _FakeAuthRepository(
        () => const Left(ServerFailure('SMS bhejne mein masla hua.')),
      );
      final container = _containerFor(repo);

      final ok = await container
          .read(otpRequestNotifierProvider.notifier)
          .request('03378372427', OtpPurpose.workerLogin);

      expect(ok, isFalse);
      final state = container.read(otpRequestNotifierProvider);
      expect(state.isLoading, isFalse);
      expect(state.hasError, isTrue);
    });

    test('a network timeout ends in AsyncError, not a spinner', () async {
      final repo = _FakeAuthRepository(
        () => const Left(NetworkFailure('', code: FailureCode.timeout)),
      );
      final container = _containerFor(repo);

      final ok = await container
          .read(otpRequestNotifierProvider.notifier)
          .request('03378372427', OtpPurpose.workerLogin);

      expect(ok, isFalse);
      expect(container.read(otpRequestNotifierProvider).isLoading, isFalse);
      expect(container.read(otpRequestNotifierProvider).hasError, isTrue);
    });

    test('a rate-limit answer ends in AsyncError, not a spinner', () async {
      final repo = _FakeAuthRepository(
        () => const Left(ValidationFailure('Bohat zyada koshishein.')),
      );
      final container = _containerFor(repo);

      await container
          .read(otpRequestNotifierProvider.notifier)
          .request('03378372427', OtpPurpose.workerLogin);

      expect(container.read(otpRequestNotifierProvider).isLoading, isFalse);
      expect(container.read(otpRequestNotifierProvider).hasError, isTrue);
    });

    test('the request carries only phone and purpose — never a device id',
        () async {
      final repo = _FakeAuthRepository(() => Right(DateTime.utc(2026)));
      final container = _containerFor(repo);

      await container
          .read(otpRequestNotifierProvider.notifier)
          .request('03378372427', OtpPurpose.workerRegister);

      expect(repo.lastPhone, '03378372427');
      expect(repo.lastPurpose, OtpPurpose.workerRegister);
    });

    test('the same handset can retry after a failure', () async {
      var shouldFail = true;
      final repo = _FakeAuthRepository(
        () => shouldFail
            ? const Left(ServerFailure('SMS bhejne mein masla hua.'))
            : Right(DateTime.utc(2026)),
      );
      final container = _containerFor(repo);
      final notifier = container.read(otpRequestNotifierProvider.notifier);

      expect(await notifier.request('03378372427', OtpPurpose.workerLogin),
          isFalse);
      shouldFail = false;
      // No client-side lockout of its own — a retry is the backend's call.
      expect(
          await notifier.request('03378372427', OtpPurpose.workerLogin), isTrue);
      expect(repo.calls, 2);
      expect(container.read(otpRequestNotifierProvider).hasError, isFalse);
    });
  });

  group('the token-refresh client is bounded', () {
    test('the default /auth/refresh client has timeouts', () {
      // An unbounded refresh holds _isRefreshing true, and every later 401
      // then waits on a completer that never settles — the request neither
      // succeeds nor fails, so the screen spins with no error to show.
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      final interceptor = AuthInterceptor(_NoopSecureStorage(), dio);

      expect(interceptor.refreshDio.options.connectTimeout, isNotNull);
      expect(interceptor.refreshDio.options.receiveTimeout, isNotNull);
      expect(interceptor.refreshDio.options.sendTimeout, isNotNull);
    });
  });
}

class _NoopSecureStorage implements SecureStorageService {
  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> clearTokens() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
