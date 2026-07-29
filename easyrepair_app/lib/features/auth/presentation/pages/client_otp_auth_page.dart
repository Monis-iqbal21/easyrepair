import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_otp_providers.dart';
import '../providers/client_password_providers.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/otp_input_section.dart';

enum _ClientAuthMode { otp, password }

/// Client's combined auth page — an OTP sub-flow (passwordless login/
/// register, backend-decided) and a password fallback sub-flow, switched via
/// a segmented selector. Both live on this one page/State so there is never
/// a confusing second Client login page.
class ClientOtpAuthPage extends ConsumerStatefulWidget {
  const ClientOtpAuthPage({super.key});

  @override
  ConsumerState<ClientOtpAuthPage> createState() => _ClientOtpAuthPageState();
}

class _ClientOtpAuthPageState extends ConsumerState<ClientOtpAuthPage> {
  _ClientAuthMode _mode = _ClientAuthMode.otp;

  // ── OTP sub-flow (unchanged) ────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _otp = '';
  bool _sendInFlight = false;
  bool _verifyInFlight = false;

  // ── Password sub-flow ────────────────────────────────────────────────────
  final _pwPhoneKey = GlobalKey<FormState>();
  final _pwFormKey = GlobalKey<FormState>();
  final _pwPhoneCtrl = TextEditingController();
  final _pwPasswordCtrl = TextEditingController();
  final _pwNameCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();
  bool _pwCheckInFlight = false;
  bool _pwSubmitInFlight = false;

