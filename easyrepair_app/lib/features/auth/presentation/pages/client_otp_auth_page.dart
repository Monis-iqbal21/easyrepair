import 'package:flutter/material.dart';
import '../../../../core/l10n/l10n_extensions.dart';
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
import '../../../../core/errors/failure_messages.dart';

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
  void initState() {
    super.initState();
    // otpRequestNotifierProvider is a global, non-autoDispose provider shared
    // by all three OTP pages and is never reset by any of them. Without this,
    // a successful OTP request earlier in the session leaves `expiresAt`
    // non-null forever, so re-entering this page renders the phone field in
    // its "OTP sent" state on the very first frame and the number can no
    // longer be corrected. Clearing state only — this never sends anything.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(otpRequestNotifierProvider.notifier).reset();
      ref.read(clientPhoneCheckNotifierProvider.notifier).reset();
    });
  }

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

  /// Editing the phone number invalidates any OTP already requested for the
  /// PREVIOUS number. Clears that state so the field stays editable and the
  /// countdown never belongs to a different number.
  ///
  /// Deliberately state-only: it must never re-request an OTP, or correcting
  /// a single digit would burn an SMS send.
  void _onOtpPhoneChanged(String _) {
    if (ref.read(otpRequestNotifierProvider).valueOrNull != null) {
      ref.read(otpRequestNotifierProvider.notifier).reset();
    }
  }

  /// Same idea for the password flow: the phone check result belongs to the
  /// number that was checked, so editing it must invalidate the result rather
  /// than locking the field.
  void _onPasswordPhoneChanged(String _) {
    if (_workerConflictMessage != null) {
      setState(() => _workerConflictMessage = null);
    }
    if (ref.read(clientPhoneCheckNotifierProvider).valueOrNull != null) {
      ref.read(clientPhoneCheckNotifierProvider.notifier).reset();
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return context.l10n.authValidationNameRequired;
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return context.l10n.authValidationPhoneRequired;
    if (!RegExp(r'^(\+92|0092|92|0)?[3][0-9]{9}$').hasMatch(value.trim())) {
      return context.l10n.authValidationPhoneInvalid;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return context.l10n.authValidationPasswordRequired;
    if (value.length < 8) {
      return context.l10n.authValidationPasswordTooShort;
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
                            title: context.l10n.authClientLoginTitle,
                            subtitle: _mode == _ClientAuthMode.otp
                                ? context.l10n.authClientOtpSubtitle
                                : context.l10n.authClientPasswordSubtitle,
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
      setState(
        () => _workerConflictMessage = failureMessage(context.l10n, error),
      );
      return;
    }
    _showSnackBar(error);
  }

  void _showSnackBar(Object? error) {
    final message = error is SmsSendFailure
        ? context.l10n.authErrorOtpSendFailed
        : failureMessage(
            context.l10n,
            error,
            fallback: context.l10n.authErrorGeneric,
          );
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
                label: context.l10n.authFieldFullName,
                hint: context.l10n.authHintFullName,
                prefixIcon: Icons.person_outline_rounded,
                validator: _validateName,
                enabled: !showOtp,
              ),
              const SizedBox(height: 14),
              // Stays editable after the code is sent — a mistyped number is
              // the single most common reason to come back to this field.
              // Editing it clears the previous request's countdown (see
              // _onOtpPhoneChanged) rather than locking the field.
              AuthTextField(
                controller: _phoneCtrl,
                label: context.l10n.authFieldMobileNumber,
                hint: '03XXXXXXXXX',
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
                validator: _validatePhone,
                onChanged: _onOtpPhoneChanged,
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: Text(
                  context.l10n.authOtpWillBeSentNotice,
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
          label: showOtp ? context.l10n.authButtonVerifyAndContinue : context.l10n.authButtonSendCode,
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
          // Deliberately NOT disabled once the phone check resolves. Resolving
          // the check is exactly what reveals the password field, so disabling
          // here made the number uneditable the moment the user moved focus to
          // the password and came back — the reported bug. (The old
          // `enabled: !resolved` also made this onChanged unreachable, since a
          // disabled field never emits it.)
          child: AuthTextField(
            controller: _pwPhoneCtrl,
            label: context.l10n.authFieldMobileNumberTitle,
            hint: '03XXXXXXXXX',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
            validator: _validatePhone,
            onChanged: _onPasswordPhoneChanged,
          ),
        ),
        if (!resolved) ...[
          const SizedBox(height: 20),
          AuthPrimaryButton(
            label: context.l10n.commonContinue,
            isLoading: _pwCheckInFlight,
            onPressed: _checkPhone,
          ),
        ] else if (status == ClientPhoneStatus.client) ...[
          const SizedBox(height: 14),
          Form(
            key: _pwFormKey,
            child: AuthTextField(
              controller: _pwPasswordCtrl,
              label: context.l10n.authFieldPassword,
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: true,
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  (v == null || v.isEmpty) ? context.l10n.authValidationPasswordRequired : null,
              onFieldSubmitted: (_) => _passwordLogin(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: GestureDetector(
              onTap: () => context.push('/auth/client/forgot-password'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
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
            label: context.l10n.authButtonLogIn,
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
                  label: context.l10n.authFieldFullNameShort,
                  hint: context.l10n.authHintFullName,
                  prefixIcon: Icons.person_outline_rounded,
                  validator: _validateName,
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _pwPasswordCtrl,
                  label: context.l10n.authFieldPassword,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _pwConfirmCtrl,
                  label: context.l10n.authFieldConfirmPassword,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return context.l10n.authValidationConfirmPasswordRequired;
                    }
                    if (v != _pwPasswordCtrl.text) {
                      return context.l10n.authValidationPasswordsDoNotMatch;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AuthPrimaryButton(
            label: context.l10n.authButtonCreateAccount,
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
              label: context.l10n.authButtonContinueWithOtp,
              isSelected: mode == _ClientAuthMode.otp,
              onTap: () => onChanged(_ClientAuthMode.otp),
            ),
          ),
          Expanded(
            child: _ModeSegment(
              label: context.l10n.authButtonContinueWithPassword,
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
            label: context.l10n.authButtonUstaadLogin,
            onPressed: () => context.push('/auth/worker/login'),
          ),
        ],
      ),
    );
  }
}
