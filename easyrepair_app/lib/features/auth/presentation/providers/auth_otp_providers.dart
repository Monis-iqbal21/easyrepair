import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/auth_tokens_entity.dart';

import '../../../../core/errors/failures.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../widgets/otp_input_section.dart' show expiresAtFromRetryAfter;
import 'auth_providers.dart';

/// Requests an OTP and holds the backend's authoritative expiry — the only
/// source of truth the OTP countdown UI should ever read from. Kept separate
/// from the verify notifiers below so "sending" and "verifying" always have
/// independent loading states, per page.
class OtpRequestNotifier extends AsyncNotifier<DateTime?> {
  @override
  Future<DateTime?> build() async => null;

  Future<bool> request(String phone, OtpPurpose purpose) async {
    // `.copyWithPrevious` carries the last known `expiresAt` through loading
    // and error states. Without it, a *resend* that fails (cooldown race,
    // rate limit, provider hiccup) would drop straight to a valueless
    // AsyncError, `expiresAt` would read null, and the OTP entry section
    // would vanish back to the phone form even though the original code is
    // still live — losing the user's in-progress verification over a
    // rejected resend, not a genuine failure of the original request.
    state = const AsyncLoading<DateTime?>().copyWithPrevious(state);
    final result = await ref
        .read(authRepositoryProvider)
        .requestOtp(phone: phone, purpose: purpose);
    return result.fold(
      (failure) {
        final retryAfter =
            failure is OtpResendTooSoonFailure ? failure.retryAfterSeconds : null;
        // `state.hasValue` is true even for the initial AsyncData(null) from
        // build(), so the check has to be against the actual expiresAt, not
        // just whether a value is present.
        if (retryAfter != null && state.valueOrNull == null) {
          // No expiresAt survived to copy forward (e.g. this page was just
          // remounted, which intentionally resets this provider — see the
          // OTP pages' initState) but the backend confirms a code requested
          // under a minute ago is still live. Reconstruct its expiry instead
          // of stranding the user on the phone form with no way to enter the
          // code they already received.
          state = AsyncData(expiresAtFromRetryAfter(retryAfter));
          return true;
        }
        state = AsyncError<DateTime?>(failure, StackTrace.current)
            .copyWithPrevious(state);
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

  /// Logs an EXISTING Client in with a one-time code.
  ///
  /// Takes no name: login is authentication, and the endpoint behind it no
  /// longer accepts registration data. An unknown or Worker-owned number
  /// fails here with [FailureCode.phoneNotRegistered] rather than quietly
  /// creating an account.
  Future<bool> verify(String phone, String otp) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).clientOtpLogin(
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

/// Ustaad registration Step 2 — spends the code for a registration token.
///
/// Holds the token only so the screen can react to success/failure; the token
/// itself is copied into the registration draft and lives nowhere else.
class UstaadOtpVerifyNotifier extends AsyncNotifier<WorkerRegistrationToken?> {
  @override
  Future<WorkerRegistrationToken?> build() async => null;

  Future<WorkerRegistrationToken?> verify(String phone, String otp) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .workerOtpVerify(phone: phone, otp: otp);
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return null;
      },
      (token) {
        state = AsyncData(token);
        return token;
      },
    );
  }

  /// Clears a previous verification so re-entering the flow never starts in an
  /// already-verified state.
  void reset() => state = const AsyncData(null);
}

final ustaadOtpVerifyNotifierProvider =
    AsyncNotifierProvider<UstaadOtpVerifyNotifier, WorkerRegistrationToken?>(
  UstaadOtpVerifyNotifier.new,
);

class WorkerOtpRegisterNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> register({
    required String fullName,
    required String phone,
    String? otp,
    required String password,
    required String categoryId,
    String? registrationToken,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).workerOtpRegister(
          fullName: fullName,
          phone: phone,
          otp: otp,
          password: password,
          categoryId: categoryId,
          registrationToken: registrationToken,
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
