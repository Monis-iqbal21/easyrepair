import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/otp_input_section.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Mirrors the Worker `ForgotPasswordPage`'s local notifiers exactly, but
/// calls the separate Client-only `/auth/client/forgot-password/*`
/// endpoints (still backed by the same `PasswordResetOtp` model — a phone
/// can only ever belong to one role, so sharing it has no cross-role risk).
final _clientForgotPasswordRequestProvider =
    AsyncNotifierProvider.autoDispose<_RequestNotifier, DateTime?>(
  _RequestNotifier.new,
);

class _RequestNotifier extends AutoDisposeAsyncNotifier<DateTime?> {
  @override
  Future<DateTime?> build() async => null;

  Future<bool> request(String phone) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .clientForgotPasswordRequest(phone);
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

final _clientForgotPasswordResetProvider =
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
    final result =
        await ref.read(authRepositoryProvider).clientForgotPasswordReset(
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

/// Client-only password recovery — kept as a separate page/class from the
/// Worker `ForgotPasswordPage` so the two flows stay visually and logically
/// separate, even though they share the same building blocks
/// (`AuthHeader`/`AuthPrimaryButton`/`AuthTextField`/`OtpInputSection`).
class ClientForgotPasswordPage extends ConsumerStatefulWidget {
  const ClientForgotPasswordPage({super.key});

  @override
  ConsumerState<ClientForgotPasswordPage> createState() =>
      _ClientForgotPasswordPageState();
}

class _ClientForgotPasswordPageState
    extends ConsumerState<ClientForgotPasswordPage> {
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

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Mobile number likhein.';
    if (!RegExp(r'^(\+92|0092|92|0)?[3][0-9]{9}$').hasMatch(value.trim())) {
      return 'Sahi Pakistani mobile number likhein.';
    }
    return null;
  }

  Future<void> _sendCode() async {
    if (!_phoneKey.currentState!.validate() || _sendInFlight) return;
    setState(() => _sendInFlight = true);
    try {
      await ref
          .read(_clientForgotPasswordRequestProvider.notifier)
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
      final ok =
          await ref.read(_clientForgotPasswordResetProvider.notifier).reset(
                phone: _phoneCtrl.text.trim(),
                otp: _otp,
                newPassword: _newPasswordCtrl.text,
              );
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password kamyabi se badal diya gaya hai.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/auth/client');
      }
    } finally {
      if (mounted) setState(() => _resetInFlight = false);
    }
  }

  String _requestErrorMessage(Object? failure) {
    if (failure is SmsSendFailure) {
      return 'OTP filhal send nahi ho saka. Password se continue karein ya thori dair baad dobara koshish karein.';
    }
    return failure is Failure ? failure.message : 'Code bhejne mein masla hua.';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(_clientForgotPasswordRequestProvider, (_, s) {
      if (s is AsyncError && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(_requestErrorMessage(s.error))));
      }
    });
    ref.listen(_clientForgotPasswordResetProvider, (_, s) {
      if (s is AsyncError && mounted) {
        final failure = s.error;
        final message =
            failure is Failure ? failure.message : 'Password badal nahi saka.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    final expiresAt =
        ref.watch(_clientForgotPasswordRequestProvider).valueOrNull;
    final showOtp = expiresAt != null;
    final resetState = ref.watch(_clientForgotPasswordResetProvider);
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
                                ? 'Naya Password\nSet Karein'
                                : 'Password Bhool\nGaye?',
                            subtitle: showOtp
                                ? 'Apne number par bheja gaya code darj karein.'
                                : 'Sirf Client account ke liye. Registered number par code bheja jayega.',
                            isSmall: isSmall,
                            showBackButton: true,
                          ),
                          SizedBox(height: isSmall ? 20 : 32),
                          if (!showOtp)
                            Form(
                              key: _phoneKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AuthTextField(
                                    controller: _phoneCtrl,
                                    label: 'Registered mobile number dalain',
                                    hint: '03XXXXXXXXX',
                                    keyboardType: TextInputType.phone,
                                    prefixIcon: Icons.phone_outlined,
                                    validator: _validatePhone,
                                  ),
                                  const SizedBox(height: 24),
                                  AuthPrimaryButton(
                                    label: 'OTP Bhejein',
                                    isLoading: _sendInFlight,
                                    onPressed: _sendCode,
                                  ),
                                ],
                              ),
                            )
                          else
                            Form(
                              key: _resetKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
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
                                    label: 'Naya Password',
                                    prefixIcon: Icons.lock_outline_rounded,
                                    obscureText: true,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Naya password likhein.';
                                      }
                                      if (v.length < 8) {
                                        return 'Password kam az kam 8 characters ka hona chahiye.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  AuthTextField(
                                    controller: _confirmCtrl,
                                    label: 'Naya Password Dobara Likhein',
                                    prefixIcon: Icons.lock_outline_rounded,
                                    obscureText: true,
                                    textInputAction: TextInputAction.done,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Password dobara likhein.';
                                      }
                                      if (v != _newPasswordCtrl.text) {
                                        return 'Passwords match nahi karte.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  AuthPrimaryButton(
                                    label: 'Naya Password Confirm Karein',
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
