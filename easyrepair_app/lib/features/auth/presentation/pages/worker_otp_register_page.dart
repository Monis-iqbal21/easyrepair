import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../worker/presentation/providers/worker_providers.dart'
    show categoriesProvider;
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_otp_providers.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/otp_input_section.dart';
import '../../../../core/l10n/l10n_extensions.dart';

/// Redesigned Ustaad registration — full CNIC name, OTP-verified phone,
/// password (kept for fallback login), and a dynamically-loaded skill
/// dropdown (no hardcoded categories/IDs).
class WorkerOtpRegisterPage extends ConsumerStatefulWidget {
  const WorkerOtpRegisterPage({super.key});

  @override
  ConsumerState<WorkerOtpRegisterPage> createState() =>
      _WorkerOtpRegisterPageState();
}

class _WorkerOtpRegisterPageState
    extends ConsumerState<WorkerOtpRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _selectedCategoryId;
  String? _skillError;
  String _otp = '';
  bool _sendInFlight = false;
  bool _registerInFlight = false;

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
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Editing the number invalidates the OTP requested for the previous one.
  /// State-only: it must never re-request a code.
  void _onPhoneChanged(String _) {
    if (ref.read(otpRequestNotifierProvider).valueOrNull != null) {
      ref.read(otpRequestNotifierProvider.notifier).reset();
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

  Future<void> _sendCode() async {
    if (_sendInFlight) return;
    final nameError = _validateName(_nameCtrl.text);
    final phoneError = _validatePhone(_phoneCtrl.text);
    if (nameError != null || phoneError != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(nameError ?? phoneError!)));
      return;
    }
    setState(() => _sendInFlight = true);
    try {
      await ref
          .read(otpRequestNotifierProvider.notifier)
          .request(_phoneCtrl.text.trim(), OtpPurpose.workerRegister);
    } finally {
      if (mounted) setState(() => _sendInFlight = false);
    }
  }

  Future<void> _register() async {
    final formValid = _formKey.currentState!.validate();
    setState(() {
      _skillError =
          _selectedCategoryId == null ? context.l10n.authSkillRequired : null;
    });
    if (!formValid || _skillError != null || _otp.length != 6 || _registerInFlight) {
      return;
    }
    setState(() => _registerInFlight = true);
    try {
      await ref.read(workerOtpRegisterNotifierProvider.notifier).register(
            fullName: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            otp: _otp,
            password: _passwordCtrl.text,
            categoryId: _selectedCategoryId!,
          );
    } finally {
      if (mounted) setState(() => _registerInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(workerOtpRegisterNotifierProvider, (_, state) {
      if (state is AsyncError) {
        final message = failureMessage(
          context.l10n,
          state.error,
          fallback: context.l10n.authErrorRegisterFailed,
        );
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

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

    final expiresAt = ref.watch(otpRequestNotifierProvider).valueOrNull;
    final showOtp = expiresAt != null;
    final registerState = ref.watch(workerOtpRegisterNotifierProvider);
    final hasOtpError = registerState is AsyncError;
    final categoriesAsync = ref.watch(categoriesProvider);

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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: isSmall ? 16 : 28),
                            AuthHeader(
                              title: context.l10n.authWorkerRegisterTitle,
                              subtitle: context.l10n.authWorkerTypeNewSubtitle,
                              isSmall: isSmall,
                              showBackButton: true,
                            ),
                            SizedBox(height: isSmall ? 20 : 32),
                            Text(
                              context.l10n.authCnicNameHint,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: kAuthGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            AuthTextField(
                              controller: _nameCtrl,
                              label: context.l10n.authFieldFullNameShort,
                              hint: context.l10n.authHintExampleFullName,
                              prefixIcon: Icons.badge_outlined,
                              validator: _validateName,
                              enabled: !showOtp,
                            ),
                            const SizedBox(height: 14),
                            // Stays editable after the code is sent — editing
                            // clears the previous request's countdown rather
                            // than locking the field (see _onPhoneChanged).
                            AuthTextField(
                              controller: _phoneCtrl,
                              label: context.l10n.authFieldMobileNumber,
                              hint: '03XXXXXXXXX',
                              keyboardType: TextInputType.phone,
                              prefixIcon: Icons.phone_outlined,
                              validator: _validatePhone,
                              onChanged: _onPhoneChanged,
                            ),
                            const SizedBox(height: 14),
                            AuthTextField(
                              controller: _passwordCtrl,
                              label: context.l10n.authCreatePasswordLabel,
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: true,
                              validator: _validatePassword,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.l10n.authSelectSkill,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kAuthDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            categoriesAsync.when(
                              loading: () => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: kAuthAccent,
                                    ),
                                  ),
                                ),
                              ),
                              error: (e, _) => Text(
                                context.l10n.authSkillsLoadFailed,
                                style: TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 12.5,
                                ),
                              ),
                              data: (categories) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: kAuthBorder),
                                  color: kAuthBg,
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedCategoryId,
                                    isExpanded: true,
                                    hint: Text(
                                      context.l10n.authSkillRequired,
                                      style: TextStyle(
                                        color: kAuthGray,
                                        fontSize: 14,
                                      ),
                                    ),
                                    items: categories
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c.id,
                                            child: Text(
                                              c.name,
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) => setState(() {
                                      _selectedCategoryId = v;
                                      _skillError = null;
                                    }),
                                  ),
                                ),
                              ),
                            ),
                            if (_skillError != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _skillError!,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (showOtp) ...[
                              const SizedBox(height: 24),
                              OtpInputSection(
                                expiresAt: expiresAt,
                                hasError: hasOtpError,
                                resendInFlight: _sendInFlight,
                                onChanged: (v) => setState(() => _otp = v),
                                onCompleted: (v) => setState(() => _otp = v),
                                onResend: _sendCode,
                              ),
                            ],
                            SizedBox(height: isSmall ? 20 : 28),
                            AuthPrimaryButton(
                              label: showOtp
                                  ? context.l10n.authButtonCreateAccount
                                  : context.l10n.authButtonSendCode,
                              isLoading: showOtp ? _registerInFlight : _sendInFlight,
                              onPressed: showOtp
                                  ? (_otp.length == 6 ? _register : null)
                                  : _sendCode,
                            ),
                          ],
                        ),
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
