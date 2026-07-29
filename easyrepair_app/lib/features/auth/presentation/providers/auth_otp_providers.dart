import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_providers.dart';

/// Requests an OTP and holds the backend's authoritative expiry — the only
/// source of truth the OTP countdown UI should ever read from. Kept separate
/// from the verify notifiers below so "sending" and "verifying" always have
/// independent loading states, per page.
class OtpRequestNotifier extends AsyncNotifier<DateTime?> {
  @override
  Future<DateTime?> build() async => null;

  Future<bool> request(String phone, OtpPurpose purpose) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .requestOtp(phone: phone, purpose: purpose);
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (expiresAt) {
        state = AsyncData(expiresAt);
        return true;
      },
    );
  }

  /// Clears any previous expiry (e.g. when the user edits the phone number
  /// after a request, so a stale countdown never lingers for the new field).
  void reset() {
    state = const AsyncData(null);
  }
}

final otpRequestNotifierProvider =
    AsyncNotifierProvider<OtpRequestNotifier, DateTime?>(
  OtpRequestNotifier.new,
);

class ClientOtpAuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> verify(String fullName, String phone, String otp) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).clientOtpLogin(
          fullName: fullName,
          phone: phone,
          otp: otp,
        );
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        ref.invalidate(authStateProvider);
        state = const AsyncData(null);
        return true;
      },
    );
  }
}

final clientOtpAuthNotifierProvider =
    AsyncNotifierProvider<ClientOtpAuthNotifier, void>(
  ClientOtpAuthNotifier.new,
);

class WorkerOtpRegisterNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> register({
    required String fullName,
    required String phone,
    required String otp,
    required String password,
    required String categoryId,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).workerOtpRegister(
          fullName: fullName,
          phone: phone,
          otp: otp,
          password: password,
          categoryId: categoryId,
        );
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        ref.invalidate(authStateProvider);
        state = const AsyncData(null);
        return true;
      },
    );
  }
}

final workerOtpRegisterNotifierProvider =
    AsyncNotifierProvider<WorkerOtpRegisterNotifier, void>(
  WorkerOtpRegisterNotifier.new,
);

class WorkerOtpLoginNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> login(String phone, String otp) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .workerOtpLogin(phone: phone, otp: otp);
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        ref.invalidate(authStateProvider);
        state = const AsyncData(null);
        return true;
      },
    );
  }
}

final workerOtpLoginNotifierProvider =
    AsyncNotifierProvider<WorkerOtpLoginNotifier, void>(
  WorkerOtpLoginNotifier.new,
);
