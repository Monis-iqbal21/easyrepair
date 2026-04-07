import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/storage/secure_storage_service.dart';

// ── Use case providers ────────────────────────────────────────────────────────

final loginUseCaseProvider = Provider<LoginUseCase>(
  (ref) => LoginUseCase(ref.watch(authRepositoryProvider)),
);

final registerUseCaseProvider = Provider<RegisterUseCase>(
  (ref) => RegisterUseCase(ref.watch(authRepositoryProvider)),
);

final logoutUseCaseProvider = Provider<LogoutUseCase>(
  (ref) => LogoutUseCase(ref.watch(authRepositoryProvider)),
);

// ── Auth state (drives GoRouter redirect) ────────────────────────────────────

final authStateProvider = FutureProvider<UserEntity?>((ref) async {
  final storage = ref.watch(secureStorageServiceProvider);
  final token = await storage.getAccessToken();
  if (token == null) return null;

  final result = await ref.watch(authRepositoryProvider).getCurrentUser();
  return result.fold((_) => null, (user) => user);
});

// ── Login notifier ────────────────────────────────────────────────────────────

class LoginNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> login(String phone, String password) async {
    debugPrint('[LoginNotifier] login started');
    state = const AsyncLoading();
    final result = await ref.read(loginUseCaseProvider).call(
          phone: phone,
          password: password,
        );
    result.fold(
      (failure) {
        debugPrint('[LoginNotifier] login failed: ${failure.message}');
        state = AsyncError(failure, StackTrace.current);
      },
      (_) {
        debugPrint('[LoginNotifier] login succeeded, invalidating authState');
        ref.invalidate(authStateProvider);
        state = const AsyncData(null);
      },
    );
  }
}

final loginNotifierProvider =
    AsyncNotifierProvider<LoginNotifier, void>(LoginNotifier.new);

// ── Register notifier ─────────────────────────────────────────────────────────

class RegisterNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> register({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(registerUseCaseProvider).call(
          phone: phone,
          password: password,
          firstName: firstName,
          lastName: lastName,
          role: role,
        );
    result.fold(
      (failure) => state = AsyncError(failure, StackTrace.current),
      (_) {
        ref.invalidate(authStateProvider);
        state = const AsyncData(null);
      },
    );
  }
}

final registerNotifierProvider =
    AsyncNotifierProvider<RegisterNotifier, void>(RegisterNotifier.new);

// ── Logout notifier ───────────────────────────────────────────────────────────

class LogoutNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> logout() async {
    state = const AsyncLoading();
    final result = await ref.read(logoutUseCaseProvider).call();
    result.fold(
      (failure) => state = AsyncError(failure, StackTrace.current),
      (_) {
        ref.invalidate(authStateProvider);
        state = const AsyncData(null);
      },
    );
  }
}

final logoutNotifierProvider =
    AsyncNotifierProvider<LogoutNotifier, void>(LogoutNotifier.new);

// ── Helper extension ──────────────────────────────────────────────────────────

extension FailureMessage on Failure {
  String get userMessage => message;
}
