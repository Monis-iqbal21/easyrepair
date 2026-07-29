import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_otp_providers.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/otp_input_section.dart';

/// Client's single combined login/registration page — no password, ever.
/// The backend alone decides login vs. new-account registration once the
/// OTP verifies; this page never makes that decision itself.
class ClientOtpAuthPage extends ConsumerStatefulWidget {
  const ClientOtpAuthPage({super.key});

  @override
  ConsumerState<ClientOtpAuthPage> createState() => _ClientOtpAuthPageState();
}

class _ClientOtpAuthPageState extends ConsumerState<ClientOtpAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _otp = '';
  String? _workerConflictMessage;
  bool _sendInFlight = false;
  bool _verifyInFlight = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Poora naam likhein.';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Mobile number likhein.';
    if (!RegExp(r'^(\+92|0092|92|0)?[3][0-9]{9}$').hasMatch(value.trim())) {
      return 'Sahi Pakistani mobile number likhein.';
    }
    return null;
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate() || _sendInFlight) return;
    setState(() {
      _workerConflictMessage = null;
      _sendInFlight = true;
    });
    try {
      await ref.read(otpRequestNotifierProvider.notifier).request(
            _phoneCtrl.text.trim(),
            OtpPurpose.clientLoginRegister,
          );
    } finally {
      if (mounted) setState(() => _sendInFlight = false);
    }
  }

  Future<void> _verify() async {
    if (_otp.length != 6 || _verifyInFlight) return;
    setState(() {
      _workerConflictMessage = null;
      _verifyInFlight = true;
    });
    try {
      final ok = await ref.read(clientOtpAuthNotifierProvider.notifier).verify(
            _nameCtrl.text.trim(),
            _phoneCtrl.text.trim(),
            _otp,
          );
      if (ok && mounted) {
        // Router's redirect (driven by authStateProvider) takes over from
        // here — no explicit navigation needed.
      }
    } finally {
      if (mounted) setState(() => _verifyInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(clientOtpAuthNotifierProvider, (_, state) {
      if (state is AsyncError) {
        final failure = state.error;
        if (failure is WorkerPhoneConflictFailure) {
          setState(() => _workerConflictMessage = failure.message);
          return;
        }
        final message = failure is Failure ? failure.message : 'Kuch ghalat ho gaya.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    ref.listen(otpRequestNotifierProvider, (_, state) {
      if (state is AsyncError) {
        final failure = state.error;
        final message = failure is Failure ? failure.message : 'Code bhejne mein masla hua.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    final expiresAt = ref.watch(otpRequestNotifierProvider).valueOrNull;
    final showOtp = expiresAt != null;
    final verifyState = ref.watch(clientOtpAuthNotifierProvider);
    final hasOtpError = verifyState is AsyncError &&
        verifyState.error is! WorkerPhoneConflictFailure;

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
                            title: 'Ustaad book karne ke liye\nlogin karein',
                            subtitle:
                                'Apna naam aur mobile number dalain. Hum verification code bhejein ge.',
                            isSmall: isSmall,
                            showBackButton: true,
                          ),
                          SizedBox(height: isSmall ? 20 : 32),
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AuthTextField(
                                  controller: _nameCtrl,
                                  label: 'Aap ka poora naam',
                                  hint: 'Apna poora naam likhein',
                                  prefixIcon: Icons.person_outline_rounded,
                                  validator: _validateName,
                                  enabled: !showOtp,
                                ),
                                const SizedBox(height: 14),
                                AuthTextField(
                                  controller: _phoneCtrl,
                                  label: 'Mobile number',
                                  hint: '03XXXXXXXXX',
                                  keyboardType: TextInputType.phone,
                                  prefixIcon: Icons.phone_outlined,
                                  validator: _validatePhone,
                                  enabled: !showOtp,
                                ),
                                const SizedBox(height: 6),
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Text(
                                    'Is number par verification code bheja jayega.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: kAuthGray,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (showOtp) ...[
                            const SizedBox(height: 24),
                            OtpInputSection(
                              expiresAt: expiresAt,
                              hasError: hasOtpError,
                              resendInFlight: _sendInFlight,
                              onChanged: (v) => setState(() => _otp = v),
                              onCompleted: (v) {
                                setState(() => _otp = v);
                                _verify();
                              },
                              onResend: _sendCode,
                            ),
                          ],
                          if (_workerConflictMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFCA5A5),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    _workerConflictMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFB91C1C),
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  AuthSecondaryButton(
                                    label: 'Ustaad Login',
                                    onPressed: () =>
                                        context.go('/auth/worker/login'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          SizedBox(height: isSmall ? 20 : 28),
                          AuthPrimaryButton(
                            label: showOtp
                                ? 'Verify Karke Aage Barhein'
                                : 'Code Bhejein',
                            isLoading: showOtp ? _verifyInFlight : _sendInFlight,
                            onPressed: showOtp
                                ? (_otp.length == 6 ? _verify : null)
                                : _sendCode,
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
