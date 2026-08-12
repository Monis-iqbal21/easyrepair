import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/local_cache_service.dart';
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

/// The signed-in user, or null when definitely signed out.
///
/// Only a genuine authentication rejection ([UnauthorizedFailure] — the
/// authenticated Dio already tried a silent token refresh internally, and it
/// definitively failed, or there was never a token at all) resolves to null.
/// Any other failure from `/auth/me` — no internet, a timeout, a 5xx — is
/// transient: [AuthInterceptor] never clears stored tokens for those, so the
/// session is still intact and this must not claim otherwise. Rethrowing
/// those lets Riverpod's own "keep the previous value visible across a
/// failed rebuild" behaviour take over — `AsyncValue.hasValue`/`value` keep
/// pointing at the last confirmed user even while `hasError` is also true,
/// so app_router.dart's redirect (which checks `hasValue` before `hasError`)
/// never mistakes a network hiccup for a logout. Only a cold-start check
/// that fails before ever resolving once has no previous value to fall back
/// on — see app_router.dart for how that case is handled.
class AuthStateNotifier extends AsyncNotifier<UserEntity?> {
  @override
  Future<UserEntity?> build() async {
    final storage = ref.watch(secureStorageServiceProvider);
    final token = await storage.getAccessToken();
    if (token == null) return null;

    final result = await ref.watch(authRepositoryProvider).getCurrentUser();
    return result.fold((failure) {
      if (failure is UnauthorizedFailure) return null;
      throw failure;
    }, (user) => user);
  }
}

final authStateProvider =
    AsyncNotifierProvider<AuthStateNotifier, UserEntity?>(
  AuthStateNotifier.new,
);

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
    String? categoryId,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(registerUseCaseProvider).call(
          phone: phone,
          password: password,
          firstName: firstName,
          lastName: lastName,
          role: role,
          categoryId: categoryId,
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
    // Captured before the use case clears tokens below — getCurrentUserId()
    // reads it back out of the (still-present) access token.
    final userId =
        await ref.read(secureStorageServiceProvider).getCurrentUserId();
    final result = await ref.read(logoutUseCaseProvider).call();
    // Unconditional, regardless of outcome — same as the token clearing
    // AuthRepositoryImpl.logout() already does on every path (backend call
    // succeeds, fails, or throws). A refresh that was starting/in-flight
    // right as the user signed out must never resurrect stale bookkeeping
    // for whoever logs in next.
    ref.read(dioProvider).resetAuthRefreshState();
    // Also unconditional — belt-and-suspenders alongside per-user cache
    // namespacing (see LocalCacheService), so a different account signing in
    // next on this device never has this user's cached bookings/jobs/chat
    // left over to stumble onto.
    if (userId != null) {
      await ref.read(localCacheServiceProvider).clearUser(userId);
    }
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

// ── Delete account notifier ───────────────────────────────────────────────────

class DeleteAccountNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> deleteAccount() async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).deleteAccount();
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

final deleteAccountNotifierProvider =
    AsyncNotifierProvider<DeleteAccountNotifier, void>(
        DeleteAccountNotifier.new);

// ── Helper extension ──────────────────────────────────────────────────────────

extension FailureMessage on Failure {
  String get userMessage => message;
}
