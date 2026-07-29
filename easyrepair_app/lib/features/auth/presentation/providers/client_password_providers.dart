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

  Future<bool> register({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).clientPasswordRegister(
          fullName: fullName,
          phone: phone,
          password: password,
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