  String? _workerConflictMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pwPhoneCtrl.dispose();
    _pwPasswordCtrl.dispose();
    _pwNameCtrl.dispose();
    _pwConfirmCtrl.dispose();
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password likhein.';
    if (value.length < 8) {
      return 'Password kam az kam 8 characters ka hona chahiye.';
    }
    return null;
  }

  void _switchMode(_ClientAuthMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _workerConflictMessage = null;
    });
    ref.read(clientPhoneCheckNotifierProvider.notifier).reset();
  }

  // ── OTP sub-flow handlers (unchanged) ───────────────────────────────────

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
      await ref.read(clientOtpAuthNotifierProvider.notifier).verify(
            _nameCtrl.text.trim(),
            _phoneCtrl.text.trim(),
            _otp,
          );
    } finally {
      if (mounted) setState(() => _verifyInFlight = false);
    }
  }

  // ── Password sub-flow handlers ──────────────────────────────────────────

  Future<void> _checkPhone() async {
    if (!_pwPhoneKey.currentState!.validate() || _pwCheckInFlight) return;
    setState(() {
      _workerConflictMessage = null;
      _pwCheckInFlight = true;
    });
    try {
      await ref
          .read(clientPhoneCheckNotifierProvider.notifier)
          .check(_pwPhoneCtrl.text.trim());
    } finally {
      if (mounted) setState(() => _pwCheckInFlight = false);
    }
  }

  Future<void> _passwordLogin() async {
    if (!_pwFormKey.currentState!.validate() || _pwSubmitInFlight) return;
    setState(() => _pwSubmitInFlight = true);
    try {
      await ref.read(clientPasswordLoginNotifierProvider.notifier).login(
            _pwPhoneCtrl.text.trim(),
            _pwPasswordCtrl.text,
          );
    } finally {
      if (mounted) setState(() => _pwSubmitInFlight = false);
    }
  }

  Future<void> _passwordRegister() async {
    if (!_pwFormKey.currentState!.validate() || _pwSubmitInFlight) return;
    setState(() => _pwSubmitInFlight = true);
    try {
      await ref.read(clientPasswordRegisterNotifierProvider.notifier).register(
            fullName: _pwNameCtrl.text.trim(),
            phone: _pwPhoneCtrl.text.trim(),
            password: _pwPasswordCtrl.text,
          );
    } finally {
      if (mounted) setState(() => _pwSubmitInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(clientOtpAuthNotifierProvider, (_, state) {
      if (state is AsyncError) _handleAuthFailure(state.error);
    });
    ref.listen(clientPasswordLoginNotifierProvider, (_, state) {
      if (state is AsyncError) _handleAuthFailure(state.error);
    });
    ref.listen(clientPasswordRegisterNotifierProvider, (_, state) {
      if (state is AsyncError) _handleAuthFailure(state.error);
    });
    ref.listen(otpRequestNotifierProvider, (_, state) {
      if (state is AsyncError) _showSnackBar(state.error);
    });
    ref.listen(clientPhoneCheckNotifierProvider, (_, state) {
      if (state is AsyncError) _handleAuthFailure(state.error);
    });

    final expiresAt = ref.watch(otpRequestNotifierProvider).valueOrNull;
    final showOtp = expiresAt != null;
    final verifyState = ref.watch(clientOtpAuthNotifierProvider);
    final hasOtpError =
        verifyState is AsyncError && verifyState.error is! WorkerPhoneConflictFailure;

    final phoneStatus = ref.watch(clientPhoneCheckNotifierProvider).valueOrNull;
    final pwLoginLoading = ref.watch(clientPasswordLoginNotifierProvider).isLoading;
    final pwRegisterLoading =
        ref.watch(clientPasswordRegisterNotifierProvider).isLoading;

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
                            subtitle: _mode == _ClientAuthMode.otp
                                ? 'Apna naam aur mobile number dalain. Hum verification code bhejein ge.'
                                : 'Apna mobile number aur password se continue karein.',
                            isSmall: isSmall,
                            showBackButton: true,
                          ),
                          SizedBox(height: isSmall ? 18 : 28),
                          _ModeSelector(
                            mode: _mode,
                            onChanged: _switchMode,
                          ),
                          const SizedBox(height: 20),
                          if (_mode == _ClientAuthMode.otp)
                            _buildOtpMode(showOtp, hasOtpError, expiresAt)
                          else
                            _buildPasswordMode(
                              phoneStatus,
                              pwLoginLoading,
                              pwRegisterLoading,
                            ),
                          if (_workerConflictMessage != null) ...[
                            const SizedBox(height: 16),
                            _WorkerConflictBanner(message: _workerConflictMessage!),
                          ],
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

  void _handleAuthFailure(Object? error) {
    if (error is WorkerPhoneConflictFailure) {
      setState(() => _workerConflictMessage = error.message);
      return;
    }
    _showSnackBar(error);
  }

  void _showSnackBar(Object? error) {
    final message = error is SmsSendFailure
        ? 'OTP filhal send nahi ho saka. Password se continue karein ya thori dair baad dobara koshish karein.'
        : (error is Failure ? error.message : 'Kuch ghalat ho gaya.');
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildOtpMode(bool showOtp, bool hasOtpError, DateTime? expiresAt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  style: TextStyle(fontSize: 12, color: kAuthGray),
                ),
              ),
            ],
          ),
        ),
        if (showOtp) ...[
          const SizedBox(height: 24),
          OtpInputSection(
            expiresAt: expiresAt!,
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
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: showOtp ? 'Verify Karke Aage Barhein' : 'Code Bhejein',
          isLoading: showOtp ? _verifyInFlight : _sendInFlight,
          onPressed: showOtp ? (_otp.length == 6 ? _verify : null) : _sendCode,
        ),
      ],
    );
  }

  Widget _buildPasswordMode(
    ClientPhoneStatus? status,
    bool pwLoginLoading,
    bool pwRegisterLoading,
  ) {
    final resolved = status != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Form(
          key: _pwPhoneKey,
          child: AuthTextField(
            controller: _pwPhoneCtrl,
            label: 'Mobile Number',
            hint: '03XXXXXXXXX',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
            validator: _validatePhone,
            enabled: !resolved,
            onChanged: (_) {
              if (resolved) {
                ref.read(clientPhoneCheckNotifierProvider.notifier).reset();
              }
            },
          ),
        ),
        if (!resolved) ...[
          const SizedBox(height: 20),
          AuthPrimaryButton(
            label: 'Aage Barhein',
            isLoading: _pwCheckInFlight,
            onPressed: _checkPhone,
          ),
        ] else if (status == ClientPhoneStatus.client) ...[
          const SizedBox(height: 14),
          Form(
            key: _pwFormKey,
            child: AuthTextField(
              controller: _pwPasswordCtrl,
              label: 'Password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: true,
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password likhein.' : null,
              onFieldSubmitted: (_) => _passwordLogin(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => context.push('/auth/client/forgot-password'),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Password Bhool Gaye?',
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
            label: 'Login Karein',
            isLoading: pwLoginLoading,
            onPressed: _passwordLogin,
          ),
        ] else if (status == ClientPhoneStatus.newAccount) ...[
          const SizedBox(height: 14),
          Form(
            key: _pwFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _pwNameCtrl,
                  label: 'Pura Naam',
                  hint: 'Apna poora naam likhein',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: _validateName,
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _pwPasswordCtrl,
                  label: 'Password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _pwConfirmCtrl,
                  label: 'Password Dobara Likhein',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Password dobara likhein.';
                    }
                    if (v != _pwPasswordCtrl.text) {
                      return 'Passwords match nahi karte.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AuthPrimaryButton(
            label: 'Account Banayein',
            isLoading: pwRegisterLoading,
            onPressed: _passwordRegister,
          ),
        ],
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final _ClientAuthMode mode;
  final ValueChanged<_ClientAuthMode> onChanged;

  const _ModeSelector({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kAuthBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAuthBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeSegment(
              label: 'OTP se Continue',
              isSelected: mode == _ClientAuthMode.otp,
              onTap: () => onChanged(_ClientAuthMode.otp),
            ),
          ),
          Expanded(
            child: _ModeSegment(
              label: 'Password se Continue',
              isSelected: mode == _ClientAuthMode.password,
              onTap: () => onChanged(_ClientAuthMode.password),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeSegment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? kAuthAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : kAuthGray,
          ),
        ),
      ),
    );
  }
}

class _WorkerConflictBanner extends StatelessWidget {
  final String message;

  const _WorkerConflictBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13.5),
          ),
          const SizedBox(height: 12),
          AuthSecondaryButton(
            label: 'Ustaad Login',
            onPressed: () => context.go('/auth/worker/login'),
          ),
        ],
      ),
    );
  }
}
