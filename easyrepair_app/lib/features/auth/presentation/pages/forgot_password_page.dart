import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/otp_input_section.dart';
import '../../../../core/l10n/l10n_extensions.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Holds the backend's authoritative OTP expiry once requested — mirrors
/// `OtpRequestNotifier` (used by the Client/Worker OTP screens) but calls the
/// separate Worker-only `/auth/forgot-password/request` endpoint, which is
/// backed by `PasswordResetOtp`, not `AuthOtp`.
final _forgotPasswordRequestProvider =
    AsyncNotifierProvider.autoDispose<_RequestNotifier, DateTime?>(
  _RequestNotifier.new,
);

class _RequestNotifier extends AutoDisposeAsyncNotifier<DateTime?> {
  @override
  Future<DateTime?> build() async => null;

  Future<bool> request(String phone) async {
    state = const AsyncLoading();
    final result =
        await ref.read(authRepositoryProvider).forgotPasswordRequest(phone);
    return result.fold(
      (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
      (expiresAt) {
        state = AsyncData(expiresAt);
        return true;
      },
    );
  }
}

final _forgotPasswordResetProvider =
    AsyncNotifierProvider.autoDispose<_ResetNotifier, void>(
  _ResetNotifier.new,
);

class _ResetNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> reset({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).forgotPasswordReset(
          phone: phone,
          otp: otp,
          newPassword: newPassword,
        );
    return result.fold(
      (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────

/// Ustaad-only password recovery — Client accounts never reach this page
/// (linked only from the password section of `WorkerLoginPage`) and never
/// receive a reset OTP even if a Client phone number is entered here (the
/// backend silently no-ops for non-Worker phones).
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _phoneKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String _otp = '';
  bool _sendInFlight = false;
  bool _resetInFlight = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  /// Editing the number invalidates the OTP requested for the previous one,
  /// returning the screen to step 1. State-only — never re-requests a code.
  void _onPhoneChanged(String _) {
    if (ref.read(_forgotPasswordRequestProvider).valueOrNull != null) {
      ref.invalidate(_forgotPasswordRequestProvider);
      setState(() => _otp = '');
    }
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return context.l10n.authValidationPhoneRequired;
    if (!RegExp(r'^(\+92|0092|92|0)?[3][0-9]{9}$').hasMatch(value.trim())) {
      return context.l10n.authValidationPhoneInvalid;
    }
    return null;
  }

  Future<void> _sendCode() async {
    if (!_phoneKey.currentState!.validate() || _sendInFlight) return;
    setState(() => _sendInFlight = true);
    try {
      await ref
          .read(_forgotPasswordRequestProvider.notifier)
          .request(_phoneCtrl.text.trim());
    } finally {
      if (mounted) setState(() => _sendInFlight = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_resetKey.currentState!.validate() ||
        _otp.length != 6 ||
        _resetInFlight) {
      return;
    }
    setState(() => _resetInFlight = true);
    try {
      final ok = await ref.read(_forgotPasswordResetProvider.notifier).reset(
            phone: _phoneCtrl.text.trim(),
            otp: _otp,
            newPassword: _newPasswordCtrl.text,
          );
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.authPasswordResetSuccess),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/auth/worker/login');
        }
      }
    } finally {
      if (mounted) setState(() => _resetInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(_forgotPasswordRequestProvider, (_, s) {
      if (s is AsyncError && mounted) {
        final message = failureMessage(
          context.l10n,
          s.error,
          fallback: context.l10n.authErrorCodeSendFailed,
        );
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });
    ref.listen(_forgotPasswordResetProvider, (_, s) {
      if (s is AsyncError && mounted) {
        final message = failureMessage(
          context.l10n,
          s.error,
          fallback: context.l10n.authErrorPasswordChangeFailed,
        );
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    final expiresAt = ref.watch(_forgotPasswordRequestProvider).valueOrNull;
    final showOtp = expiresAt != null;
    final resetState = ref.watch(_forgotPasswordResetProvider);
    final hasOtpError = resetState is AsyncError;

    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets.bottom;
    final isSmall = mq.size.height < 680;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: viewInsets + 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: isSmall ? 16 : 28),
                          AuthHeader(
                            title: showOtp
                                ? context.l10n.authSetNewPasswordTitle
                                : context.l10n.authForgotPasswordTitle,
                            subtitle: showOtp
                                ? context.l10n.authEnterCodeSentToNumber
                                : context.l10n.authForgotPasswordWorkerOnly,
                            isSmall: isSmall,
                            showBackButton: true,
                          ),
                          SizedBox(height: isSmall ? 20 : 32),
                          // The phone field stays MOUNTED in both steps. It
                          // used to be removed from the tree once the code was
                          // sent, which left no way to correct a mistyped
                          // number without leaving the screen. Editing it
                          // clears the pending request (see _onPhoneChanged)
                          // and returns to step 1.
                          Form(
                            key: _phoneKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AuthTextField(
                                  controller: _phoneCtrl,
                                  label: context.l10n.authForgotPasswordPrompt,
                                  hint: '03XXXXXXXXX',
                                  keyboardType: TextInputType.phone,
                                  prefixIcon: Icons.phone_outlined,
                                  validator: _validatePhone,
                                  onChanged: _onPhoneChanged,
                                ),
                                if (!showOtp) ...[
                                  const SizedBox(height: 24),
                                  AuthPrimaryButton(
                                    label: context.l10n.authSendOtp,
                                    isLoading: _sendInFlight,
                                    onPressed: _sendCode,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (showOtp)
                            Form(
                              key: _resetKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 20),
                                  OtpInputSection(
                                    expiresAt: expiresAt,
                                    hasError: hasOtpError,
                                    resendInFlight: _sendInFlight,
                                    onChanged: (v) => setState(() => _otp = v),
                                    onCompleted: (v) =>
                                        setState(() => _otp = v),
                                    onResend: _sendCode,
                                  ),
                                  const SizedBox(height: 20),
                                  AuthTextField(
                                    controller: _newPasswordCtrl,
                                    label: context.l10n.generalNewPassword,
                                    prefixIcon: Icons.lock_outline_rounded,
                                    obscureText: true,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return context.l10n.authNewPasswordRequired;
                                      }
                                      if (v.length < 8) {
                                        return context.l10n.authValidationPasswordTooShort;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  AuthTextField(
                                    controller: _confirmCtrl,
                                    label: context.l10n.generalConfirmNewPassword,
                                    prefixIcon: Icons.lock_outline_rounded,
                                    obscureText: true,
                                    textInputAction: TextInputAction.done,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return context.l10n.authValidationConfirmPasswordRequired;
                                      }
                                      if (v != _newPasswordCtrl.text) {
                                        return context.l10n.authValidationPasswordsDoNotMatch;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  AuthPrimaryButton(
                                    label: context.l10n.authConfirmNewPasswordButton,
                                    isLoading: _resetInFlight,
                                    onPressed: _otp.length == 6
                                        ? _resetPassword
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
