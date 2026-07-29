import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_otp_providers.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/otp_input_section.dart';

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
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
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
        ..showSnackBar(const SnackBar(content: Text('Password likhein.')));
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
        final failure = state.error;
        final message = failure is Failure ? failure.message : 'Code bhejne mein masla hua.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });
    ref.listen(workerOtpLoginNotifierProvider, (_, state) {
      if (state is AsyncError) {
        final failure = state.error;
        final message = failure is Failure ? failure.message : 'Login nahi ho saka.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });
    ref.listen(loginNotifierProvider, (_, state) {
      if (state is AsyncError) {
        final failure = state.error;
        final message = failure is Failure ? failure.message : 'Login nahi ho saka.';
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
                            title: 'Ustaad Login',
                            subtitle: '',
                            isSmall: isSmall,
                            showBackButton: true,
                          ),
                          SizedBox(height: isSmall ? 20 : 32),
                          AuthTextField(
                            controller: _phoneCtrl,
                            label: 'Apna registered mobile number dalain',
                            hint: '03XXXXXXXXX',
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone_outlined,
                            validator: _validatePhone,
                            enabled: !showOtp,
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
                                ? 'OTP Se Login Karein'
                                : 'OTP Bhejein',
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
                                  'Ya phir',
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
                            label: 'Password',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _loginWithPassword(),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => context.go('/forgot-password'),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'Password bhool gaye?',
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
                            label: 'Password Se Login Karein',
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
