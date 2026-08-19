import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_providers.dart';

/// Classifies a phone number before any password is entered, driving which
/// sub-form the Client auth page's password mode shows.
class ClientPhoneCheckNotifier extends AsyncNotifier<ClientPhoneStatus?> {
  @override
  Future<ClientPhoneStatus?> build() async => null;

  Future<bool> check(String phone) async {
    state = const AsyncLoading();
    final result =
        await ref.read(authRepositoryProvider).checkClientPhoneStatus(phone);
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (status) {
        state = AsyncData(status);
        return true;
      },
    );
  }

  /// Clears the classification (e.g. the user edits the phone number after
  /// a check, so a stale mode never lingers for the new value).
  void reset() {
    state = const AsyncData(null);
  }
}

final clientPhoneCheckNotifierProvider =
    AsyncNotifierProvider<ClientPhoneCheckNotifier, ClientPhoneStatus?>(
  ClientPhoneCheckNotifier.new,
);

class ClientPasswordLoginNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> login(String phone, String password) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .clientPasswordLogin(phone: phone, password: password);
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

final clientPasswordLoginNotifierProvider =
    AsyncNotifierProvider<ClientPasswordLoginNotifier, void>(
  ClientPasswordLoginNotifier.new,
);

class ClientPasswordRegisterNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Creates the account and starts its session — one call, one step.
  ///
  /// [otp] is verified by the backend BEFORE anything is created, so there is
  /// no longer any window in which an unverified account holds tokens. This
  /// replaces the previous two-call sequence (create, then verify by logging
  /// in again), which existed only because the register endpoint could not
  /// accept a code.
  Future<bool> register({
    required String fullName,
    required String phone,
    required String password,
    required String otp,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).clientPasswordRegister(
          fullName: fullName,
          phone: phone,
          password: password,
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

final clientPasswordRegisterNotifierProvider =
    AsyncNotifierProvider<ClientPasswordRegisterNotifier, void>(
  ClientPasswordRegisterNotifier.new,
);
