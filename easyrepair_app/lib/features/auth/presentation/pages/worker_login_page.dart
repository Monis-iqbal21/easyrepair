import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_otp_providers.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/otp_input_section.dart';
import '../../../../core/l10n/l10n_extensions.dart';

/// Existing Ustaad login — OTP or password, both against the same phone
/// field. Password login reuses the existing, unchanged `/auth/login` path
/// (via `loginNotifierProvider`) so nothing about that behaviour changes.
class WorkerLoginPage extends ConsumerStatefulWidget {
  const WorkerLoginPage({super.key});

  @override
  ConsumerState<WorkerLoginPage> createState() => _WorkerLoginPageState();
}

class _WorkerLoginPageState extends ConsumerState<WorkerLoginPage> {
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _otp = '';
  bool _sendInFlight = false;
  bool _otpVerifyInFlight = false;

  @override
  void initState() {
    super.initState();
    // otpRequestNotifierProvider is a global, non-autoDispose provider shared
    // with the other OTP pages and never reset by any of them. Without this,
    // an OTP requested earlier in the session leaves `expiresAt` non-null
    // forever, so this page opens already in its "OTP sent" state and the
    // number cannot be corrected. Clears state only — sends nothing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(otpRequestNotifierProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Editing the number invalidates the OTP requested for the previous one.
  /// State-only: it must never re-request a code, or fixing one digit would
  /// burn an SMS send.
  void _onPhoneChanged(String _) {
    if (ref.read(otpRequestNotifierProvider).valueOrNull != null) {
      ref.read(otpRequestNotifierProvider.notifier).reset();
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
    if (_sendInFlight) return;
    final phoneError = _validatePhone(_phoneCtrl.text);
    if (phoneError != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(phoneError)));
      return;
    }
    setState(() => _sendInFlight = true);
    try {
      await ref
          .read(otpRequestNotifierProvider.notifier)
          .request(_phoneCtrl.text.trim(), OtpPurpose.workerLogin);
    } finally {
      if (mounted) setState(() => _sendInFlight = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6 || _otpVerifyInFlight) return;
    setState(() => _otpVerifyInFlight = true);
    try {
      await ref
          .read(workerOtpLoginNotifierProvider.notifier)
          .login(_phoneCtrl.text.trim(), _otp);
    } finally {
      if (mounted) setState(() => _otpVerifyInFlight = false);
    }
  }

  Future<void> _loginWithPassword() async {
    final phoneError = _validatePhone(_phoneCtrl.text);
    if (phoneError != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(phoneError)));
      return;
    }
    if (_passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.authValidationPasswordRequired)));
      return;
    }
    await ref
        .read(loginNotifierProvider.notifier)
        .login(_phoneCtrl.text.trim(), _passwordCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(otpRequestNotifierProvider, (_, state) {
      if (state is AsyncError) {
        final message = failureMessage(
          context.l10n,
          state.error,
          fallback: context.l10n.authErrorCodeSendFailed,
        );
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });
    ref.listen(workerOtpLoginNotifierProvider, (_, state) {
      if (state is AsyncError) {
        final message = failureMessage(
          context.l10n,
          state.error,
          fallback: context.l10n.authErrorLoginFailed,
        );
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });
    ref.listen(loginNotifierProvider, (_, state) {
      if (state is AsyncError) {
        final message = failureMessage(
          context.l10n,
          state.error,
          fallback: context.l10n.authErrorLoginFailed,
        );
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    final expiresAt = ref.watch(otpRequestNotifierProvider).valueOrNull;
    final showOtp = expiresAt != null;
    final otpLoginState = ref.watch(workerOtpLoginNotifierProvider);
    final hasOtpError = otpLoginState is AsyncError;
    final passwordLoginLoading = ref.watch(loginNotifierProvider).isLoading;

    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets.bottom;
    final isSmall = mq.size.height < 680;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                            title: context.l10n.authButtonUstaadLogin,
                            subtitle: '',
                            isSmall: isSmall,
                            showBackButton: true,
                          ),
                          SizedBox(height: isSmall ? 20 : 32),
                          // Stays editable after the code is sent — editing
                          // clears the previous request's countdown rather
                          // than locking the field (see _onPhoneChanged).
                          AuthTextField(
                            controller: _phoneCtrl,
                            label: context.l10n.authForgotPasswordPrompt,
                            hint: '03XXXXXXXXX',
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone_outlined,
                            validator: _validatePhone,
                            onChanged: _onPhoneChanged,
                          ),
                          const SizedBox(height: 20),
                          if (showOtp) ...[
                            OtpInputSection(
                              expiresAt: expiresAt,
                              hasError: hasOtpError,
                              resendInFlight: _sendInFlight,
                              onChanged: (v) => setState(() => _otp = v),
                              onCompleted: (v) {
                                setState(() => _otp = v);
                                _verifyOtp();
                              },
                              onResend: _sendCode,
                            ),
                            const SizedBox(height: 16),
                          ],
                          AuthPrimaryButton(
                            label: showOtp
                                ? context.l10n.authLoginWithOtp
                                : context.l10n.authSendOtp,
                            isLoading: showOtp ? _otpVerifyInFlight : _sendInFlight,
                            onPressed: showOtp
                                ? (_otp.length == 6 ? _verifyOtp : null)
                                : _sendCode,
                          ),
                          SizedBox(height: isSmall ? 20 : 28),
                          Row(
                            children: [
                              const Expanded(child: Divider(color: kAuthBorder)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  context.l10n.authOr,
                                  style: TextStyle(
                                    color: kAuthGray,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider(color: kAuthBorder)),
                            ],
                          ),
                          SizedBox(height: isSmall ? 20 : 28),
                          AuthTextField(
                            controller: _passwordCtrl,
                            label: context.l10n.authFieldPassword,
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _loginWithPassword(),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: GestureDetector(
                              onTap: () => context.go('/forgot-password'),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  context.l10n.authButtonForgotPassword,
                                  style: TextStyle(
                                    color: kAuthAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AuthPrimaryButton(
                            label: context.l10n.authLoginWithPassword,
                            isLoading: passwordLoginLoading,
                            onPressed: _loginWithPassword,
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
